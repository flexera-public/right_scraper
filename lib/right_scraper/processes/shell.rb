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
  module Processes

    # provides a shell with configurable properties that satisfies the interface
    # for a shell for right_git but can be used for other scraper actions.
    class Shell
      include ::RightGit::Shell::Interface

      # exceptions.
      class LimitError < ShellError; end

      class SizeLimitError < LimitError; end
      class TimeLimitError < LimitError; end

      MAX_SAFE_BUFFER_LINE_COUNT  = 10
      MAX_SAFE_BUFFER_LINE_LENGTH = 80

      attr_reader :retriever

      attr_accessor :initial_directory, :stop_timestamp

      # @param [RightScraper::Repositories::Base] retriever associated with shell
      # @param [Hash] options for shell
      # @option options [Integer] :stop_timestamp for interruption (Default = max_seconds from retriever)
      def initialize(retriever)
        options = {
          :stop_timestamp    => nil,
          :initial_directory => nil,
        }.merge(options)
        unless @retriever = retriever
          raise ::ArgumentError.new('retriever is required')
        end

        # set stop time once for the lifetime of this shell object.
        @stop_timestamp = options[:stop_timestamp]
        if @stop_timestamp.nil? && @retriever.max_seconds
          @stop_timestamp = (::Time.now + @retriever.max_seconds).to_i
        end
        unless @initial_directory = options[:initial_directory]
          @initial_directory = @retriever.repo_dir
        end
      end

      # Implements execute interface.
      #
      # @param [String] cmd the shell command to run
      # @param [Hash] options for execution
      #
      # @return [Integer] exitstatus of the command
      #
      # @raise [ShellError] on failure only if :raise_on_failure is true
      def execute(cmd, options = {})
        inner_execute(cmd, safe_output_handler, options)
        true
      ensure
        @output = nil
      end

      # Implements output_for interface.
      #
      # @param [String] cmd command to execute
      # @param [Hash] options for execution
      #
      # @return [String] entire output (stdout) of the command
      #
      # @raise [ShellError] on failure only if :raise_on_failure is true
      def output_for(cmd, options = {})
        inner_execute(cmd, unsafe_output_handler, options)
        @output.display_text
      ensure
        @output = nil
      end

      # Buffers output safely.
      #
      # @param [String] data
      #
      # @return [TrueClass] always true
      def safe_output_handler(data)
        @output.safe_buffer_data(data)
        true
      end

      # Buffers output unsafely but completely.
      #
      # @param [String] data
      #
      # @return [TrueClass] always true
      def unsafe_output_handler(data)
        @output.buffer << data.chomp
        true
      end

      # Raises size limit error.
      #
      # @raise [SizeLimitError] always
      def size_limit_handler
        raise SizeLimitError, "Exceeded size limit on repository directory: #{@retriever.repo_dir}"
      end

      # Raises timeout error.
      #
      # @raise [TimeLimitError] always
      def timeout_handler
        raise TimeLimitError, "Timed-out after #{@retriever.max_seconds} seconds"
      end

      # Handles exit status.
      #
      # @param [Status] status after execution
      #
      # @return [TrueClass] always true
      #
      # @raise [ShellError] on execution failure
      def exit_handler(status)
        unless status.success?
          @output.buffer << "Exit code = #{status.exitstatus}"
          raise ShellError, "Execution failed: #{@output.display_text}"
        end
        true
      end

      private

      def inner_execute(cmd, output_handler, options)
        # max seconds decreases over lifetime of shell until no more commands
        # can be executed due to initial time constraint.
        max_seconds = @stop_timestamp - ::Time.now.to_i
        min_seconds = 5  # process start, a network gesture, etc.
        timeout_handler if max_seconds < min_seconds

        # use safe buffer (allows both safe and unsafe buffering) with
        # limited buffering for output that is only seen on error.
        @output = ::RightScale::RightPopen::SafeOutputBuffer.new(
          buffer          = [],
          max_line_count  = MAX_SAFE_BUFFER_LINE_COUNT,
          max_line_length = MAX_SAFE_BUFFER_LINE_LENGTH)

        # initial checkout (i.e. clone) is to a specified non-existing
        # directory; no initial directory only in that case.
        working_directory =
          (@initial_directory && ::File.directory?(@initial_directory)) ?
          @initial_directory :
          nil

        # always watch the repo directory regardless of working directory so
        # so that submodules are treated as part of parent repo for size and
        # time limit purposes.
        #
        # note that the watch_directory logic does effectively nothing until the
        # directory appears on disk.
        watch_directory = @retriever.repo_dir

        # synchronous popen with watchers, etc.
        ::RightScale::RightPopen.popen3_sync(
          cmd,
          :target             => self,
          :directory          => working_directory,
          :timeout_handler    => :timeout_handler,
          :size_limit_handler => :size_limit_handler,
          :exit_handler       => :exit_handler,
          :stderr_handler     => output_handler,
          :stdout_handler     => output_handler,
          :inherit_io         => true,  # avoid killing any rails connection
          :watch_directory    => watch_directory,
          :size_limit_bytes   => @retriever.max_bytes,
          :timeout_seconds    => max_seconds)
        true
      end

    end
  end
end
