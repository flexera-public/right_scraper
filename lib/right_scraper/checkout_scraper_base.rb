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

require File.expand_path(File.join(File.dirname(__FILE__), 'fs_scraper_base'))
require 'tmpdir'
require 'libarchive_ruby'

module RightScale
  # Base class for FS based scrapers that want to do version control
  # operations (CVS, SVN, etc.).  Subclasses can get away with
  # implementing only #do_checkout but to support incremental
  # operation need to implement #exists? and #do_update, in addition
  # to FilesystemBasedScraper#ignorable_paths.
  class CheckoutBasedScraper < FilesystemBasedScraper
    def initialize(repository, options={})
      super
      if exists?
        begin
          do_update
        rescue
          puts "AARGH " + $!
          FileUtils.remove_entry_secure checkout_path
          do_checkout
        end
      else
        do_checkout
      end
    end

    def exists?
      false
    end

    def do_update
      do_checkout
    end

    def do_checkout
    end

    def checkout_path
      @basedir
    end
  end
end
