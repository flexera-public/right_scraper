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

require File.expand_path(File.join(File.dirname(__FILE__), 'scraper_base'))
require File.expand_path(File.join(File.dirname(__FILE__), 'builders', 'archive'))
require File.expand_path(File.join(File.dirname(__FILE__), 'builders', 'manifest'))
require File.expand_path(File.join(File.dirname(__FILE__), 'builders', 'metadata'))
require File.expand_path(File.join(File.dirname(__FILE__), 'builders', 'union'))
require 'tmpdir'
require 'libarchive_ruby'

module RightScale
  class FilesystemBasedScraper < ScraperBase
    # Create a new scraper.  In addition to the options recognized by
    # ScraperBase#initialize, this class recognizes _:directory_ and
    # _:builders_.
    #
    # === Options ===
    # _:directory_:: Directory to perform scraper work in
    # _:builders_:: List of Builder classes to use, defaulting to
    #               FilesystemBuilder
    #
    # === Parameters ===
    # repository(RightScale::Repository):: repository to scrape
    # options(Hash):: scraper options
    def initialize(repository, options={})
      super
      @temporary = !options.has_key?(:directory)
      @basedir = options[:directory] || Dir.mktmpdir
      builders = options[:builders] || [FilesystemBuilder]
      @builder = UnionBuilder.new(builders,
                                  :scraper => self,
                                  :logger => @logger,
                                  :max_bytes => max_bytes,
                                  :max_seconds => max_seconds)
      @logger.operation(:initialize, "setting up in #{@basedir}") do
        FileUtils.mkdir(@basedir) unless File.exists?(@basedir)
        @stack = []
        rewind
      end
    end

    def ignorable_paths
      []
    end

    def close
      @logger.operation(:close) do
        @stack.each {|s| s.close}
        FileUtils.remove_entry_secure @basedir if @temporary
      end
    end

    def rewind
      @logger.operation(:rewind) do
        @stack.each {|s| s.close}
        @stack = [Dir.open(@basedir)]
      end
    end

    # Return the position of the scraper.  Here, the position is the
    # path relative from the top of the temporary directory.
    def position
      return strip_tmpdir(@stack.last.path)
    end

    def strip_tmpdir(path)
      res = path[@basedir.length+1..-1]
      if res == nil || res == ""
        "."
      else
        res
      end
    end

    # Seek to the given position.
    def seek(position)
      @logger.operation(:seek, "to #{position}") do
        dirs = position.split(File::SEPARATOR)
        rewind
        until dirs.empty?
          name = dirs.shift
          dir = @stack.last
          entry = dir.read
          until entry == nil || entry == name
            entry = dir.read
          end
          raise "Position #{position} no longer exists!" if entry == nil
          @stack << Dir.open(File.join(dir.path, name))
        end
        @stack.last.rewind # to make sure we don't miss a metadata.json here.
      end
    end

    def ignorable?(entry)
      ignorable_paths.include?(entry)
    end

    def next
      @logger.operation(:next) do
        until @stack.empty?
          dir = @stack.last
          entry = dir.read
          if entry == nil
            dir.close
            @stack.pop
            next
          end

          fullpath = File.join(dir.path, entry)

          next if entry == '.' || entry == '..'
          next if ignorable?(entry)

          if File.directory?(fullpath)
            @stack << Dir.new(fullpath)
            next
          elsif entry == 'metadata.json'
            cookbook = RightScale::Cookbook.new(@repository, nil, position)

            @builder.go(dir.path, cookbook)

            return cookbook
          end
        end
        nil
      end
    end
  end
end
