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
require 'right_scraper/retrievers'

require 'fileutils'
require 'tempfile'
require 'digest/sha1'
require 'right_popen'
require 'right_popen/safe_output_buffer'

module RightScraper::Retrievers

  # A retriever for resources stored in archives on a web server
  # somewhere.  Uses command line curl and command line tar.
  class Download < ::RightScraper::Retrievers::Base

    class DownloadError < Exception; end

    @@available = false

    # Determines if downloader is available.
    def available?
      unless @@available
        begin
          # FIX: we might want to parse the result and require a minimum curl
          # version.
          cmd = "curl --version"
          `#{cmd}`
          if $?.success?
            @@available = true
          else
            raise RetrieverError, "\"#{cmd}\" exited with #{$?.exitstatus}"
          end
        rescue
          @logger.note_error($!, :available, "download retriever is unavailable")
        end
      end
      @@available
    end

    # Directory used to download tarballs
    def workdir
      @workdir ||= ::File.join(::File.dirname(@repo_dir), 'download')
    end

    # Download tarball and unpack it
    def retrieve
      raise RetrieverError.new("download retriever is unavailable") unless available?
      ::FileUtils.remove_entry_secure @repo_dir if File.exists?(@repo_dir)
      ::FileUtils.remove_entry_secure workdir if File.exists?(workdir)
      ::FileUtils.mkdir_p @repo_dir
      ::FileUtils.mkdir_p workdir
      file = ::File.join(workdir, "package")

      # TEAL FIX: we have to always-download the tarball before we can
      # determine if contents have changed, but afterward we can compare the
      # previous download against the latest downloaded and short-circuit the
      # remaining flow for the no-difference case.
      @logger.operation(:downloading) do
        credential_command = if @repository.first_credential && @repository.second_credential
          ['-u', "#{@repository.first_credential}:#{@repository.second_credential}"]
        else
          []
        end
        @output = ::RightScale::RightPopen::SafeOutputBuffer.new
        @cmd = [
          'curl',
          '--silent', '--show-error', '--location', '--fail',
          '--location-trusted', '-o', file, credential_command,
          @repository.url
        ].flatten
        begin
          ::RightScale::RightPopen.popen3_sync(
            @cmd,
            :target             => self,
            :pid_handler        => :pid_download,
            :timeout_handler    => :timeout_download,
            :size_limit_handler => :size_limit_download,
            :exit_handler       => :exit_download,
            :stderr_handler     => :output_download,
            :stdout_handler     => :output_download,
            :inherit_io         => true,  # avoid killing any rails connection
            :watch_directory    => workdir,
            :size_limit_bytes   => @max_bytes,
            :timeout_seconds    => @max_seconds)
        rescue Exception => e
          @logger.note_phase(:abort, :running_command, 'curl', e)
          raise
        end
      end

      note_tag(file)

      @logger.operation(:unpacking) do
        path = @repository.to_url.path
        if path =~ /\.gz$/
          extraction = "xzf"
        elsif path =~ /\.bz2$/
          extraction = "xjf"
        else
          extraction = "xf"
        end
        Dir.chdir(@repo_dir) do
          @output = ::RightScale::RightPopen::SafeOutputBuffer.new
          @cmd = ['tar', extraction, file]
          begin
            ::RightScale::RightPopen.popen3_sync(
              @cmd,
              :target             => self,
              :pid_handler        => :pid_download,
              :timeout_handler    => :timeout_download,
              :size_limit_handler => :size_limit_download,
              :exit_handler       => :exit_download,
              :stderr_handler     => :output_download,
              :stdout_handler     => :output_download,
              :inherit_io         => true,  # avoid killing any rails connection
              :watch_directory    => @repo_dir,
              :size_limit_bytes   => @max_bytes,
              :timeout_seconds    => @max_seconds)
          rescue Exception => e
            @logger.note_phase(:abort, :running_command, @cmd.first, e)
            raise
          end
        end
      end
      true
    end

    def pid_download(pid)
      @logger.note_phase(:begin, :running_command, @cmd.first)
      true
    end

    def output_download(data)
      @output.safe_buffer_data(data)
    end

    def timeout_download
      raise DownloadError, "Downloader timed out"
    end

    def size_limit_download
      raise DownloadError, "Downloader exceeded size limit"
    end

    def exit_download(status)
      unless status.success?
        @output.safe_buffer_data("Exit code = #{status.exitstatus}")
        raise DownloadError, "Downloader failed: #{@output.display_text}"
      end
      @logger.note_phase(:commit, :running_command, @cmd.first)
      true
    end


    # Amend @repository with the tag information from the downloaded
    # file.
    #
    # === Parameters
    # file(String):: file that was downloaded
    def note_tag(file)
      digest = Digest::SHA1.new
      File.open(file) {|f| digest << f.read(4096) }
      repo = @repository.clone
      repo.tag = digest.hexdigest
      @repository = repo
    end
  end
end
