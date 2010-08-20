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
require 'tmpdir'
require 'libarchive_ruby'

module RightScale
  class FilesystemBasedScraper < ScraperBase
    def initialize(repository, options={})
      super
      @temporary = !options.has_key?(:directory)
      @basedir = options[:directory] || Dir.mktmpdir
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
            cookbook = RightScale::Cookbook.new(@repository, nil, nil, position)

            @logger.operation(:reading_metadata) do
              cookbook.metadata = JSON.parse(open(fullpath) {|f| f.read })
            end

            @logger.operation(:creating_manifest) do
              cookbook.manifest = make_manifest(dir.path)
            end

            @logger.operation(:creating_archive) do
              # make new archive rooted here
              exclude_declarations =
                ignorable_paths.map {|path| "--exclude #{path}"}.join(' ')
              cookbook.archive =
                watch("tar -C #{File.dirname fullpath} -c #{exclude_declarations} .")
            end

            return cookbook
          end
        end
        nil
      end
    end

    def make_manifest(path)
      hash = {}
      scan(Dir.new(path), hash, nil)
      hash
    end

    def scan(directory, hash, position)
      directory.each do |entry|
        next if entry == '.' || entry == '..'
        next if ignorable?(entry)

        fullpath = File.join(directory.path, entry)
        relative_position = position ? File.join(position, entry) : entry

        if File.directory?(fullpath)
          scan(Dir.new(fullpath), hash, relative_position)
        else
          digest = Digest::SHA1.new
          open(fullpath) do |f|
            digest << f.read(2048) until f.eof?
          end
          hash[relative_position] = digest.hexdigest
        end
      end
    end
    private :scan
  end
end
