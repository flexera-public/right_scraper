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

require 'find'

module RightScale

  # Encapsulate information returned by watcher
  class WatchStatus

    # Potential outcome of watcher
    VALID_STATUSES = [ :success, :timeout, :size_exceeded ]

    attr_reader :status    # One of VALID_STATUSES
    attr_reader :exit_code # Watched process exit code or -1 if process was killed
    attr_reader :output    # Watched process combined output

    # Initialize attibutes
    def initialize(status, exit_code, output)
      @status    = status
      @exit_code = exit_code
      @output    = output
    end

  end

  class Watcher

    attr_reader :max_bytes   # Maximum size in bytes of watched directory before process is killed
    attr_reader :max_seconds # Maximum number of elapased seconds before external process is killed

    # Initialize attributes
    #
    # max_bytes(Integer):: Maximum size in bytes of watched directory before process is killed
    # max_seconds(Integer):: Maximum number of elapased seconds before external process is killed
    def initialize(max_bytes, max_seconds)
      @max_bytes   = max_bytes
      @max_seconds = max_seconds
    end

    # Launch given command as external process and watch given directory
    # so it doesn't exceed given size. Also watch time elapsed and kill
    # external process if either the size of the watched directory exceed
    # @max_bytes or the time elapsed exceeds @max_seconds.
    # Note: This method is not thread-safe, instantiate one watcher per thread
    #
    # === Parameters
    # cmd(String):: Command line to be launched
    # dest_dir(String):: Watched directory
    #
    # === Return
    # res(RightScale::WatchStatus):: Outcome of watch, see RightScale::WatchStatus
    def launch_and_watch(cmd, dest_dir)
      status = nil
      output = ''

      # Run external process and monitor it in a new thread
      r = IO.popen(cmd)
      Thread.new do
        Process.wait(r.pid)
        status = $?
      end

      # Loop until process is done or times out or takes too much space
      timed_out = repeat(1, @max_seconds) do
        output += r.readlines.join
        if @max_bytes < 0
          status
        else
          size = 0
          Find.find(dest_dir) { |f| size += File.stat(f).size unless File.directory?(f) } if File.directory?(dest_dir)
          size > @max_bytes || status
        end
      end

      # Cleanup and report status
      output += r.readlines.join
      Process.kill('TERM', r.pid) unless status
      r.close
      s = status ? :success : (timed_out ? :timeout : :size_exceeded)
      exit_code = status && status.exitstatus || -1
      res = WatchStatus.new(s, exit_code, output)
    end

    protected

    # Run given block in thread and time execution
    #
    # === Block
    # Block whose execution is timed
    #
    # === Return
    # elapsed(Integer):: Number of seconds elapsed while running given block
    def timed
      start_at = Time.now
      yield
      elapsed = Time.now - start_at
    end

    # Repeat given block at regular intervals
    #
    # === Parameters
    # seconds(Integer):: Number of seconds between executions
    # timeout(Integer):: Timeout after which execution stops and method returns
    #
    # === Block
    # Given block gets executed every period seconds until timeout is reached
    # *or* block returns true
    #
    # === Return
    # res(TrueClass|FalseClass):: true if timeout is reached, false otherwise.
    def repeat(period, timeout)
      end_at = Time.now + timeout
      while res = (timeout < 0 || Time.now < end_at)
        exit = false
        elapsed = timed { exit = yield }
        break if exit
        sleep(period - elapsed) if elapsed < period
      end
      !res
    end

  end

end
