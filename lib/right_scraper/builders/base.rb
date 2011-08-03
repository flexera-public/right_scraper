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

require File.expand_path(File.join(File.dirname(__FILE__), '..', 'logger'))

module RightScraper
  module Builders
    # Base class for building additional metadata from filesystem
    # based checkouts.  Subclasses should override #go, and possibly
    # #new if they require additional arguments.
    #
    # The lifecycle for a builder is as follows:
    # - builder = Builder.new (once)
    # - builder.go(dir, resource) (many times)
    # - builder.finish (once)
    class Builder
      # Create a new Builder.  Recognizes options as given.  Some
      # options may be required, others optional.  This class recognizes
      # only :logger.
      #
      # === Options
      # <tt>:logger</tt>:: Optional.  Logger currently being used
      #
      # === Parameters
      # options(Hash):: builder options
      def initialize(options={})
        @logger = options.fetch(:logger, Logger.new)
      end

      # Run builder for this resource.
      #
      # === Parameters
      # dir(String):: directory resource exists at
      # resource(Object):: resource instance being built
      def go(dir, resource)
      end

      # Notification that all scans for this repository have
      # completed.
      def finish
      end
    end
  end
end
