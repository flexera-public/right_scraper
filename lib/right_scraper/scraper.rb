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
require File.expand_path(File.join(File.dirname(__FILE__), 'logger'))

module RightScale
  # Library main entry point. Instantiate this class and call the scrape
  # method to download or update a remote repository to the local disk.
  class Scraper
    # Initialize scrape destination directory
    #
    # === Parameters
    # scrape_dir(String):: Scrape destination directory
    # options(Hash):: Options for the scraper
    def initialize(scrape_dir, options={})
      @options = options.merge({:directory => scrape_dir})
      @logger = ScraperLogger.new
      @cookbooks = []
    end

    class ScraperLogger < Logger
      attr_accessor :errors
      attr_accessor :callback

      def initialize
        @errors = []
      end

      def operation(type, explanation="")
        begin
          @callback.call(:begin, type, explanation, nil) unless @callback.nil?
          result = super
          @callback.call(:commit, type, explanation, nil) unless @callback.nil?
          result
        rescue
          @callback.call(:abort, type, explanation, nil) unless @callback.nil?
          raise
        end
      end

      def note_error(exception, type, explanation="")
        @errors << [exception, type, explanation]
      end
    end

    # Scrape given repository, depositing files into the scrape
    # directory.  Update content of unique directory incrementally
    # when possible with further calls.
    #
    # === Parameters
    # repo(Hash|RightScale::Repository):: Repository to be scraped
    #                                     Note: repo can either be a Hash or a RightScale::Repository instance.
    #                                     See the RightScale::Repository class for valid Hash keys.
    #
    # === Block
    # If a block is given, it will be called back with progress information
    # the block should take four arguments:
    # - first argument is one of <tt>:begin</tt>, <tt>:commit</tt>,
    #   <tt>:abort</tt> which signifies what
    #   the scraper is trying to do and where it is when it does it
    # - second argument is a symbol describing the operation being performed
    #   in an easy-to-match way
    # - third argument is optional further explanation
    # - fourth argument is the exception pending (only relevant for <tt>:abort</tt>)
    #
    # The old increment functionality can be gotten by listening for
    # <tt>:commit</tt> or <tt>:abort</tt> and <tt>:scraping</tt>,
    # which will only be called once per scraper and at the end of its
    # run.
    #
    # === Return
    # true:: If scrape was successful
    # false:: If scrape failed, call errors for information on failure
    #
    # === Raise
    # 'Invalid repository type':: If repository type is not known
    def scrape(repo, incremental=true, &callback)
      errorlen = errors.size
      repo = RightScale::Repository.from_hash(repo) if repo.is_a?(Hash)
      @logger.callback = callback
      begin
        @logger.operation(:scraping, "from #{repo}") do
          scraper = repo.scraper.new(repo, @options.merge({:logger => @logger}))
          cookbook = scraper.next
          until cookbook.nil?
            @cookbooks << cookbook
            cookbook = scraper.next
          end
        end
      rescue
        # logger handles communication with the end user and appending
        # to our error list, we just need to keep going.
      end
      @logger.callback = nil
      errors.size == errorlen
    end

    # Path to directory where given repo should be or was downloaded
    #
    # === Parameters
    # repo(Hash|RightScale::Repository):: Remote repository corresponding to local directory
    #
    # === Return
    # String:: Path to local directory that corresponds to given repository
    def repo_dir(repo)
      RightScale::Scrapers::ScraperBase.repo_dir(scrape_dir, repo)
    end

    # (Array):: Error messages in case of failure
    def errors
      @logger.errors
    end

    # (Array):: Cookbooks scraped
    attr_reader :cookbooks

    # Was scraping successful?
    # Call errors to get error messages if false
    #
    # === Return
    # Boolean:: true if scrape finished with no error, false otherwise.
    def succeeded?
      errors.empty?
    end
  end
end
