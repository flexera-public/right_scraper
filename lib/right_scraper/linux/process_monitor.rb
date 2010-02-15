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

module RightScale

  # *nix specific watcher implementation
  class ProcessMonitor

    # Spawn given process and callback given block with output and exit code
    #
    # === Parameters
    # cmd(String):: Process command line (including arguments)
    #
    # === Block
    # Given block should take one argument which is a hash which may contain
    # the keys :output and :exit_code. The value associated with :output is a chunk
    # of output while the value associated with :exit_code is the process exit code
    # This block won't be called anymore once the :exit_code key has associated value
    #
    # === Return
    # pid(Integer):: Spawned process pid
    def spawn(cmd)
      # Run external process and monitor it in a new thread
      @io = IO.popen(cmd)
      @reader = Thread.new do
        o = @io.read
        until o == ''
          yield(:output => o)
          o = @io.read
        end
        Process.wait(@io.pid)
        yield(:exit_code => $?.exitstatus)
      end
      @io.pid
    end

    # Close io and join reader thread
    #
    # === Return
    # true:: Always return true
    def cleanup
      @reader.join
      @io.close
    end

  end
end
