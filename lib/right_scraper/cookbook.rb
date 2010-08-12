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

require 'json'

module RightScale
  # Localized representation of a cookbook.  Contains the repository
  # it was fetched from, the cookbook contents, and the metadata as a
  # hash.
  class Cookbook
    # (RightScale::Repository) Repository the cookbook was fetched from.
    attr_accessor :repository

    # (Archive) Archive of the cookbook.
    attr_accessor :archive

    # (Hash) Metadata from the cookbook.
    attr_accessor :metadata

    # Position in the repository.  A datum gotten from the scraper and
    # associated with it.
    attr_accessor :position

    # Create a new Cookbook from the given parameters.
    #
    # === Parameters
    # repo(RightScale::Repository):: repository to load cookbook from
    # archive(Archive):: cookbook archive
    # metadata(Hash):: metadata for the cookbook
    # position:: position in the repository
    def initialize(repo, archive, metadata, position)
      @repository = repo
      @archive = archive
      @metadata = metadata
      @position = position
    end

    # Load a cookbook from a repository and a position in the repository.
    #
    # === Parameters
    # repo(RightScale::Repository):: repository to load cookbook from
    # position:: position in the repository
    def self.fetch(repo, position)
      scraper = repo.scraper
      scraper.seek(position)
      scraper.next
    end
  end
end
