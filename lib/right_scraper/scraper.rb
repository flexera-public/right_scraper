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
  # Library main entry point. Instantiate this class and call the scrape
  # method to download or update a remote repository to the local disk.
  class Scraper

    # (String) Path to directory where remote repository was downloaded
    # Note: This will be a subfolder of the scrape directory (directory given to initializer)
    attr_reader :last_repo_dir
    
    # Initialize scrape destination directory
    #
    # === Parameters
    # scrape_dir(String):: Scrape destination directory
    # max_bytes(Integer):: Maximum size allowed for repos, -1 for no limit (default)
    # max_seconds(Integer):: Maximum number of seconds a single scrape operation should take, -1 for no limit (default)
    def initialize(scrape_dir, max_bytes = -1, max_seconds = -1)
      @scrape_dir = scrape_dir
      @max_bytes = max_bytes
      @max_seconds = max_seconds
      @scrapers = {}
    end

    # Scrape given repository.
    # Create unique directory inside scrape directory when called for the first time.
    # Update content of unique directory incrementally when possible with further calls.
    #
    # === Parameters
    # repo(Hash|RightScale::Repository):: Repository to be scraped
    # Note: repo can either be a Hash or a RightScale::Repo instance.
    # See the RightScale::Repo class for valid Hash keys.
    # incremental(FalseClass|TrueClass):: Whether scrape should be incremental if possible (true by default)
    #
    # === Block
    # If a block is given, it will be called back with progress information
    # the block should take two arguments:
    # - first argument is the string containing the info
    # - second argument is a boolean indicating whether to increment progress
    # The block is called exactly once with the increment flag set to true
    #
    # === Return
    # true:: If scrape was successful
    # false:: If scrape failed, call error_message for information on failure
    #
    # === Raise
    # 'Invalid repository type':: If repository type is not known
    def scrape(repo, incremental=true, &callback)
      repo = RightScale::Repository.from_hash(repo) if repo.is_a?(Hash)
      scraper_class = repo.scraper
      @scraper = @scrapers[scraper_class] ||=
        scraper_class.new(@scrape_dir, @max_bytes, @max_seconds)
      @scraper.scrape(repo, incremental, &callback)
      @last_repo_dir = @scraper.current_repo_dir
      @scraper.succeeded?
    end
    
    # Retrieve directory path where repo was or would be downloaded
    #
    # === Parameters
    # repo(Hash|RightScale::Repository):: Remote repository corresponding to local directory
    #
    # === Return 
    # repo_dir(String):: Path to local directory that corresponds to given repository
    def repo_dir(repo)
      repo_dir = RightScale::ScraperBase.repo_dir(scrape_dir, repo)
    end

    # Error messages in case of failure
    #
    # === Return
    # errors(Array):: Error messages or empty array if no error
    def errors
      errors = @scraper && @scraper.errors || []
    end

    # Was scraping successful?
    # Call error_message to get error messages if false
    #
    # === Return
    # succeeded(Boolean):: true if scrape finished with no error, false otherwise.
    def succeeded?
      succeeded = errors.size == 0
    end
  end
end
