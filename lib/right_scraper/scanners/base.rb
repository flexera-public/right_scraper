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

require File.expand_path(File.join(File.dirname(__FILE__), '..', 'logger'))

module RightScale
  # Base class for scanning filesystems.  Subclasses should override
  # #notice and possibly #notice_dir.
  class Scanner
    # Create a new Scanner.  Recognizes options as given.  Some
    # options may be required, others optional.  This class recognizes
    # only _:logger_.
    #
    # === Options ===
    # _:logger_:: Optional.  Logger currently being used
    #
    # === Parameters ===
    # options(Hash):: scanner options
    def initialize(options={})
      @logger = options.fetch(:logger, Logger.new)
    end

    # Begin a scan for the given cookbook.
    #
    # === Parameters ===
    # cookbook(RightScale::Cookbook):: cookbook to scan
    def begin(cookbook)
    end

    # Finish a scan for the given cookbook.
    #
    # === Parameters ===
    # cookbook(RightScale::Cookbook):: cookbook that just finished scanningi
    def end(cookbook)
    end

    # Notice a file during scanning.
    #
    # === Block ===
    # Return the data for this file.  We use a block because it may
    # not always be necessary to read the data.
    #
    # === Parameters ===
    # relative_position(String):: relative pathname for _pathname_ from root of cookbook
    def notice(relative_position)
    end

    # Notice a directory during scanning.  Returns true if the scanner
    # should recurse into the directory (the default behavior)
    #
    # === Parameters ===
    # relative_position(String):: relative pathname for the directory from root of cookbook
    #
    # === Returns ===
    # Boolean:: should the scanning recurse into the directory
    def notice_dir(relative_position)
      true
    end
  end
end
