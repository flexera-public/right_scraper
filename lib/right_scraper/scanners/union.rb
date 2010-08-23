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
  # Union scanner, to permit running multiple scanners while only
  # walking the fs once.
  class UnionScanner
    # Create a new UnionScanner.  Recognizes no new options.
    #
    # === Parameters ===
    # classes(List):: List of Scanner classes to run
    # options(Hash):: scanner options
    def initialize(classes, options={})
      @subscanners = classes.map {|klass| klass.new(options)}
    end

    # Begin a scan for the given cookbook.
    #
    # === Parameters ===
    # cookbook(RightScale::Cookbook):: cookbook to scan
    def begin(cookbook)
      @subscanners.each {|scanner| scanner.begin(cookbook)}
    end

    # Finish a scan for the given cookbook.
    #
    # === Parameters ===
    # cookbook(RightScale::Cookbook):: cookbook that just finished scanningi
    def end(cookbook)
      @subscanners.each {|scanner| scanner.end(cookbook)}
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
      data = nil
      @subscanners.each {|scanner| scanner.notice(relative_position) {
          data = yield if data.nil?
          data
        }
      }
    end

    # Notice a directory during scanning.  Returns true if any of the
    # subscanners report that they should recurse into the directory.
    #
    # === Parameters ===
    # relative_position(String):: relative pathname for directory from root of cookbook
    #
    # === Returns ===
    # Boolean:: should the scanning recurse into the directory
    def notice_dir(relative_position)
      @subscanners.any? {|scanner| scanner.notice_dir(relative_position)}
    end
  end
end
