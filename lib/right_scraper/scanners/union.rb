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
require 'right_scraper/scanners'

module RightScraper::Scanners

  # Union scanner, to permit running multiple scanners while only
  # walking the fs once.
  class Union

    # Create a new union scanner.  Recognizes no new options.
    #
    # === Parameters
    # classes(List):: List of Scanner classes to run
    # options(Hash):: scanner options
    def initialize(classes, options={})
      @subscanners = classes.map {|klass| klass.new(options)}
    end

    # Notify subscanners that all scans have completed.
    def finish
      @subscanners.each {|scanner| scanner.finish}
    end

    # Begin a scan for the given resource.
    #
    # === Parameters
    # resource(RightScraper::Resource::Base):: resource to scan
    def begin(resource)
      @subscanners.each {|scanner| scanner.begin(resource)}
    end

    # Finish a scan for the given resource.
    #
    # === Parameters
    # resource(RightScraper::Resource::Base):: resource that just finished scanning
    def end(resource)
      @subscanners.each {|scanner| scanner.end(resource)}
    end

    # Notice a file during scanning.
    #
    # === Block
    # Return the data for this file.  We use a block because it may
    # not always be necessary to read the data.
    #
    # === Parameters
    # relative_position(String):: relative pathname for the file from the root of resource
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
    # === Parameters
    # relative_position(String):: relative pathname for directory from root of resource
    #
    # === Returns
    # Boolean:: should the scanning recurse into the directory
    def notice_dir(relative_position)
      @subscanners.any? {|scanner| scanner.notice_dir(relative_position)}
    end
  end
end
