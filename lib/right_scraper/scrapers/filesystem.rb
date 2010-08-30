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

require File.expand_path(File.join(File.dirname(__FILE__), 'base'))
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'builders', 'filesystem'))
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'builders', 'union'))
require 'tmpdir'

module RightScale
  module Scrapers
    # Base class for generic filesystem based scrapers.  Subclasses
    # should override #ignorable_paths, and add some setup code to
    # #new so that the scraper has something to scrape.
    #
    # It is important to call #close when you are done with the scraper
    # so that various open file descriptors and temporary files and the
    # like can be cleaned up.  Ideally, use begin/ensure for this, like
    # follows:
    #   begin
    #     fs = FilesystemBasedScraper.new(...)
    #     ...
    #   ensure
    #     fs.close
    #   end
    class FilesystemBasedScraper < ScraperBase
      # Create a new scraper.  In addition to the options recognized by
      # ScraperBase#new, this class recognizes <tt>:directory</tt> and
      # <tt>:builders</tt>.
      #
      # === Options ===
      # <tt>:directory</tt>:: Directory to perform scraper work in
      # <tt>:builders</tt>:: List of Builder classes to use, defaulting to
      #                      FilesystemBuilder
      #
      # === Parameters ===
      # repository(RightScale::Repository):: repository to scrape
      # options(Hash):: scraper options
      def initialize(repository, options={})
        super
        @temporary = !options.has_key?(:directory)
        @basedir = options[:directory] || Dir.mktmpdir
        builders = options[:builders] || [RightScale::Builders::Filesystem]
        @builder = RightScale::Builders::Union.new(builders,
                                                   :scraper => self,
                                                   :scanner => @scanner,
                                                   :logger => @logger,
                                                   :max_bytes => max_bytes,
                                                   :max_seconds => max_seconds)
        setup_dir
        @logger.operation(:initialize, "setting up in #{basedir}") do
          FileUtils.mkdir_p(basedir)
          @stack = []
          @next = find_next(Dir.new(basedir))
        end
      end

      def setup_dir
      end

      # (String) Base directory where filesystem will be located.
      attr_reader :basedir

      # Paths to ignore when traversing the filesystem.  Mostly used for
      # things like Git and Subversion version control directories.
      #
      # === Returns
      # List:: list of filenames to ignore.
      def ignorable_paths
        []
      end

      def reset_stack
        @stack.each {|s| s.close}
        @stack = []
      end

      # Close the scraper, cleaning up any temporary data.
      def close
        @logger.operation(:close) do
          reset_stack
          FileUtils.remove_entry_secure @basedir if @temporary
        end
      end

      # Return true if this scraper is closed.
      #
      # === Returns
      # Boolean:: true if this scraper is closed
      def closed?
        stack.empty?
      end

      # Reset the scraper to start scraping the filesystem from the
      # beginning.  Akin to IO#rewind or Dir#rewind and used for the
      # same sort of operation.
      def rewind
        @logger.operation(:rewind) do
          reset_stack
          @next = find_next(Dir.new(basedir))
        end
      end

      # Return the position of the scraper.  Here, the position is the
      # path relative from the top of the temporary directory.  Akin to
      # IO#pos or IO#tell.
      def pos
        strip_basedir(@stack.last.path)
      end
      alias_method :tell, :pos

      # Turn path from an absolute filesystem location to a relative
      # file location from #basedir.
      #
      # === Parameters
      # path(String):: absolute path to relativize
      #
      # === Returns
      # res(String):: relative pathname for path
      def strip_basedir(path)
        res = path[basedir.length+1..-1]
        if res == nil || res == ""
          "."
        else
          res
        end
      end
      private :strip_basedir

      # Seek to the given position.  Akin to IO#seek.  Position is an
      # opaque datum returned by #pos.
      #
      # === Parameters
      # position:: opaque datum listing where to seek.
      def seek(position)
        @logger.operation(:seek, "to #{position}") do
          dirs = position.split(File::SEPARATOR)
          reset_stack
          @stack << Dir.new(basedir)
          until dirs.empty?
            name = dirs.shift
            dir = @stack.last
            raise "Position #{position} no longer exists!" if seek_to_named(dir, name).nil?
            @stack << Dir.open(File.join(dir.path, name))
          end
          @next = find_next(@stack.pop)
        end
      end

      # Test if the entry given is ignorable.  By default just uses
      # #ignorable_paths
      #
      # === Parameters
      # entry(String):: file name to check
      #
      # === Returns
      # Boolean:: true if the entry should be ignored
      def ignorable?(entry)
        ignorable_paths.include?(entry)
      end

      # Find the next cookbook, starting in dir.
      #
      # === Parameters
      # dir(Dir):: directory to begin search in
      def find_next(dir)
        @logger.operation(:finding_next_cookbook, "examining #{dir.path}") do
          if File.exists?(File.join(dir.path, 'metadata.json'))
            read_cookbook(dir)
          else
            @stack << dir
            search_dirs
          end
        end
      end

      # Read a cookbook from the given path.
      #
      # === Parameters
      # dir(Dir):: directory to read cookbook from
      def read_cookbook(dir)
        @logger.operation(:reading_cookbook, "reading cookbook from #{dir.path}") do
          cookbook = RightScale::Cookbook.new(@repository, nil, strip_basedir(dir.path))
          @builder.go(dir.path, cookbook)
          cookbook
        end
      end

      # Search the directory stack looking for the next cookbook.
      def search_dirs
        @logger.operation(:searching, "looking for next cookbook") do
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

      def seek_to_named(dir, name)
        @logger.operation(:seeking, "seeking to #{name} in #{dir.path}") do
          dir.rewind
          loop do
            lastpos = dir.pos
            entry = dir.read
            if entry.nil?
              return nil
            elsif entry == name
              return lastpos
            end
          end
        end
      end
      private :seek_to_named

      # Return the next cookbook in the filesystem, or nil if none.  As
      # a part of building the cookbooks, invokes the builders.
      #
      # === Returns
      # Cookbook:: next cookbook in filesystem, or nil if none.
      def next
        @logger.operation(:next) do
          next nil if @next.nil?

          value = @next
          @next = search_dirs
          value
        end
      end
    end
  end
end
