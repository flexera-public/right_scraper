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
    # Union builder, to permit running multiple builders in sequence
    # with the same interface as running one.
    class Union
      # (Array) subcomponents of this union
      attr_reader :subbuilders

      # Create a new union builder.  Recognizes no new options.
      #
      # === Parameters
      # classes(List):: List of Builder classes to run
      # options(Hash):: options to initialize each Builder with
      def initialize(classes, options={})
        @subbuilders = classes.map {|klass| klass.new(options)}
      end

      # Run each builder for this resource.
      #
      # === Parameters
      # dir(String):: directory resource exists at
      # resource(RightScraper::Resources::Base):: resource instance being built
      def go(dir, resource)
        @subbuilders.each {|builder| builder.go(dir, resource)}
      end

      # Notify subbuilders that all scans for this repository have
      # completed.
      def finish
        @subbuilders.each {|builder| builder.finish}
      end
    end
  end
end
