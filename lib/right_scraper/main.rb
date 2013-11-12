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
require 'right_scraper'

require 'fileutils'

module RightScraper

  # Library main entry point. Instantiate this class and call the scrape
  # method to download or update a remote repository to the local disk and
  # run a scraper on the resulting files.
  #
  # Note that this class was known as Scraper in v1-3 but the name was confusing
  # due to the Scrapers module performing only a subset of the main Scraper
  # class functionality.
  class Main

    # (Array):: Scraped resources
    attr_reader :resources

    # Initialize scrape destination directory
    #
    # === Options
    # <tt>:kind</tt>:: Type of scraper that will traverse directory for resources, one of :cookbook or :workflow
    # <tt>:basedir</tt>:: Local directory where files are retrieved and scraped, use temporary directory if nil
    # <tt>:max_bytes</tt>:: Maximum number of bytes to read from remote repo, unlimited if nil
    # <tt>:max_seconds</tt>:: Maximum number of seconds to spend reading from remote repo, unlimited if nil
    def initialize(options={})
      options = {
        :kind        => nil,
        :basedir     => nil,
        :max_bytes   => nil,
        :max_seconds => nil,
        :callback    => nil,
        :logger      => nil,
        :s3_key      => nil,
        :s3_secret   => nil,
        :s3_bucket   => nil,
        :errors      => nil,
        :warnings    => nil,
        :scanners    => nil,
        :builders    => nil,
      }.merge(options)
      @temporary = !options.has_key?(:basedir)
      options[:basedir] ||= Dir.mktmpdir
      options[:logger] ||= ::RightScraper::Loggers::Default.new
      @logger = options[:logger]
      @resources = []
      @options = options
    end

    # Scrape given repository, depositing files into the scrape
    # directory.  Update content of unique directory incrementally
    # when possible with further calls.
    #
    # === Parameters
    # repo(Hash|RightScraper::Repositories::Base):: Repository to be scraped
    #   Note: repo can either be a Hash or a RightScraper::Repositories::Base instance.
    #         See the RightScraper::Repositories::Base class for valid Hash keys.
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
    # === Return
    # true:: If scrape was successful
    # false:: If scrape failed, call errors for information on failure
    #
    # === Raise
    # 'Invalid repository type':: If repository type is not known
    def scrape(repo, incremental=true, &callback)
      errorlen = errors.size
      repo = RightScraper::Repositories::Base.from_hash(repo) if repo.is_a?(Hash)
      @logger.callback = callback
      begin
        # 1. Retrieve the files
        retriever = nil
        repo_dir_changed = false
        @logger.operation(:retrieving, "from #{repo}") do
          # note that the retriever type may be unavailable but allow the
          # retrieve method to raise any such error.
          retriever = repo.retriever(@options)
          repo_dir_changed = retriever.retrieve
        end

        # TEAL FIX: Note that retrieve will now return true iff there has been
        # a change to the last scraped repository directory for efficiency
        # reasons and only for retreiver types that support this behavior.
        #
        # Even if the retrieval is skipped due to already having the data on
        # disk we still need to scrape its resources only because of the case
        # of the metadata scraper daemon, which updates multiple repositories
        # of similar criteria.
        #
        # The issue is that a new repo can appear later with the same criteria
        # as an already-scraped repo and will need it's own copy of the
        # scraped resources. The easiest (but not most efficient) way to
        # deliver these is to rescrape the already-seen resources. This
        # becomes more expensive as we rely on generating "metadata.json" from
        # "metadata.rb" for cookbooks but is likely not expensive enough to
        # need to improve this logic.


        # 2. Now scrape if there is a scraper in the options
        @logger.operation(:scraping, retriever.repo_dir) do
          if @options[:kind]
            options = @options.merge({:ignorable_paths => retriever.ignorable_paths,
                                      :repo_dir        => retriever.repo_dir,
                                      :repository      => retriever.repository})
            scraper = RightScraper::Scrapers::Base.scraper(options)
            @resources += scraper.scrape
          end
        end
      rescue Exception
        # logger handles communication with the end user and appending
        # to our error list, we just need to keep going.
      ensure
        # ensure basedir is always removed if temporary (even with errors).
        ::FileUtils.remove_entry_secure(@options[:basedir]) rescue nil if @temporary
      end
      @logger.callback = nil
      errors.size == errorlen
    end

    # Path to directory where given repo should be or was downloaded
    #
    # === Parameters
    # repo(Hash|RightScraper::Repositories::Base):: Remote repository corresponding to local directory
    #
    # === Return
    # String:: Path to local directory that corresponds to given repository
    def repo_dir(repo)
      RightScraper::Retrievers::Base.repo_dir(@options[:basedir], repo)
    end

    # (Array):: Error messages in case of failure
    def errors
      @logger.errors
    end

    # (Array):: Warnings or empty
    def warnings
      @logger.warnings
    end

   # Was scraping successful?
    # Call errors to get error messages if false
    #
    # === Return
    # Boolean:: true if scrape finished with no error, false otherwise.
    def succeeded?
      errors.empty?
    end
    alias_method :successful?, :succeeded?

  end
end