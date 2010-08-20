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
  # override next, seek, position, rewind
  class ScraperBase
    # Integer:: optional maximum size permitted for repositories
    attr_accessor :max_bytes

    # Integer:: optional maximum number of seconds for any single
    # scrape operation.
    attr_accessor :max_seconds

    # RightScale::Repository:: repository currently being scraped
    attr_reader :repository

    def initialize(repository,options={})
      @repository = repository
      @max_bytes = options[:max_bytes] || nil
      @max_seconds = options[:max_seconds] || nil
      @logger = options[:logger] || Logger.new
      @logger.repository = repository
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

    # Set the scraper back to the beginning of scanning this repository.
    def rewind
      raise NotImplementedError
    end

    # Close the scraper, removing any temporary files.
    # Should be used as follows:
    #  scraper = ...
    #  begin
    #    # use the scraper
    #  ensure
    #    scraper.close
    #  end
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
