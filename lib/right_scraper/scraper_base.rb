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

  # Base class for all scrapers.
  # Actual scraper implementation should override scrape_imp and optionally incremental_update?
  class ScraperBase

    # (String) Path to directory containing all scraped repositories
    attr_accessor :root_dir

    # (RightScale::Repository) Last scraped repository
    attr_reader :repo

    # (Array) Error messages if any
    attr_reader :errors

    # (String) Path to local directory where repository was downloaded
    attr_reader :current_repo_dir

    # Set path to directory containing all scraped repos
    #
    # === Parameters
    # root_dir(String):: Path to scraped repos parent directory
    def initialize(root_dir)
      @root_dir = root_dir
    end

    # Common implementation of scrape method for all repository types.
    # Each scraper implementation should override scrape_imp which is called
    # after this method initializes all the scraper attributes properly.
    # See RightScale::Scraper#scrape
    def scrape(repo, &callback)
      @repo             = repo
      @callback         = callback
      @current_repo_dir = ScraperBase.repo_dir(root_dir, repo)
      @scrape_dir_path  = File.expand_path(File.join(@current_repo_dir, '..'))
      @incremental      = incremental_update?
      @errors           = []
      FileUtils.rm_rf(@current_repo_dir) unless @incremental
      scrape_imp
      true
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
      dir_name  = Digest::MD5.hexdigest(repo.to_s)
      dir_path  = File.join(root_dir, dir_name)
      repo_dir = "#{dir_path}/repo"
    end

    # Was last call to scrapesuccessful?
    # Call errors to get error messages if false
    #
    # === Return
    # succeeded(TrueClass|FalseClass):: true if scrape finished with no error, false otherwise.
    def succeeded?
      succeeded = @errors.nil? || @errors.size == 0
    end
    
    protected

    # Check whether it is possible to perform an incremental update of the repo
    #
    # === Return
    # true:: Scrape directory contains files belonging to the scraped repo and protocol supports
    #        incremental updates
    # false:: Otherwise
    def incremental_update?
      false # Incremental updates not supported by default
    end
    
    # Override this method with scraper specific implementation in descendants
    #
    # === Return
    # true:: Always return true
    def scrape_imp
      raise "Method not implemented"
    end
    
  end
end
