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

require File.expand_path(File.join(File.dirname(__FILE__), 'base'))
require 'json'

module RightScale
  module Scanners
    # Load cookbook metadata from a filesystem.
    class Metadata < Scanner
      # Begin a scan for the given cookbook.
      #
      # === Parameters
      # cookbook(RightScale::Cookbook):: cookbook to scan
      def begin(cookbook)
        @cookbook = cookbook
      end

      # Notice a file during scanning.
      #
      # === Block
      # Return the data for this file.  We use a block because it may
      # not always be necessary to read the data.
      #
      # === Parameters
      # relative_position(String):: relative pathname for the file from root of cookbook
      def notice(relative_position)
        if relative_position == "metadata.json"
          @logger.operation(:metadata_parsing) do
            @cookbook.metadata = JSON.parse(yield)
          end
        end
      end

      # Notice a directory during scanning.  Since metadata.json is by
      # definition only in the root directory we don't need to recurse,
      # but we do need to go into the first directory (identified by
      # +relative_position+ being +nil+).
      #
      # === Parameters
      # relative_position(String):: relative pathname for the directory from root of cookbook
      #
      # === Returns
      # Boolean:: should the scanning recurse into the directory
      def notice_dir(relative_position)
        relative_position == nil
      end
    end
  end
end
