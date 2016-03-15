#--
# Copyright: Copyright (c) 2016 RightScale, Inc.
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

require 'right_scraper'

module RightScraper
  module Scanners
    # Build manifests from a filesystem.
    class CookbookFilenameScanner < ::RightScraper::Scanners::Base

      # Initializer
      #
      # === Parameters
      # @param [Hash] options
      # @option options [Array] :warnings bucket
      def initialize(options)
        super
        raise ArgumentError.new("options[:warnings] is required") unless @warnings = options[:warnings]
      end

      # Checks file names for any problematic characters.
      #
      # === Block ===
      # @yield [] returns file data, not checked here
      #
      # === Parameters ===
      # @param [String] relative_position for file from root of resource
      def notice(relative_position)
        if detect_non_printing_non_ascii(relative_position)
          @warnings << "A file name contained non-printing or non-ASCII characters: #{relative_position.inspect}"
        end
      end

      # Checks directory names for any problematic characters.
      #
      # === Parameters ===
      # @param [String] relative_position for directory from root of resource
      #
      # === Returns ===
      # @return [TrueClass|FalseClass] true if scanning should recurse directory
      def notice_dir(relative_position)
        if relative_position && detect_non_printing_non_ascii(relative_position)
          @warnings << "A directory name contained non-printing or non-ASCII characters: #{relative_position.inspect}"
          # ignore directory contents since directory itself is problematic.
          false
        else
          true
        end
      end

      private

      # Determines if the given string contains non-printing or non-ASCII
      # characters.
      #
      # === Returns ===
      # @return [TrueClass|FalseClass] true if any character is non-printing or non-ASCII
      def detect_non_printing_non_ascii(relative_position)
        !!relative_position.bytes.find { |byte| byte < 0x20 || byte > 0x7E }
      end
    end
  end
end
