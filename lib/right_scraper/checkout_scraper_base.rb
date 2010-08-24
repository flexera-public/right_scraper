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
    # Create a new scraper.  This class does not recognize any new
    # options, so see FilesystemBasedScraper#initialize for option
    # handling.
    #
    # === Parameters ===
    # repository(RightScale::Repository):: repository to scrape
    # options(Hash):: scraper options
    def setup_dir
      if exists?
        begin
          @logger.operation(:updating) do
            do_update
          end
        rescue
          @logger.note_error($!, :updating, "switching to using checkout")
          FileUtils.remove_entry_secure basedir
          @logger.operation(:checkout) do
            do_checkout
          end
        end
      else
        @logger.operation(:checkout) do
          do_checkout
        end
      end
    end

    # Return true if a checkout exists.
    #
    # === Returns ===
    # Boolean:: true if the checkout already exists (and thus
    #           incremental updating can occur).
    def exists?
      false
    end

    # Perform an incremental update of the checkout.  Subclasses that
    # want to handle incremental updating need to override this.
    def do_update
      do_checkout
    end

    # Perform a de novo full checkout of the repository.  Subclasses
    # must override this to do anything useful.
    def do_checkout
      FileUtils.mkdir_p(basedir)
    end

    # Path to check repository to.  Currently @basedir/repository hash.
    def basedir
      File.join(@basedir, @repository.repository_hash)
    end
  end
end
