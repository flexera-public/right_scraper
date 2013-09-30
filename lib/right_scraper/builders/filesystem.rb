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
require 'right_scraper/builders'

module RightScraper
  module Builders
    # Build metadata by scanning the filesystem.
    class Filesystem < ::RightScraper::Builders::Base

      # Create a new filesystem scanner.  In addition to the options
      # recognized by Builder, this class recognizes <tt>:retriever</tt> and
      # <tt>:scanner</tt>.
      #
      # === Options
      # <tt>:scanner</tt>:: Required.  Scanner currently being used
      # <tt>:ignorable_paths</tt>:: Ignore directories whose name belong to this list
      #
      # === Parameters
      # options(Hash):: scraper options
      def initialize(options={})
        super
        @scanner = options.fetch(:scanner)
        @ignorable_paths = options[:ignorable_paths]
      end

      # Tell the scanner we're done.
      def finish
        super
        @scanner.finish
      end

      # Run builder for this resource.
      #
      # === Parameters
      # dir(String):: directory resource exists at
      # resource(Object):: resource instance being built
      def go(dir, resource)
        @logger.operation(:scanning_filesystem, "rooted at #{dir}") do
          @scanner.begin(resource)
          maybe_scan(Dir.new(dir), nil)
          @scanner.end(resource)
        end
      end

      def maybe_scan(directory, position)
        if @scanner.notice_dir(position)
          scan(directory, position)
        end
      end

      # Scan the contents of directory.
      #
      # === Parameters
      # directory(Dir):: directory to scan
      # position(String):: relative pathname for _directory_ from root of resource
      def scan(directory, position)
        directory.each do |entry|
          next if entry == '.' || entry == '..'
          next if @ignorable_paths && @ignorable_paths.include?(entry)

          fullpath = File.join(directory.path, entry)
          relative_position = position ? File.join(position, entry) : entry

          if File.directory?(fullpath)
            maybe_scan(Dir.new(fullpath), relative_position)
          else
            # bind the temporary parameters to the callback in case it is not
            # invoked immediately.
            bind_now = lambda{|file| lambda{ open(file) {|f| f.read} } }.call(fullpath)
            @scanner.notice(relative_position, &bind_now)
          end
        end
      end
    end
  end
end
