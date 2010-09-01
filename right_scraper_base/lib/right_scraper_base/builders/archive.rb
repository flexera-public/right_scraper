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
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'process_watcher'))
require 'digest/sha1'

module RightScale
  module Builders
    # Class for building tarballs from filesystem based checkouts.
    class Archive < Builder
      include ProcessWatcher

      # Create a new ArchiveBuilder.  In addition to the options
      # recognized by Builder, recognizes :scraper,
      # :max_bytes, and :max_seconds.
      #
      # === Options
      # <tt>:scraper</tt>:: Required.  FilesystemBasedScraper currently being used
      # <tt>:max_bytes</tt>:: Optional.  Maximum size of archive to attempt to create.
      # <tt>:max_seconds</tt>:: Optional.  Maximum amount of time to attempt to create the archive.
      def initialize(options={})
        super
        @scraper = options.fetch(:scraper)
        @max_bytes = options[:max_bytes]
        @max_seconds = options[:max_seconds]
      end

      # Build archive.
      #
      # === Parameters
      # dir(String):: directory where cookbook exists
      # cookbook(RightScale::Cookbook):: cookbook being built
      def go(dir, cookbook)
        @logger.operation(:creating_archive) do
          exclude_declarations =
            @scraper.ignorable_paths.map {|path| ["--exclude", path]}
          cookbook.data[:archive] =
            watch("tar", ["-C", dir, "-c", exclude_declarations, "."].flatten, @max_bytes, @max_seconds)
        end
      end
    end
  end
end
