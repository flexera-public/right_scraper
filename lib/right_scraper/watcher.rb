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
if RUBY_PLATFORM =~ /mswin/
  require File.expand_path(File.join(File.dirname(__FILE__), 'win32', 'process_monitor'))
else
  require File.expand_path(File.join(File.dirname(__FILE__), 'linux', 'process_monitor'))
end

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
    def launch_and_watch(cmd, args, dest_dir)
      exit_code = nil
      output    = ''
      monitor   = ProcessMonitor.new

      # Run external process and monitor it in a new thread, platform specific
      pid = monitor.spawn(cmd, *args) do |data|
        output << data[:output] if data[:output]
        exit_code = data[:exit_code] if data.include?(:exit_code)
      end

      # Loop until process is done or times out or takes too much space
      timed_out = repeat(1, @max_seconds) do
        if @max_bytes < 0
          exit_code
        else
          size = 0
          Find.find(dest_dir) { |f| size += File.stat(f).size rescue 0 if File.file?(f) } if File.directory?(dest_dir)
          size > @max_bytes || exit_code
        end
      end

      # Cleanup and report status
      # Note: We need to store the exit status before we kill the underlying process so that
      # if it finished in the mean time we still report -1 as exit code
      if exit_code
        exit_status = exit_code
        outcome = :success
      else
        exit_status = -1
        outcome = (timed_out ? :timeout : :size_exceeded)
        Process.kill('INT', pid)
      end

      # Cleanup any open handle etc., platform specific
      monitor.cleanup

      res = WatchStatus.new(outcome, exit_status, output)
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
