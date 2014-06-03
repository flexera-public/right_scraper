#--
# Copyright: Copyright (c) 2010-2013 RightScale, Inc.
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# 'Software'), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#++

# ancestor
require 'right_scraper/scanners'

require 'json'
require 'right_popen'
require 'right_popen/safe_output_buffer'
require 'tmpdir'

module RightScraper::Scanners

  # Load cookbook metadata from a filesystem.
  class CookbookMetadata < ::RightScraper::Scanners::Base
    JSON_METADATA = 'metadata.json'
    RUBY_METADATA = 'metadata.rb'

    UNDEFINED_COOKBOOK_NAME = 'undefined'
    KNIFE_METADATA_SCRIPT_NAME = 'knife_metadata.rb'

    JAILED_FILE_SIZE_CONSTRAINT = 128 * 1024  # 128 KB
    FREED_FILE_SIZE_CONSTRAINT = 64 * 1024  # 64 KB

    TARBALL_CREATE_TIMEOUT = 30 # ..to create the tarball
    TARBALL_ARCHIVE_NAME = 'cookbook.tar'

    # exceptions
    class MetadataError < Exception; end

    def tls
      Thread.current[self.class.to_s.to_sym] ||= {}
    end

    def begin(resource)
      @read_blk = nil
      @cookbook = resource
      true
    end

    # Complete a scan for the given resource.
    #
    # === Parameters ===
    # resource(RightScraper::Resources::Base):: resource to scan
    def end(resource)
      @logger.operation(:metadata_parsing) do
        if @read_blk
          metadata = ::JSON.parse(@read_blk.call)
          resource.metadata = metadata

          # check for undefined cookbook name.
          #
          # note that many specs in right_scraper use badly formed metadata
          # that is not even a hash so, to avoid having to fix all of them
          # (and also in case the user's metadata.json is not a hash) check
          # for the has_key? method.
          #
          # if real metadata is not a hash then that should cause failure
          # at a higher level. if the cookbook name is actually defined as
          # being 'undefined' then the user gets a warning anyway.
          if (metadata.respond_to?(:has_key?) &&
              metadata['name'] == UNDEFINED_COOKBOOK_NAME)
            message =
              'Cookbook name appears to be undefined and has been' +
              ' supplied automatically.'
            @logger.note_warning(message)
          end
        else
          # should not be scanning at all unless one of the metadata files was
          # detected before starting scan.
          fail 'Unexpected missing metadata'
        end
      end
      true
    ensure
      @read_blk = nil
      @cookbook = nil
    end

    # All done scanning this repository, we can tear down the warden container we may or
    # may not have created while parsing the cookbooks for this repository.
    #
    def finish
      begin
        FileUtils.remove_entry_secure(tls[:tmpdir]) if tls[:tmpdir]
      rescue ::Exception => e
        @logger.note_warning(e.message)
      end

      if warden = tls[:warden]
        begin
          warden.cleanup
        rescue ::Exception => e
          @logger.note_warning(e.message)
        end
      end

    ensure
      # Cleanup thread-local storage
      tls.clear
    end

    # Notice a file during scanning.
    #
    # === Block
    # Return the data for this file.  We use a block because it may
    # not always be necessary to read the data.
    #
    # === Parameters
    # relative_position(String):: relative pathname for the file from root of cookbook
    def notice(relative_position, &blk)
      case relative_position
      when JSON_METADATA
        # preferred over RUBY_METADATA.
        @read_blk = blk
      when RUBY_METADATA
        # defer to any JSON_METADATA, which we hope refers to the same info.
        @read_blk ||= self.method(:generate_metadata_json)
      end
      true
    end

    # Notice a directory during scanning.  Since metadata.{json,rb} is by
    # definition only in the root directory we don't need to recurse,
    # but we do need to go into the first directory (identified by
    # +relative_position+ being +nil+).
    #
    # === Parameters
    # relative_position(String):: relative pathname for the directory from root of cookbook
    #
    # === Returns
    # Boolean:: should the scanning recurse into the directory
    def notice_dir(relative_position)
      relative_position == nil
    end

    private

    # Executes the 'metadata.rb' file from a cookbook. Because we don't want
    # to evaluate arbitrary Ruby code, we need to sandbox it first using
    # Warden.
    #
    # in order for knife metadata to succeed in the general case we need to
    # copy some (but not all) of the cookbook directory AND its ancestors (if
    # any) into the container. we will try and restrict copying to what might
    # plausibly be referenced by 'metadata.rb' but this could be anything like
    # a LICENSE, README, etc. the best heuristic seems to be to copy any file
    # whose size is small (less than 128K) because 'metadata.rb' should not be
    # executing binaries and should only consume text files of a reasonable
    # size. if these restrictions cause a problem then the user is free to
    # pre-knife his own 'metadata.json' file and check it into the repo.
    #
    # note the selection of the jailed cookbook dir is specific to the
    # behavior of knife metadata. the cookbook name is defined when the
    # 'metadata.rb' declares the name attribute, but the name attribute is
    # optional. when no name attribute is declared, the metadata automagically
    # uses the parent directory name. this works okay so long as the parent
    # directory name is actually the cookbook name. in the case of a repo with
    # 'metadata.rb' at the root (i.e. no checked-in parent directory) then the
    # cookbook name is undefined. in this case, we want the cookbook name to
    # be 'undefined' to remind the user to declare the name explicitly.
    #
    # === Returns
    # @return [String] metadata JSON text
    def generate_metadata_json
      @logger.operation(:metadata_generation) do
        # note we will use the same tmpdir path inside and outside the
        # container only because it is non-trivial to invoke mktmpdir inside
        # the container.
        tmpdir = create_tmpdir

        # arrest
        knife_metadata_script_path = ::File.join(tmpdir, KNIFE_METADATA_SCRIPT_NAME)
        jailed_repo_dir = ::File.join(tmpdir, UNDEFINED_COOKBOOK_NAME)
        jailed_cookbook_dir = (@cookbook.pos == '.' && jailed_repo_dir) || ::File.join(jailed_repo_dir, @cookbook.pos)
        jailed_metadata_json_path = ::File.join(jailed_cookbook_dir, JSON_METADATA)
        freed_metadata_json_path = ::File.join(tmpdir, JSON_METADATA)

        # police brutality
        copy_out = { jailed_metadata_json_path => freed_metadata_json_path }

        begin
          # jail the repo
          unless warden = tls[:warden]
            # Create the container, one for all in this repo
            warden = tls[:warden] = create_warden

            # Get a list of the files in the repo we need
            create_knife_metadata_script(knife_metadata_script_path)
            copy_in = generate_copy_in
            copy_in << knife_metadata_script_path

            # tar up the required pieces of the repo and copy them into the container
            cookbook_tarball_path = ::File.join(tmpdir, TARBALL_ARCHIVE_NAME)
            create_cookbook_tarball(cookbook_tarball_path, copy_in, jailed_repo_dir)

            # unarchive the tarball on the otherside (this is faster than single file copies)
            cmd = "tar -Pxf #{cookbook_tarball_path.inspect}"
            warden.run_command_in_jail(cmd, cookbook_tarball_path, nil)
          end

          # Generate the metadata
          cmd = "export LC_ALL='en_US.UTF-8'; ruby #{knife_metadata_script_path.inspect} #{jailed_cookbook_dir}"
          warden.run_command_in_jail(cmd, nil, copy_out)

          # constraining the generate file size is debatable, but our UI
          # attempts to load metadata JSON into memory far too often to be
          # blasé about generating multi-megabyte JSON files.
          unless ::File.file?(freed_metadata_json_path)
            raise MetadataError, 'Generated JSON file not found.'
          end
          freed_metadata_json_size = ::File.stat(freed_metadata_json_path).size
          if freed_metadata_json_size <= FREED_FILE_SIZE_CONSTRAINT
            # parole for good behavior
            return ::File.read(freed_metadata_json_path)
          else
            # life imprisonment.
            raise MetadataError,
                  "Generated metadata size of" +
                  " #{freed_metadata_json_size / 1024} KB" +
                  " exceeded the allowed limit of" +
                  " #{FREED_FILE_SIZE_CONSTRAINT / 1024} KB"
          end
        rescue ::RightScraper::Processes::Warden::LinkError => e
          raise MetadataError,
                "Failed to generate metadata from source: #{e.message}" +
                "\n#{e.link_result.stdout}" +
                "\n#{e.link_result.stderr}"
        end
      end
    end

    def stdout_tarball(data)
      @stdout_buffer << data
    end

    def stderr_tarball(data)
      @stderr_buffer.safe_buffer_data(data)
    end

    def timeout_tarball
      raise MetadataError,
        "Timed out waiting for tarball to build.\n" +
        "stdout: #{@stdout_buffer.join}\n" +
        "stderr: #{@stderr_buffer.display_text}"
    end

    def create_cookbook_tarball(dest_file, contents, dest_path)
      @logger.operation(:tarball_generation) do
        tarball_cmd = [
          'tar',
          "-Pcf #{dest_file}",
          "--transform='s,#{@cookbook.repo_dir},#{dest_path},'",
          contents
        ]

        @stdout_buffer = []
        @stderr_buffer = ::RightScale::RightPopen::SafeOutputBuffer.new
        begin
          ::RightScale::RightPopen.popen3_sync(
            tarball_cmd.join(' '),
            :target             => self,
            :timeout_handler    => :timeout_tarball,
            :stderr_handler     => :stderr_tarball,
            :stdout_handler     => :stdout_tarball,
            :inherit_io         => true,  # avoid killing any rails connection
            :timeout_seconds    => TARBALL_CREATE_TIMEOUT)
        rescue Exception => e
          raise MetadataError,
            "Failed to generate cookbook tarball from source files: #{e.message}\n" +
            "stdout: #{@stdout_buffer.join}\n" +
            "stderr: #{@stderr_buffer.display_text}"
        end
      end
    end

    # generates a script that runs Chef's knife tool. it presumes the jail
    # contains a ruby interpreter that has chef installed as a gem.
    #
    # we want to avoid using the knife command line only because it requires a
    # '$HOME/.chef/knife.rb' configuration file even though we won't use that
    # configuration file in any way. :@
    #
    # the simplest solution is to execute the knife tool within a ruby script
    # because it has no pre-configuration requirement and it does not require
    # the knife binstub to be on the PATH.
    def create_knife_metadata_script(script_path)
      script = <<EOS
require 'rubygems'
require 'chef'
require 'chef/knife/cookbook_metadata'

jailed_cookbook_dir = ARGV.pop
knife_metadata = ::Chef::Knife::CookbookMetadata.new
knife_metadata.name_args = [::File.basename(jailed_cookbook_dir)]
knife_metadata.config[:cookbook_path] = ::File.dirname(jailed_cookbook_dir)
knife_metadata.run
EOS
      ::File.open(script_path, 'w') { |f| f.puts script }
      true
    end

    # need to enumerate files relative to the cookbook directory because we
    # have no idea what the metadata script will attempt to consume from the
    # files available in its repository. it may even attempt to manipulate
    # files in the system or go out to the network, which may or may not be
    # allowed by the conditions of the jail.
    #
    # some cookbooks (for Windows, especially) will have large binaries
    # included in the repository. we don't want to spend time copying these
    # files into jail so limit the files that metadata can reference by size.
    # presumably the jail would also be limiting disk space so it is important
    # to avoid this source of failure.
    #
    # again, the user can work around these contraints by generating his own
    # metadata and checking it into the repository.
    def generate_copy_in()
      copy_in = []
      start_path = @cookbook.repo_dir
      recursive_generate_copy_in(copy_in, start_path)
      copy_in
    end

    # recursive part of generate_copy_in
    def recursive_generate_copy_in(copy_in, current_path)
      limited_files_of(current_path) { |file| copy_in << file }
      directories_of(current_path) do |dir|
        recursive_generate_copy_in(copy_in, ::File.join(dir))
      end
      true
    end

    # yields files in parent meeting size criteria.
    def limited_files_of(parent)
      ::Dir["#{parent}/*"].each do |item|
        if ::File.file?(item)
          if ::File.stat(item).size <= JAILED_FILE_SIZE_CONSTRAINT
            yield item
          else
            if ::File.basename(item) == RUBY_METADATA
              raise MetadataError,
                    'Metadata source file' +
                    " #{relative_to_repo_dir(item).inspect}" +
                    ' in repository exceeded size constraint of' +
                    " #{JAILED_FILE_SIZE_CONSTRAINT / 1024} KB"
            else
              message = 'Ignored a repository file during metadata' +
                        ' generation due to exceeding size constraint of' +
                        " #{JAILED_FILE_SIZE_CONSTRAINT / 1024} KB:" +
                        " #{relative_to_repo_dir(item).inspect}"
              @logger.info(message)
            end
          end
        end
      end
    end

    # yields directories of parent.
    def directories_of(parent)
      ::Dir["#{parent}/*"].each do |item|
        case item
        when '.', '..'
          # do nothing
        else
          yield item if ::File.directory?(item)
        end
      end
    end

    # converts the given absolute path to be relative to repo_dir.
    def relative_to_repo_dir(path)
      path[(@cookbook.repo_dir.length + 1)..-1]
    end

    # factory method for an object capable of running command in jail
    # (convenient for testing).
    def create_warden
      ::RightScraper::Processes::Warden.new
    end

    # factory method for tmpdir (convenient for testing).
    def create_tmpdir
      tls[:tmpdir] ||= ::Dir.mktmpdir
    end

  end
end
