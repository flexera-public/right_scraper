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
require 'digest/sha1'
require 'uri'

module RightScraper

  module Resources

    # Localized representation of a resource.  Contains the resource 
    # contents, and the metadata as a hash. A resource at its core is any
    # abstraction that is statically represented by a set of files and 
    # directories and metadata.
    #
    # The JSON metadata for the resource is in #metadata, and the
    # manifest is in #manifest.  
    class Base

      # (Repositories::Base) Repository the resource was fetched from.
      attr_reader :repository

      # (Hash) Metadata from the resource.
      attr_accessor :metadata

      # (Hash) Manifest for resource.  A hash of path => SHA-1 digests.
      attr_accessor :manifest

      # (String) Position in the repository.
      attr_accessor :pos
       
      # Create a new resource from the given parameters.
      #
      # === Parameters
      # repo(Repositories::Base):: Repository containing this resource
      def initialize(repo, pos)
        @repository = repo
        @pos = pos
      end

      # Resource hash
      # 
      # === Return
      # hash(String):: Hexadecimal value that uniquely identifies this resource
      def resource_hash
        Digest::SHA1.hexdigest("#{PROTOCOL_VERSION}\000#{@repository.checkout_hash}\000#{@pos}")
      end

    end
  end
end
