#--
# Copyright: Copyright (c) 2010 RightScale, Inc.
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
require File.expand_path(File.join(File.dirname(__FILE__), 'watch'))
require 'tempfile'

module RightScale
  module Processes
    # Manage a dedicated SSH agent.
    class SSHAgent
      include ProcessWatcher

      def initialize
        @display = ENV['DISPLAY']
        @askpass = ENV['SSH_ASKPASS']
        @sshauth = ENV['SSH_AUTH_SOCK']
        @agentpid = ENV['SSH_AGENT_PID']
      end

      # Open a connection to the SSH agent and set +ENV+
      # appropriately.
      def open
        output = watch('ssh-agent', ['-s'], -1, 10)
        output.split(/\n/).each do |line|
          if line =~ /^(SSH_\w+)=(.*?); export \1;$/
            ENV[$1] = $2
          end
        end
      end

      # Close the connection to the SSH agent, and restore +ENV+.
      def close
        begin
          watch('ssh-agent', ['-k'], -1, 10)
        ensure
          ENV['SSH_AGENT_PID'] = @agentpid unless @agentpid.nil?
          ENV['DISPLAY'] = @display unless @display.nil?
          ENV['SSH_ASKPASS'] = @askpass unless @askpass.nil?
          ENV['SSH_AUTH_SOCK'] = @sshauth unless @sshauth.nil?
        end
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
        watch("ssh-add", [file], -1, 10)
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
    end
  end
end
