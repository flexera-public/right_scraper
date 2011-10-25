#--
# Copyright: Copyright (c) 2010-2011 RightScale, Inc.
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

module RightScraper
  module Retrievers
    # Base class for all retrievers.
    #
    # Retrievers fetch remote repositories into a given path
    # They will attempt to fetch incrementally when possible (e.g. leveraging
    # the underlying source control management system incremental capabilities) 
    class Base

      # Integer:: optional maximum size permitted for repositories
      attr_accessor :max_bytes

      # Integer:: optional maximum number of seconds for any single
      # retrieve operation.
      attr_accessor :max_seconds

      # RightScraper::Repositories::Base:: repository currently being retrieved
      attr_reader :repository

      # String:: Path to directory where files are retrieved
      attr_reader :repo_dir

      # exceptions
      class RetrieverError < Exception; end

      # Create a new retriever for the given repository.  This class
      # recognizes several options, and subclasses may recognize
      # additional options.  Options may never be required.
      #
      # === Options
      # <tt>:basedir</tt>:: Required, base directory where all files should be retrieved
      # <tt>:max_bytes</tt>:: Maximum number of bytes to read
      # <tt>:max_seconds</tt>:: Maximum number of seconds to spend reading
      # <tt>:logger</tt>:: Logger to use
      #
      # === Parameters
      # repository(RightScraper::Repositories::Base):: repository to scrape
      # options(Hash):: retriever options
      #
      # === Raise
      # 'Missing base directory':: if :basedir option is missing
      def initialize(repository, options={})
        raise 'Missing base directory' unless options[:basedir]
        @repository = repository
        @max_bytes = options[:max_bytes] || nil
        @max_seconds = options[:max_seconds] || nil
        @basedir = options[:basedir]
        @repo_dir = RightScraper::Retrievers::Base.repo_dir(@basedir, repository)
        @logger = options[:logger] || RightScraper::Logger.new
        @logger.repository = repository
        @logger.operation(:initialize, "setting up in #{@repo_dir}") do
          FileUtils.mkdir_p(@repo_dir)
        end
      end

      # Determines if retriever is available (has required CLI tools, etc.)
      def available?
        raise NotImplementedError
      end

      # Paths to ignore when traversing the filesystem.  Mostly used for
      # things like Git and Subversion version control directories.
      #
      # === Return
      # list(Array):: list of filenames to ignore.
      def ignorable_paths
        []
      end

      # Retrieve repository, overridden in heirs
      def retrieve
        raise NotImplementedError
      end

      # Path to directory where given repo should be or was downloaded
      #
      # === Parameters
      # root_dir(String):: Path to directory containing all scraped repositories
      # repo(Hash|RightScraper::Repositories::Base):: Remote repository corresponding to local directory
      #
      # === Return
      # String:: Path to local directory that corresponds to given repository
      def self.repo_dir(root_dir, repo)
        repo = RightScraper::Repositories::Base.from_hash(repo) if repo.is_a?(Hash)
        dir_name  = repo.repository_hash
        dir_path  = File.join(root_dir, dir_name)
        "#{dir_path}/repo"
      end

      protected

      # (Hash) Lookup table from textual description of scraper type
      # ('cookbook' or 'workflow' currently) to the class that
      # represents that scraper.
      @@types = {} unless class_variable_defined?(:@@types)

    end
  end
end
