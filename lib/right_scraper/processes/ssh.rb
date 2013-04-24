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

require 'tempfile'
require 'tmpdir'
require 'right_popen'
require 'right_popen/safe_output_buffer'

module RightScraper
  module Processes
    # Manage a dedicated SSH agent.
    class SSHAgent

      class SSHAgentError < Exception; end

      def initialize
        @display = ENV['DISPLAY']
        @askpass = ENV['SSH_ASKPASS']
        @sshauth = ENV['SSH_AUTH_SOCK']
        @agentpid = ENV['SSH_AGENT_PID']
        @home = ENV['HOME']
      end

      # Open a connection to the SSH agent and set +ENV+
      # appropriately.
      def open
        ENV['SSH_ASKPASS'] = File.expand_path(File.join(File.dirname(__FILE__),
                                                        '..', '..', '..',
                                                        'scripts',
                                                        'stub_ssh_askpass'))
        ENV['HOME'] = "/dev/null"
        @dir = Dir.mktmpdir
        @socketfile = File.join(@dir, "agent")
        @process = nil
        @interupted_to_close = false
        @ssh_agent_output = ::RightScale::RightPopen::SafeOutputBuffer.new
        cmd = ['ssh-agent', '-a', @socketfile, '-d']
        ::RightScale::RightPopen.popen3_sync(
          cmd,
          :target          => self,
          :inherit_io      => true,  # avoid killing any rails connection
          :watch_handler   => :watch_ssh_agent,
          :stderr_handler  => :output_ssh_agent,
          :stdout_handler  => :output_ssh_agent,
          :timeout_handler => :timeout_ssh_agent,
          :exit_handler    => :exit_ssh_agent,
          :timeout_seconds => 10)
        if @process
          ENV['SSH_AGENT_PID'] = @process.pid.to_s
          ENV['SSH_AUTH_SOCK'] = @socketfile
        end
      end

      # Close the connection to the SSH agent, and restore +ENV+.
      def close
        begin
          FileUtils.remove_entry_secure @dir
          lay_to_rest
        ensure
          setvar 'SSH_AGENT_PID', @agentpid
          setvar 'DISPLAY', @display
          setvar 'SSH_ASKPASS', @askpass
          setvar 'SSH_AUTH_SOCK', @sshauth
          setvar 'HOME', @home
        end
      end

      def output_ssh_agent(data)
        @ssh_agent_output.safe_buffer_data(data)
      end

      # abandons watch when socket file appears
      #
      # @return [TrueClass|FalseClass] true to continue watch, false to abandon
      def watch_ssh_agent(process)
        if @interupted_to_close
          true
        else
          @process = process
          !::File.exists?(@socketfile)
        end
      end

      def timeout_ssh_agent
        unless @interupted_to_close
          raise SSHAgentError, 'Timed out waiting for ssh-agent control socket to appear'
        end
      end

      def exit_ssh_agent(status)
        unless @interupted_to_close || status.success?
          @ssh_agent_output.safe_buffer_data("Exit code = #{status.exitstatus}")
          raise SSHAgentError, "ssh-agent failed: #{@ssh_agent_output.display_text}"
        end
        true
      end

      # Add the given key data to the ssh agent.
      #
      # === Parameters
      # key(String):: ssh key data
      def add_key(key)
        begin
          file = Tempfile.new('key')
          file.puts(key)
          file.close

          add_keyfile(file.path)
        ensure
          file.close(true) unless file.nil?
        end
      end

      # Add the key data in the given file to the ssh agent.
      #
      # === Parameters
      # file(String):: file containing key data
      def add_keyfile(file)
        @ssh_add_output = ::RightScale::RightPopen::SafeOutputBuffer.new
        cmd = ['ssh-add', file]
        ::RightScale::RightPopen.popen3_sync(
          cmd,
          :target          => self,
          :inherit_io      => true,  # avoid killing any rails connection
          :stderr_handler  => :output_ssh_add,
          :stdout_handler  => :output_ssh_add,
          :timeout_handler => :timeout_ssh_add,
          :exit_handler    => :exit_ssh_add,
          :timeout_seconds => 10)
      end

      def output_ssh_add(data)
        @ssh_add_output.safe_buffer_data(data)
      end

      def timeout_ssh_add
        raise SSHAgentError, 'ssh-add timed out'
      end

      def exit_ssh_add(status)
        unless status.success?
          @ssh_add_output.safe_buffer_data("Exit code = #{status.exitstatus}")
          raise SSHAgentError, "ssh-add failed: #{@ssh_add_output.display_text}"
        end
        true
      end

      # Execute the block in a new ssh agent.
      # Equivalent to
      #  agent = SSHAgent.new
      #  begin
      #   agent.open
      #   ...
      #  ensure
      #   agent.close
      #  end
      def self.with
        agent = SSHAgent.new
        begin
          agent.open
          yield agent
        ensure
          agent.close
        end
      end

      private

      def lay_to_rest
        if @process
          if @process.interrupt
            @interupted_to_close = true
            @process.sync_exit_with_target
          else
            @process.safe_close_io
          end
        end
      end

      # Set an environment variable to a value.  If +value+ is nil,
      # delete the variable instead.
      #
      # === Parameters
      # key(String):: environment variable name
      # value(String or nil):: proposed new value
      #
      # === Return
      # true
      def setvar(key, value)
        if value.nil?
          ENV.delete(key)
        else
          ENV[key] = value
        end
        true
      end

    end
  end
end
