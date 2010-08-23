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

require File.expand_path(File.join(File.dirname(__FILE__), 'watcher'))
require File.expand_path(File.join(File.dirname(__FILE__), 'logger'))
require 'tmpdir'
require 'libarchive_ruby'

module RightScale
  # Base class for all scrapers.  Actual scraper implementation should
  # override #next, #seek, #pos, and #rewind.
  #
  # It is important to call #close when you are done with the scraper
  # so that various open file descriptors and temporary files and the
  # like can be cleaned up.  Ideally, use begin/ensure for this, like
  # follows:
  #   begin
  #     scraper = ScraperBase.new(...)
  #     ...
  #   ensure
  #     scraper.close
  #   end
  class ScraperBase
    # Integer:: optional maximum size permitted for repositories
    attr_accessor :max_bytes

    # Integer:: optional maximum number of seconds for any single
    # scrape operation.
    attr_accessor :max_seconds

    # RightScale::Repository:: repository currently being scraped
    attr_reader :repository

    # Create a new scraper for the given repository.  This class
    # recognizes several options, and subclasses may recognize
    # additional options.  Options may never be required.
    #
    # === Options ===
    # _:max_bytes_:: Maximum number of bytes to read
    # _:max_seconds_:: Maximum number of seconds to spend reading
    # _:logger_:: Logger to use
    #
    # === Parameters ===
    # repository(RightScale::Repository):: repository to scrape
    # options(Hash):: scraper options
    def initialize(repository,options={})
      @repository = repository
      @max_bytes = options[:max_bytes] || nil
      @max_seconds = options[:max_seconds] || nil
      @logger = options[:logger] || Logger.new
      @logger.repository = repository
    end

    # Return next cookbook from the stream, or nil if none.
    def next
      raise NotImplementedError
    end

    # Seek to the given position.  Akin to IO#seek.  Position is an
    # opaque datum returned by #pos.
    #
    # === Parameters
    # position:: opaque datum listing where to seek.
    def seek(position)
      raise NotImplementedError
    end
    alias_method :pos=, :seek

    # Return the position of the scraper.  Here, the position is the
    # path relative from the top of the temporary directory.  Akin to
    # IO#pos or IO#tell.
    def pos
      raise NotImplementedError
    end
    alias_method :tell, :pos

    # Reset the scraper to start scraping the filesystem from the
    # beginning.  Akin to IO#rewind or Dir#rewind and used for the
    # same sort of operation.
    def rewind
      raise NotImplementedError
    end

    # Close the scraper, removing any temporary files.
    def close
    end

    # Path to directory where given repo should be or was downloaded
    #
    # === Parameters
    # root_dir(String):: Path to directory containing all scraped repositories
    # repo(Hash|RightScale::Repository):: Remote repository corresponding to local directory
    #
    # === Return
    # repo_dir(String):: Path to local directory that corresponds to given repository
    def self.repo_dir(root_dir, repo)
      repo = Repository.from_hash(repo) if repo.is_a?(Hash)
      dir_name  = repo.repository_hash
      dir_path  = File.join(root_dir, dir_name)
      repo_dir = "#{dir_path}/repo"
    end
  end
end
