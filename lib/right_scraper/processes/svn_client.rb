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

module RightScraper::Processes

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
  class SvnClient

    class SvnClientError < StandardError; end

    attr_reader :repository, :shell

    # @param [RightScraper::Repositories::Base] repository to associate
    # @param [Object] shell for execution
    def initialize(repository, logger, shell)
      unless @repository = repository
        raise ::ArgumentError, 'repository is required'
      end
      unless @logger = logger
        raise ::ArgumentError, 'logger is required'
      end
      unless @shell = shell
        raise ::ArgumentError, 'shell is required'
      end
    end

    def self.calculate_version
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

    # Executes svn using the given arguments.
    #
    # @param [Array] args for svn
    #
    # @return [TrueClass] always true
    def execute(*args)
      shell.execute(svn_command_for(args), :logger => @logger)
      true
    end

    # Executes and returns output for svn using the given arguments.
    #
    # @param [Array] args for svn
    #
    # @return [String] output text
    def output_for(*args)
      shell.output_for(svn_command_for(args), :logger => @logger)
    end

    private

    def svn_command_for(*args)
      version = self.class.calculate_version
      svn_args = ['svn', args, '--no-auth-cache', '--non-interactive']
      case
      when (version[0] != 1 || version[1] < 4)
        raise SvnClientError, 'SVN client version is unsupported (~> 1.4)'
      when version[1] < 6
        # --trust-server-cert is a 1.6ism
      else
        svn_args << '--trust-server-cert'
      end
      if @repository.first_credential && @repository.second_credential
        svn_args << "--username"
        svn_args << @repository.first_credential
        svn_args << "--password"
        svn_args << @repository.second_credential
      end
      svn_args.flatten.join(' ')
    end
  end
end
