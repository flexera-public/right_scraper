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

require 'right_popen'
require 'right_popen/safe_output_buffer'

module RightScraper
  # Simplified interface to the process of creating SVN client
  # contexts.
  #
  # SVN client contexts are needed for almost every nontrivial SVN
  # operation, and the authentication procedure is truly baroque.
  # Thus, when you need a client context, do something like this:
  #   client = SvnClient.new(repository)
  #   client.with_context do |ctx|
  #     ...
  #   end
  module SvnClient

    class SvnClientError < Exception; end

    def calculate_version
      unless @svn_version
        begin
          cmd = 'svn --version --quiet'
          out = `#{cmd}`
          if $?.success?
            @svn_version = out.chomp.split('.').map {|e| e.to_i}
          else
            raise SvnClientError, "Unable to determine svn version: #{cmd.inspect} exited with #{$?.exitstatus}"
          end
        rescue Errno::ENOENT => e
          raise SvnClientError, "Unable to determine svn version: #{e.message}"
        end
      end
      @svn_version
    end

    def svn_arguments
      version = calculate_version
      case
      when version[0] != 1
        raise "SVN major revision is not 1, cannot be sure it will run properly."
      when version[1] < 4
        raise "SVN minor revision < 4; cannot be sure it will run properly."
      when version[1] < 6
        # --trust-server-cert is a 1.6ism
        args = ["--no-auth-cache", "--non-interactive"]
      else
        args = ["--no-auth-cache", "--non-interactive", "--trust-server-cert"]
      end
      if repository.first_credential && repository.second_credential
        args << "--username"
        args << repository.first_credential
        args << "--password"
        args << repository.second_credential
      end
      args
    end

    def get_tag_argument
      if repository.tag
        tag_cmd = ["-r", get_tag.to_s]
      else
        tag_cmd = ["-r", "HEAD"]
      end
    end

    def run_svn_no_chdir(*args)
      run_svn_with(nil, :safe_output_svn_client, *args)
    end

    def run_svn(*args)
      run_svn_with(repo_dir, :safe_output_svn_client, *args)
    end

    def run_svn_with_buffered_output(*args)
      run_svn_with(repo_dir, :unsafe_output_svn_client, *args)
    end

    # runs svn client with safe buffering (by default).
    #
    # === Parameters
    # @param [Array] args for svn client command line
    #
    # === Return
    # @return [Array] lines of output or empty
    def run_svn_with(initial_directory, output_handler, *args)
      @output = ::RightScale::RightPopen::SafeOutputBuffer.new
      @output_handler = output_handler
      cmd = ['svn', args, svn_arguments].flatten
      ::RightScale::RightPopen.popen3_sync(
        cmd,
        :target             => self,
        :directory          => initial_directory,
        :timeout_handler    => :timeout_svn_client,
        :size_limit_handler => :size_limit_svn_client,
        :exit_handler       => :exit_svn_client,
        :stderr_handler     => output_handler,
        :stdout_handler     => output_handler,
        :inherit_io         => true,  # avoid killing any rails connection
        :watch_directory    => repo_dir,
        :size_limit_bytes   => @max_bytes,
        :timeout_seconds    => @max_seconds)
      @output.buffer
    end

    def safe_output_svn_client(data)
      @output.safe_buffer_data(data)
    end

    def unsafe_output_svn_client(data)
      @output.buffer << data.chomp
    end

    def timeout_svn_client
      raise SvnClientError, "svn client timed out"
    end

    def size_limit_svn_client
      raise SvnClientError, "svn client exceeded size limit"
    end

    def exit_svn_client(status)
      unless status.success?
        self.method(@output_handler).call("Exit code = #{status.exitstatus}")
        raise SvnClientError, "svn client failed: #{@output.display_text}"
      end
      true
    end

    # Fetch the tag from the repository, or nil if one doesn't
    # exist.  This is a separate method because the repo tag should
    # be a number but is a string in the database.
    def get_tag
      case repository.tag
      when Fixnum then repository.tag
      when /^\d+$/ then repository.tag.to_i
      else
        repository.tag
      end
    end
  end
end
