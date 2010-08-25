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
    # Spawn given process and callback given block with output and exit code. This method
    # accepts a variable number of parameters; the first param is always the command to
    # run; successive parameters are command-line arguments for the process.
    #
    # === Parameters
    # cmd(String):: Name of the command to run
    # arg1(String):: Optional, first command-line argumument
    # arg2(String):: Optional, first command-line argumument
    # ...
    # argN(String):: Optional, Nth command-line argumument
    #
    # === Block
    # Given block should take one argument which is a hash which may contain
    # the keys :output and :exit_code. The value associated with :output is a chunk
    # of output while the value associated with :exit_code is the process exit code
    # This block won't be called anymore once the :exit_code key has associated value
    #
    # === Return
    # pid(Integer):: Spawned process pid
    def spawn(cmd, *args)
      args = args.map { |a| a.to_s } #exec only likes string arguments

      #Run subprocess; capture its output using a pipe
      pr, pw = IO::pipe
      @pid = fork do
        oldstderr = STDERR.clone
        pr.close
        STDIN.reopen(File.open('/dev/null', 'r'))
        STDOUT.reopen(pw)
        STDERR.reopen(pw)
        begin
          exec(cmd, *args)
        rescue
          oldstderr.puts "Couldn't exec: #{$!}"
        end
      end

      #Monitor subprocess output and status in a dedicated thread
      pw.close
      @io = pr
      @reader = Thread.new do
        wait_result = nil
        loop do
          wait_result = Process.waitpid2(@pid, Process::WNOHANG)
          break unless wait_result.nil?
          array = select([@io], nil, nil, 0.1)
          array[0].each do |fdes|
            unless fdes.eof?
              # HACK HACK HACK 4096 is a magic number I pulled out of my
              # ass, the real one should depend on the kernel's buffer
              # sizes.
              result = fdes.readpartial(4096)
              yield(:output => result)
            end
          end unless array.nil?
        end
        dontcare, status = wait_result
        yield(:exit_code => status.exitstatus)
      end

      return @pid
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
