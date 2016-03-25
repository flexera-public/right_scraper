#--
# Copyright: Copyright (c) 2010-2016 RightScale, Inc.
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

require 'right_support'
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

    attr_reader :logger, :resources

    # Initialize scrape destination directory
    #
    # === Options
    # <tt>:kind</tt>:: Type of scraper that will traverse directory for resources, one of :cookbook or :workflow
    # <tt>:basedir</tt>:: Local directory where files are retrieved and scraped, use temporary directory if nil
    # <tt>:max_bytes</tt>:: Maximum number of bytes to read from remote repo, unlimited if nil
    # <tt>:max_seconds</tt>:: Maximum number of seconds to spend reading from remote repo, unlimited if nil
    def initialize(options={})
      options = ::RightSupport::Data::Mash.new(
        :kind        => nil,
        :basedir     => nil,
        :max_bytes   => nil,
        :max_seconds => nil,
        :logger      => nil,
        :s3_key      => nil,
        :s3_secret   => nil,
        :s3_bucket   => nil,
        :scanners    => nil,
        :builders    => nil,
      ).merge(options)
      @temporary = !options.has_key?(:basedir)
      options[:basedir] ||= Dir.mktmpdir
      options[:logger] ||= ::RightScraper::Loggers::Default.new
      @logger = options[:logger]
      @resources = []
      options[:errors] = @logger.errors
      options[:warnings] = @logger.warnings

      # load classes from scanners and builders options, if necessary.
      [:scanners, :builders].each do |k|
        list = options[k] || []
        list.each_with_index do |clazz, index|
          unless clazz.kind_of?(::Class)
            list[index] = ::Object.const_get(clazz)
          end
        end
      end
      @options = options
    end

    # Scrapes and scans a given repository.
    #
    # @deprecated the newer methodology will perform these operations in stages
    # controlled externally instead of calling this all-in-one method.
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
      old_logger_callback = @logger.callback
      @logger.callback = callback
      errorlen = errors.size
      begin
        if retrieved = retrieve(repo)
          scan(retrieved)
        end
      rescue Exception
        # legacy logger handles communication with the end user and appending
        # to our error list; we just need to keep going. the new methodology
        # has no such guaranteed communication so the caller will decide how to
        # handle errors, etc.
      ensure
        @logger.callback = old_logger_callback
        cleanup
      end
      errors.size == errorlen
    end

    # Retrieves the given repository. See #scrape for details.
    def retrieve(repo)
      errorlen = errors.size
      unless repo.kind_of?(::RightScraper::Repositories::Base)
        repo = ::RightSupport::Data::Mash.new(repo)
        repository_hash = repo.delete(:repository_hash)  # optional
        repo = RightScraper::Repositories::Base.from_hash(repo)
        if repository_hash && repository_hash != repo.repository_hash
          raise RightScraper::Error, "Repository hash mismatch: #{repository_hash} != #{repo.repository_hash}"
        end
      end

      retriever = nil

      # 1. Retrieve the files
      @logger.operation(:retrieving, "from #{repo}") do
        # note that the retriever type may be unavailable but allow the
        # retrieve method to raise any such error.
        retriever = repo.retriever(@options)
        retriever.retrieve
      end

      if errors.size == errorlen
        # create the freed directory with world-writable permission for
        # subsequent scan output for less-privileged child processes.
        freed_base_path = freed_dir(repo)
        ::FileUtils.rm_rf(freed_base_path) if ::File.exist?(freed_base_path)
        ::FileUtils.mkdir_p(freed_base_path)
        ::File.chmod(0777, freed_base_path)

        # the following hash is needed for running any subsequent scanners.
        {
          ignorable_paths: retriever.ignorable_paths,
          repo_dir: retriever.repo_dir,
          freed_dir: freed_base_path,
          repository: retriever.repository
        }
      else
        nil
      end
    end

    # Scans a local directory. See #scrape for details.
    def scan(retrieved)
      errorlen = errors.size
      old_callback = @logger.callback
      options = ::RightSupport::Data::Mash.new(@options).merge(retrieved)
      repo = options[:repository]
      unless repo.kind_of?(::RightScraper::Repositories::Base)
        repo = ::RightSupport::Data::Mash.new(repo)
        repository_hash = repo.delete(:repository_hash)  # optional
        repo = RightScraper::Repositories::Base.from_hash(repo)
        if repository_hash && repository_hash != repo.repository_hash
          raise RightScraper::Error, "Repository hash mismatch: #{repository_hash} != #{repo.repository_hash}"
        end
        options[:repository] = repo
      end
      @logger.operation(:scraping, options[:repo_dir]) do
        scraper = ::RightScraper::Scrapers::Base.scraper(options)
        @resources += scraper.scrape
      end
      errors.size == errorlen
    end

    # base directory for any file operations.
    def base_dir
      @options[:basedir]
    end

    # cleans up temporary files, etc.
    def cleanup
      ::FileUtils.remove_entry_secure(base_dir) rescue nil if @temporary
    end

    # Path to directory where given repo should be or was downloaded
    #
    # === Parameters
    # repo(Hash|RightScraper::Repositories::Base):: Remote repository corresponding to local directory
    #
    # === Return
    # String:: Path to local directory that corresponds to given repository
    def repo_dir(repo)
      RightScraper::Retrievers::Base.repo_dir(base_dir, repo)
    end

    # Path to directory where scanned artifacts can by copied out of containment
    # due to lack of permissions to write to other directories. the freed files
    # can then be reused by subsequent scanners, etc.
    def freed_dir(repo)
      ::File.expand_path('../freed', repo_dir(repo))
    end

    # (Array):: Error messages in case of failure
    def errors
      @logger.errors
    end

    # (Array):: Warnings or empty
    def warnings
      @logger.warnings
    end

    # (Array):: scanners or empty
    def builders
      return @options[:builders]
    end

    # (Array):: scanners or empty
    def scanners
      return @options[:scanners]
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
