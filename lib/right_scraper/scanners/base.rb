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
  module Scanners
    # Base class for scanning filesystems.  Subclasses should override
    # #notice and may override #new, #begin, #end and
    # #notice_dir.
    #
    # Overriding #new is useful for getting
    # additional arguments.  Overriding #begin allows you to do
    # processing before the scan of a given resource begins;
    # overriding #end allows you to do processing after it completes.
    #
    # Most processing will occur in #notice, which notifies you that a
    # file has been detected, and in #notice_dir.  In #notice you are
    # handed the relative position of the file from the start of the
    # resource; so if you were scanning <tt>/a/resource</tt> and
    # noticed a file <tt>b/c</tt>, #notice would be called with
    # <tt>"b/c"</tt>, even though the full pathname is
    # <tt>/a/resource/b/c</tt>.  If you decide you need the actual
    # data, #notice takes a block which will return that data to you
    # if you +yield+.
    #
    # In #notice_dir you are handed the relative position of a
    # directory.  The return value determines whether you find the
    # directory worth recursing into, or not--as an example, when
    # looking for the <tt>metadata.json</tt> file it is never
    # necessary to descend past the topmost directory of the resource,
    # but the same is not true when building a manifest.
    class Base
      # Create a new Scanner.  Recognizes options as given.  Some
      # options may be required, others optional.  This class recognizes
      # only _:logger_.
      #
      # === Options ===
      # _:logger_:: Optional.  Logger currently being used
      #
      # === Parameters ===
      # options(Hash):: scanner options
      def initialize(options={})
        @logger = options.fetch(:logger, RightScraper::Logger.new)
      end

      # Notification that all scans for this repository have
      # completed.
      def finish
      end

      # Begin a scan for the given resource.
      #
      # === Parameters ===
      # resource(RightScraper::Resource::Base):: resource to scan
      def begin(resource)
      end

      # Finish a scan for the given resource.
      #
      # === Parameters ===
      # resource(RightScraper::Resource::Base):: resource that just finished
      #                                  scanning
      def end(resource)
      end

      # Notice a file during scanning.
      #
      # === Block ===
      # Return the data for this file.  We use a block because it may
      # not always be necessary to read the data.
      #
      # === Parameters ===
      # relative_position(String):: relative pathname for _pathname_
      #                             from root of resource
      def notice(relative_position)
      end

      # Notice a directory during scanning.  Returns true if the scanner
      # should recurse into the directory (the default behavior)
      #
      # === Parameters ===
      # relative_position(String):: relative pathname for the directory
      #                             from root of resource
      #
      # === Returns ===
      # Boolean:: should the scanning recurse into the directory
      def notice_dir(relative_position)
        true
      end
    end
  end
end
