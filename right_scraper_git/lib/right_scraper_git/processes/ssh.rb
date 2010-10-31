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
require 'tempfile'
require 'process_watcher'

module RightScraper
  module Processes
    # Manage a dedicated SSH agent.
    class SSHAgent
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
        output = ProcessWatcher.watch('ssh-agent', ['-s'], nil, -1, 10)
        output.split(/\n/).each do |line|
          if line =~ /^(SSH_\w+)=(.*?); export \1;$/
            ENV[$1] = $2
          end
        end
        ENV['SSH_ASKPASS'] = File.expand_path(File.join(File.dirname(__FILE__),
                                                        '..', '..', '..',
                                                        'scripts',
                                                        'stub_ssh_askpass'))
        ENV['HOME'] = "/dev/null"
      end

      # Close the connection to the SSH agent, and restore +ENV+.
      def close
        begin
          lay_to_rest(ENV['SSH_AGENT_PID'].to_i)
        ensure
          setvar 'SSH_AGENT_PID', @agentpid
          setvar 'DISPLAY', @display
          setvar 'SSH_ASKPASS', @askpass
          setvar 'SSH_AUTH_SOCK', @sshauth
          setvar 'HOME', @home
        end
      end

      # Kill +pid+.  Initially use SIGTERM to be kind and a good
      # citizen.  If it doesn't die after +timeout+ seconds, use
      # SIGKILL instead.  In any case, the process will die.  The
      # status information is accessible in $?.
      #
      # === Parameters
      # pid(Fixnum):: pid of process to kill
      # timeout(Fixnum):: time in seconds to wait before forcing
      #                   process to die.  Defaults to 10 seconds.
      def lay_to_rest(pid, timeout=10)
        Process.kill('TERM', pid)
        time_waited = 0
        loop do
          if time_waited >= timeout
            Process.kill('KILL', pid)
            # can't waitpid here, because the ssh-agent isn't our
            # child.  Still, after SIGKILL it will die and init will
            # reap it, so continue
            return
          end
          # still can't waitpid here, so we see if it's still alive
          return unless still_alive?(pid)
          sleep 1
          time_waited += 1
        end
      end

      # Check to see if the process +pid+ is still alive, by sending
      # the 0 signal and checking for an exception.
      #
      # === Parameters
      # pid(Fixnum):: pid of process to check on
      #
      # === Return
      # Boolean:: true if process is still alive
      def still_alive?(pid)
        begin
          Process.kill(0, pid)
          true
        rescue Errno::ESRCH
          false
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
      private :setvar

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
        ProcessWatcher.watch("ssh-add", [file], nil, -1, 10)
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
