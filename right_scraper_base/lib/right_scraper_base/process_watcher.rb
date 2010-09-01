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

require File.expand_path(File.join(File.dirname(__FILE__), 'processes', 'watcher'))
require File.expand_path(File.join(File.dirname(__FILE__), 'logger'))

module RightScale
  module ProcessWatcher
    # Watch command, respecting @max_bytes and @max_seconds.
    #
    # === Parameters ===
    # command(String):: command to run
    # args(Array):: arguments for the command
    # max_bytes(Integer):: maximum number of bytes to permit
    # max_seconds(Integer):: maximum number of seconds to permit to run
    #
    # === Returns
    # String:: output of command
    def watch(command, args, max_bytes, max_seconds)
      watcher = RightScale::Processes::Watcher.new(max_bytes, max_seconds)
      logger = @logger || Logger.new
      Dir.mktmpdir do |dir|
        logger.operation(:running_command, "in #{dir}, running #{command} #{args}") do
          result = watcher.launch_and_watch(command, args, dir)
          if result.status == :timeout
            raise "Timeout error"
          elsif result.status == :size_exceeded
            raise "Command took too much space"
          elsif result.exit_code != 0
            raise "Unknown error: #{result.exit_code} output #{result.output}"
          else
            result.output
          end
        end
      end
    end

    # Spawn given process, wait for it to complete, and return its output The exit status
    # of the process is available in the $? global. Functions similarly to the backtick
    # operator, only it avoids invoking the command interpreter under operating systems
    # that support fork-and-exec.
    #
    # This method accepts a variable number of parameters; the first param is always the
    # command to run; successive parameters are command-line arguments for the process.
    #
    # === Parameters
    # cmd(String):: Name of the command to run
    # arg1(String):: Optional, first command-line argumument
    # arg2(String):: Optional, first command-line argumument
    # ...
    # argN(String):: Optional, Nth command-line argumument
    #
    # === Return
    # output(String):: The process' output
    def run(cmd, *args)
      pm = RightScale::Processes::ProcessMonitor.new
      output = StringIO.new

      pm.spawn(cmd, *args) do |options|
        output << options[:output] if options[:output]
      end

      pm.cleanup
      output.close
      output = output.string
      return output
    end
  end
end
