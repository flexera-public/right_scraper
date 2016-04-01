#--
# Copyright: Copyright (c) 2010-2016 RightScale, Inc.
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

require 'fileutils'
require 'json'
require 'right_git'
require 'right_popen'
require 'right_popen/safe_output_buffer'
require 'tmpdir'

module RightScraper::Scanners

  # Load cookbook metadata from a filesystem.
  class CookbookMetadata < ::RightScraper::Scanners::Base
    JSON_METADATA = 'metadata.json'
    RUBY_METADATA = 'metadata.rb'

    UNDEFINED_COOKBOOK_NAME    = 'undefined'
    KNIFE_METADATA_SCRIPT_NAME = 'knife_metadata.rb'
    KNIFE_METADATA_TIMEOUT     = 60  # 1m

    JAILED_FILE_SIZE_CONSTRAINT = 128 * 1024  # 128 KB
    FREED_FILE_SIZE_CONSTRAINT  = 64 * 1024  # 64 KB


    attr_reader :freed_dir

    # exceptions
    class MetadataError < ::RightScraper::Error; end

    def initialize(options)
      super

      # we will free the generated 'metadata.json' to a path relative to the
      # repository directory. this allows for multiple passes over the
      # generated file(s) using different child processes, some or all of
      # which may execute in containers. the exact location of the freed file
      # depends on the cookbook position; recall that multiple cookbooks can
      # appear within a given repository.
      @freed_dir = options[:freed_dir].to_s
      if @freed_dir.empty? || !::File.directory?(@freed_dir)
        raise ::ArgumentError, "Missing or invalid freed_dir: #{@freed_dir.inspect}"
      end
    end

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

    # All done scanning this repository.
    #
    def finish
      begin
        ::FileUtils.remove_entry_secure(tls[:tmpdir]) if tls[:tmpdir]
      rescue ::Exception => e
        @logger.note_warning(e.message)
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
    # to evaluate arbitrary Ruby code, we need to sandbox it first.
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
        tmpdir, created = create_tmpdir

        # path constants
        src_knife_script_path = ::File.expand_path(
            ::File.join(__FILE__, '../../../../scripts', KNIFE_METADATA_SCRIPT_NAME))
        dst_knife_script_dir = tmpdir
        dst_knife_script_path = ::File.join(dst_knife_script_dir, KNIFE_METADATA_SCRIPT_NAME)
        jailed_repo_dir = ::File.join(tmpdir, UNDEFINED_COOKBOOK_NAME)
        jailed_cookbook_dir = (@cookbook.pos == '.' && jailed_repo_dir) || ::File.join(jailed_repo_dir, @cookbook.pos)
        jailed_metadata_json_path = ::File.join(jailed_cookbook_dir, JSON_METADATA)
        freed_metadata_dir = (@cookbook.pos == '.' && freed_dir) || ::File.join(freed_dir, @cookbook.pos)
        freed_metadata_json_path = ::File.join(freed_metadata_dir, JSON_METADATA)

        # in the multi-pass case we will run this scanner only on the first pass
        # so the 'metadata.json' file should not exist. the read-only scanner,
        # which is safe outside of containment, should be used subsequently.
        # the entire 'freed' directory should have been removed upon the next
        # successful retrieval so that this scanner will succeed.
        if ::File.file?(freed_metadata_json_path)
          raise MetadataError, "Refused to overwrite already-generated metadata file: #{freed_metadata_json_path}"
        end

        # jail the repo using the legacy semantics for copying files in and out
        # of jail.
        copy_out = { jailed_metadata_json_path => freed_metadata_json_path }

        # copy files into the jail once per repository (i.e. not once per
        # cookbook within the repository).
        if created
          copy_in = generate_copy_in(@cookbook.repo_dir, jailed_repo_dir)
          copy_in[src_knife_script_path] = dst_knife_script_path

          # note that at this point we previously used Warden as a container
          # for the copied-in files but now we assume that the current process
          # is already in a container (i.e. Docker) and so this copying is
          # more about creating a writable directory for knife than about
          # containment. the checked-out repo should be read-only to this
          # contained process due to running with limited privileges.
          do_copy_in(copy_in)
        end

        # HACK: support ad-hoc testing in dev-mode by using the current version
        # for rbenv shell.
        if ::ENV['RBENV_VERSION'].to_s.empty?
          ruby = 'ruby'
        else
          ruby = `which ruby`.chomp
        end

        # execute knife as a child process. any constraints are assumed to be
        # imposed on the current process by a container (timeout, memory, etc.)
        shell = ::RightGit::Shell::Default
        output = StringIO.new
        begin
          shell.execute(
            "#{ruby} #{dst_knife_script_path.inspect} #{jailed_cookbook_dir.inspect} 2>&1",
            directory: dst_knife_script_dir,
            outstream: output,
            raise_on_failure: true,
            set_env_vars: { LC_ALL: 'en_US.UTF-8' },  # character encoding for emitted JSON
            clear_env_vars: %w{BUNDLE_BIN_PATH BUNDLE_GEMFILE},
            timeout: KNIFE_METADATA_TIMEOUT)
          output = output.string
        rescue ::RightGit::Shell::ShellError => e
          output = output.string
          raise MetadataError, "Failed to run chef knife: #{e.message}\n#{output[0, 1024]}"
        end

        # free files from jail.
        do_copy_out(copy_out)

        # load and return freed metadata.
        return ::File.read(freed_metadata_json_path)
      end
    end

    # copies files into jail. we no longer start a new container so this is only
    # a local file copying operation. we still need files to appear in a
    # writable directory location because knife will write to the directory.
    def do_copy_in(path_map)
      path_map.each do |src_path, dst_path|
        if src_path != dst_path
          ::FileUtils.mkdir_p(::File.dirname(dst_path))
          ::FileUtils.cp(src_path, dst_path)
        end
      end
      true
    end

    # copies files out of jail by mapping of jail to free path.
    def do_copy_out(path_map)
      path_map.each do |src_path, dst_path|
        # constraining the generated 'metadata.json' size is debatable, but
        # our UI attempts to load metadata JSON into memory far too often to
        # be blasé about generating multi-megabyte JSON files.
        unless ::File.file?(src_path)
          raise MetadataError, "Expected generated file was not found: #{src_path}"
        end
        src_size = ::File.stat(src_path).size
        if src_size <= FREED_FILE_SIZE_CONSTRAINT
          ::FileUtils.mkdir_p(::File.dirname(dst_path))
          ::FileUtils.cp(src_path, dst_path)
        else
          raise MetadataError,
                "Generated file size of" +
                " #{src_size / 1024} KB" +
                " exceeded the allowed limit of" +
                " #{FREED_FILE_SIZE_CONSTRAINT / 1024} KB"
        end
      end
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
    #
    # @return [Hash] path_map as map of source to destination file paths
    def generate_copy_in(src_base_path, dst_base_path)
      src_base_path = ::File.expand_path(src_base_path)
      dst_base_path = ::File.expand_path(dst_base_path)
      copy_in = []
      recursive_generate_copy_in(copy_in, src_base_path)

      src_base_path += '/'
      src_base_path_len = src_base_path.length
      dst_base_path += '/'
      copy_in.inject({}) do |h, src_path|
        h[src_path] = ::File.join(dst_base_path, src_path[src_base_path_len..-1])
        h
      end
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

    # factory method for tmpdir (convenient for testing).
    def create_tmpdir
      td = tls[:tmpdir]
      if td.nil?
        td = ::Dir.mktmpdir
        tls[:tmpdir] = td
        created = true
      else
        created = false
      end
      return [td, created]
    end

  end # CookbookMetadata
end # RightScraper::Scanners
