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

# ancestor
require 'right_scraper/processes'

require 'right_git'
require 'right_popen'
require 'right_popen/safe_output_buffer'

module RightScraper
  module Processes

    # provides a shell with configurable properties that satisfies the interface
    # for a shell for right_git but can be used for other scraper actions.
    class Shell
      include ::RightGit::Shell::Interface

      # exceptions.
      class LimitError < ::RightGit::Shell::ShellError; end

      class SizeLimitError < LimitError; end
      class TimeLimitError < LimitError; end

      MAX_SAFE_BUFFER_LINE_COUNT  = 10
      MAX_SAFE_BUFFER_LINE_LENGTH = 128

      attr_accessor :initial_directory, :max_seconds, :max_bytes
      attr_accessor :stop_timestamp, :watch_directory

      # @param [RightScraper::Repositories::Base] retriever associated with shell
      # @param [Hash] options for shell
      # @option options [Integer] :initial_directory for child process (Default = use current directory)
      # @option options [Integer] :max_bytes for interruption (Default = no byte limit)
      # @option options [Integer] :max_seconds for interruption (Default = no time limit)
      # @option options [Integer] :watch_directory for interruption (Default = no byte limit)
      def initialize(options = {})
        options = {
          :initial_directory => nil,
          :max_bytes         => nil,
          :max_seconds       => nil,
          :watch_directory   => nil,
        }.merge(options)

        @initial_directory = options[:initial_directory]
        @max_bytes = options[:max_bytes]
        @max_seconds = options[:max_seconds]
        @watch_directory = options[:watch_directory]

        # set stop time once for the lifetime of this shell object.
        @stop_timestamp = (::Time.now + @max_seconds).to_i if @max_seconds
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
        inner_execute(cmd, :safe_output_handler, options)
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
        inner_execute(cmd, :unsafe_output_handler, options)
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
        message =
          "Exceeded size limit of #{@max_bytes / (1024 * 1024)} MB on " +
          "repository directory. Hidden file and directory sizes are not " +
          "included in the total."
        raise SizeLimitError, message
      end

      # Raises timeout error.
      #
      # @raise [TimeLimitError] always
      def timeout_handler
        raise TimeLimitError, "Timed-out after #{@max_seconds} seconds"
      end

      # Handles exit status.
      #
      # @param [Status] status after execution
      #
      # @return [TrueClass] always true
      #
      # @raise [ShellError] on execution failure
      def exit_handler(status)
        @exit_code = status.exitstatus
        if @raise_on_failure && !status.success?
          @output.buffer << "Exit code = #{@exit_code}"
          raise ::RightGit::Shell::ShellError, "Execution failed: #{@output.display_text}"
        end
        true
      end

      private

      def inner_execute(cmd, output_handler, options)
        options = {
          :directory        => nil,
          :logger           => nil,
          :outstream        => nil,
          :raise_on_failure => true,
          :set_env_vars     => nil,
          :clear_env_vars   => nil,
        }.merge(options)
        if options[:outstream]
          raise ::ArgumentError, ':outstream is not currently supported'
        end
        @raise_on_failure = options[:raise_on_failure]

        # max seconds decreases over lifetime of shell until no more commands
        # can be executed due to initial time constraint.
        if @stop_timestamp
          remaining_seconds = @stop_timestamp - ::Time.now.to_i
          min_seconds = 5  # process start, a network gesture, etc.
          timeout_handler if remaining_seconds < min_seconds
        else
          remaining_seconds = nil
        end

        # set/clear env vars, if requested.
        environment = {}
        if cev = options[:clear_env_vars]
          cev.each { |k| environment[k] = nil }
        end
        if sev = options[:set_env_vars]
          environment.merge!(sev)
        end
        environment = nil if environment.empty?

        # use safe buffer (allows both safe and unsafe buffering) with limited
        # buffering for output that is only seen on error.
        @output = ::RightScale::RightPopen::SafeOutputBuffer.new(
          buffer          = [],
          max_line_count  = MAX_SAFE_BUFFER_LINE_COUNT,
          max_line_length = MAX_SAFE_BUFFER_LINE_LENGTH)

        # directory may be provided, else use initial directory.
        working_directory = options[:directory] || @initial_directory

        # synchronous popen with watchers, etc.
        if logger = options[:logger]
          logger.info("+ #{cmd}")
        end
        @exit_code = nil
        ::RightScale::RightPopen.popen3_sync(
          cmd,
          :target             => self,
          :directory          => working_directory,
          :environment        => environment,
          :timeout_handler    => :timeout_handler,
          :size_limit_handler => :size_limit_handler,
          :exit_handler       => :exit_handler,
          :stderr_handler     => output_handler,
          :stdout_handler     => output_handler,
          :inherit_io         => true,  # avoid killing any rails connection
          :watch_directory    => @watch_directory,
          :size_limit_bytes   => @max_bytes,
          :timeout_seconds    => remaining_seconds)
        @exit_code
      end

    end
  end
end
