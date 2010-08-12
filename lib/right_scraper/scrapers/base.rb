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

require 'digest/md5'

module RightScale

  # Base class for all scrapers.  Actual scraper implementation should
  # override next, seek, position
  class NewScraperBase
    # Integer:: optional maximum size permitted for repositories
    attr_accessor :max_bytes

    # Integer:: optional maximum number of seconds for any single
    # scrape operation.
    attr_accessor :max_seconds

    # RightScale::Repository:: repository currently being scraped
    attr_reader :repository

    def initialize(repository,max_bytes=nil,max_seconds=nil)
      @repository = repository
      @max_bytes = max_bytes
      @max_seconds = max_seconds
    end

    # Return next Cookbook object from the stream.
    def next
      raise NotImplementedError
    end

    # Move the scraper into the given position.
    def seek(position)
      raise NotImplementedError
    end

    # Retrieve the current position of the scraper.
    def position
      raise NotImplementedError
    end
  end
end
