#--
# Copyright: Copyright (c) 2013 RightScale, Inc.
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
require 'right_scraper/loggers'

require 'logger'

module RightScraper
  module Loggers
    class Base < ::Logger

      attr_accessor :callback, :errors, :warnings

      def initialize(*args)
        super(*args)
        @abort_seen = false
        @callback = nil
        @errors = []
        @warnings = []
      end

      # Encapsulates an operation that merits logging.
      #
      # @param [Symbol] type of operation
      # @param [String] explanation of operation or empty
      #
      # @yield [] operational callback (required)
      #
      # @return [Object] result of callback
      def operation(type, explanation = '')
        begin
          note_phase(:begin, type, explanation)
          result = yield
          note_phase(:commit, type, explanation)
          result
        rescue Exception => e
          note_phase(:abort, type, explanation, e)
          raise
        end
      end

      # Note a phase change within an operation.
      #
      # @param [Symbol] phase of operation; one of :begin, :commit, :abort
      # @param [Symbol] type of operation
      # @param [String] explanation of operation or nil
      # @param [Exception] exception or nil
      #
      # @return [TrueClass] always true
      def note_phase(phase, type, explanation, exception = nil)
        @callback.call(phase, type, explanation, exception) if @callback
        case phase
        when :begin
          @abort_seen = false
        when :commit
          # do nothing
        when :abort
          unless @abort_seen
            note_error(exception, type, explanation)
            @abort_seen = true
          end
        else
          fail 'Unknown phase'
        end
      end

      # Note an error, with the given exception and explanation of what
      # was going on.
      #
      # @param [Exception] exception or nil
      # @param [Symbol] type of operation
      # @param [String] explanation of operation or nil
      #
      # @return [TrueClass] always true
      def note_error(exception, type, explanation = nil)
        raise NotImplementedError
      end

      # Note a warning for current operation.
      #
      # @param [Exception] exception or nil
      # @param [Symbol] type of operation
      # @param [String] explanation of operation or nil
      #
      # @return [TrueClass] always true
      def note_warning(message)
        raise NotImplementedError
      end

    end
  end
end
