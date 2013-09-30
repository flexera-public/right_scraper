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
require 'right_scraper/scrapers'

module RightScraper::Scrapers

  # Base class for all scrapers. Subclasses should override
  # #find_next which instantiates the resource from the file system.
  class Base < ::RightScraper::RegisteredBase

    # Scraped resources
    attr_reader :resources

    # @return [Module] module for registered repository types
    def self.registration_module
      ::RightScraper::Scrapers
    end

    # Initialize scraper
    #
    # === Options
    # <tt>:kind</tt>:: Scraper type, one of :cookbook or :workflow
    # <tt>:repo_dir</tt>:: Required, path to directory containing files
    #   to be scraped
    # <tt>:ignorable_paths</tt>:: List of directory names that should
    #   be ignored by scraper
    # <tt>:scanners</tt>:: List of Scanner classes to use, optional
    # <tt>:builders</tt>:: List of Builder classes to use, optional
    #
    # === Return
    # scraper(Scrapers::Base):: Corresponding scraper instance
    def self.scraper(options)
      scraper_kind = options.delete(:kind)
      scraper_class = query_registered_type(scraper_kind)
      scraper_class.new(options)
    end

    # Do the scrape!
    # Extract all resources from directory
    # Call this method or call 'next_resource' to retrieve
    # resources one by one (you must then call 'close' yourself)
    # Fill @resources
    #
    # === Return
    # resources<Array>:: List of all scraped resources
    def scrape
      @resources = []
      begin
        resource = next_resource
        until resource.nil?
          @resources << resource
          resource = next_resource
        end
      ensure
        close
      end
      @resources
    end

    # Return the next resource in the filesystem, or nil if none.  As
    # a part of building the resources, invokes the builders.
    # A resource can be a cookbook, a workflow, a RightScript etc.
    #
    # === Returns
    # Object:: next resource in filesystem, or nil if none.
    def next_resource
      @logger.operation(:next) do
        next nil if @next.nil?

        value = @next
        @next = search_dirs
        while @next.nil? && !@queue.empty?
          pop_queue
        end
        value
      end
    end

    # Close any opened file descriptor
    #
    # === Return
    # true:: Always return true
    def close
      @builder.finish
      if @stack && !@stack.empty?
        @stack.each {|s| s.close}
        @stack = []
      end
      true
    end

    protected

    # Directory containing files to be scraped
    attr_reader :repo_dir

    # Initialize scraper
    #
    # === Options
    # <tt>:repository</tt>:: Required, original repository containing scraped
    #   files
     # <tt>:repo_dir</tt>:: Required, path to directory containing files
    #   to be scraped
    # <tt>:ignorable_paths</tt>:: List of directory names that should
    #   be ignored by scraper
    # <tt>:scanners</tt>:: List of Scanner classes to use, defaulting
    #   to RightScraper::Scanners::ResourceManifest and
    #   RightScraper::Scanners::CookbookMetadata
    # <tt>:builders</tt>:: List of Builder classes to use, defaulting to
    #   RightScaper::Builders::Filesystem
    #
    def initialize(options)
      raise "Repository required when initializing a scraper" unless options[:repository]
      raise "Repository directory required when initializing a scraper" unless options[:repo_dir]
      @repository = options[:repository]
      unless @logger = options[:logger]
        raise ::ArgumentError, ':logger is required'
      end
      @repo_dir = options[:repo_dir]
      @ignorable_paths = options[:ignorable_paths]
      @stack = []
      @queue = (@repository.resources_path || [""]).reverse
      @resources = []
      scanners = options[:scanners] || default_scanners
      @scanner = RightScraper::Scanners::Union.new(scanners, options)
      builders = options[:builders] || default_builders
      @builder = RightScraper::Builders::Union.new(builders, :ignorable_paths => @ignorable_paths,
                                                             :scanner         => @scanner,
                                                             :logger          => @logger,
                                                             :max_bytes       => @max_bytes,
                                                             :max_seconds     => @max_seconds)
      pop_queue # Initialize @next
    end

    # List of default scanners for this scaper
    #
    # === Return
    # Array<Scanner>:: Default scanners
    def default_scanners
    end

    # List of default builders for this scaper
    #
    # === Return
    # Array<Builder>:: Default builders
    def default_brokers
    end

    # Find the interesting item in given directory
    # Override in actual scraper implementation
    #
    # === Parameters
    # dir(Dir):: directory to begin search in
    def find_next(dir)
      raise NotImplementedError
    end

    # Return the position of the scraper.  Here, the position is the
    # path relative from the top of the temporary directory.  Akin to
    # IO#pos or IO#tell.
    def pos
      strip_repo_dir(@stack.last.path)
    end
    alias_method :tell, :pos

    # Turn path from an absolute filesystem location to a relative
    # file location from #repo_dir.
    #
    # === Parameters
    # path(String):: absolute path to relativize
    #
    # === Returns
    # res(String):: relative pathname for path
    def strip_repo_dir(path)
      res = path[repo_dir.length+1..-1]
      if res == nil || res == ""
        "."
      else
        res
      end
    end
    private :strip_repo_dir

    # Test if the entry given is ignorable.  By default just uses
    # #ignorable_paths
    #
    # === Parameters
    # entry(String):: file name to check
    #
    # === Returns
    # Boolean:: true if the entry should be ignored
    def ignorable?(entry)
      @ignorable_paths.include?(entry)
    end

    # Initialize @next with the next resource
    #
    # === Returns
    # @next(Resources::Base):: Next resource
    def pop_queue
      until @queue.empty?
        nextdir = @queue.pop
        if File.directory?(File.join(repo_dir, nextdir))
          @next = find_next(Dir.new(File.join(repo_dir, nextdir)))
          return @next
        else
          @logger.warn("When processing in #{@repository}, no such path #{nextdir}")
        end
      end
      @next = nil
    end

    # Search the directory stack looking for the next resource.
    def search_dirs
      @logger.operation(:searching) do
        until @stack.empty?
          dir = @stack.last
          entry = dir.read
          if entry == nil
            dir.close
            @stack.pop
            next
          end

          next if entry == '.' || entry == '..'
          next if ignorable?(entry)

          fullpath = File.join(dir.path, entry)

          if File.directory?(fullpath)
            result = find_next(Dir.new(fullpath))
            break
          end
        end
        result
      end
    end
    private :search_dirs

  end
end
