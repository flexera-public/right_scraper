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
require 'digest/sha1'
require 'uri'

module RightScale
  # Localized representation of a cookbook.  Contains the repository
  # it was fetched from, the cookbook contents, and the metadata as a
  # hash.
  #
  # Cookbooks can be converted to and from URL-type syntaxes with
  # RightScale::Cookbook#to_url and RightScale::Cookbook::from_url,
  # with the caveat that it is not at present possible to perfectly
  # reconstruct the repository a cookbook uses from the cookbook URL.
  # The JSON metadata for the Cookbook is in #metadata, and the
  # manifest is in #manifest.  The last interesting method is
  # #cookbook_hash, which returns a unique identifier for that
  # cookbook.
  class Cookbook
    # (RightScale::Repository) Repository the cookbook was fetched from.
    attr_accessor :repository

    # (Hash) Metadata from the cookbook.
    attr_accessor :metadata

    # (Hash) Miscellaneous unsynchronized data; currently used to
    # store the archive itself.
    attr_accessor :data

    # (Hash) Manifest for cookbook.  A hash of path => SHA-1 digests.
    attr_accessor :manifest

    # Position in the repository.  A datum gotten from the scraper and
    # associated with it.
    attr_accessor :pos

    # Create a new Cookbook from the given parameters.
    #
    # === Parameters
    # repo(RightScale::Repository):: repository to load cookbook from
    # metadata(Hash):: metadata for the cookbook
    # pos:: position in the repository
    def initialize(repo, metadata, pos)
      @repository = repo
      @data = {}
      @metadata = metadata
      @pos = pos
    end

    # Load a cookbook from a repository and a position in the repository.
    #
    # === Parameters
    # repo(RightScale::Repository):: repository to load cookbook from
    # position:: position in the repository
    def self.fetch(repo, pos)
      scraper = repo.scraper
      scraper.seek(pos)
      scraper.next
    end

    # Convert this Cookbook to a Cookbook URL that completely
    # describes where and how to fetch the cookbook.  It should always
    # be the case that
    #   Cookbook.from_url(cookbook.to_url) == cookbook
    #
    # One caveat is that the credentials required to access the
    # repository this cookbook points to are not encoded as a part of
    # this URL, meaning that it is not necessarily possible to
    # rescrape a cookbook without knowing those credentials elsewhere.
    # However due to the definition of Repository#repository_hash and
    # Repository#checkout_hash, those hashes are accurate.
    def to_url
      repo_url = @repository.to_url
      if repo_url.userinfo
        repo_url.user = nil
        repo_url.password = nil
      end
      unless pos.nil?
        query = Cookbook.parse_query(repo_url.query || "")
        query["p"] = [pos.to_s]
        repo_url.query = Cookbook.unparse_query(query)
      end
      unless @repository.revision.nil?
        repo_url.fragment = @repository.revision
      end
      "#{@repository.repo_type}:#{repo_url}"
    end

    # Return a hexadecimal string that uniquely identifies this
    # cookbook.
    def cookbook_hash
      Digest::SHA1.hexdigest("#{@repository.checkout_hash} #{pos}")
    end

    # Create a new Cookbook from the given Cookbook URL.  It should
    # always be the case that
    #   Cookbook.from_url(cookbook.to_url) == cookbook
    #
    # === Parameters
    # url(String):: URL to create cookbook from.
    def self.from_url(url)
      hash, pos = split_url(url)
      @repo = Repository.from_hash(hash)
      Cookbook.new(@repo, nil, pos)
    end

    private

    # Parse the query component of a URL into a hash.  Currently
    # implemented in terms of CGI::parse.  Should always be the case that
    #  parse_query(unparse_query(hash)) == hash
    #
    # The converse may not be true because HTTP query strings are not
    # unique; in particular & and ; are interchangable.
    #
    # === Parameters
    # string(String):: Query component of URL.
    #
    # === Returns
    # Hash:: association from keys to (possibly multiple) values.
    def self.parse_query(string)
      CGI::parse(string)
    end

    # Turn a CGI-style hash into the query component of a URL into a
    # hash.    Should always be the case that
    #  parse_query(unparse_query(hash)) == hash
    #
    # The converse may not be true because HTTP query strings are not
    # unique; in particular & and ; are interchangable.
    #
    # === Parameters
    # hash(Hash):: association from keys to (possibly multiple) values.
    #
    # === Returns
    # String:: Corresponding query component of URL.
    def self.unparse_query(hash)
      keys = hash.keys.sort
      keys.map do |key|
        hash[key].sort.map do |value|
          CGI::escape(key) + "=" + CGI::escape(value)
        end.join(";")
      end.join(';')
    end

    # Split a Cookbook URL into its component parts.  The bulk is in
    # +hash+, which has the following keys: <tt>:repo_type</tt>::
    # Required.  Repository type, which should be a value suitable for
    # Repository#from_hash.  <tt>:url</tt>:: Required.  Remaining URL
    # after Cookbook specific parts have been parsed out.
    # <tt>:first_credential</tt>:: Optional.  First credential
    # required for access (usually username).
    # <tt>:second_credential</tt>:: Optional.  Second credential
    # required for access (usually password).  <tt>:tag</tt>::
    # Optional.  Tag of the checkout in question.
    #
    # === Parameters
    # url(String):: Cookbook URL to parse.
    #
    # === Returns
    # Two values, hash and position, defined as follows:
    # hash(Hash):: components of the Cookbook URL, defined above.
    # position(String):: position of the Cookbook in the repository.
    def self.split_url(url)
      scheme, full_url = url.split(":", 2)
      uri = URI.parse(full_url)
      userinfo, query, tag = uri.select(:userinfo, :query, :fragment)
      unless userinfo.nil?
        username, password = userinfo.split(":", 2).map {|str| URI.unescape str}
        uri.user = nil
        uri.password = nil
      end
      unless query.nil?
        hash = parse_query(query)
        position = hash["p"][0]
        hash.delete("p")
        result = unparse_query(hash)
        if result == ""
          uri.query = nil
        else
          uri.query = result
        end
      end
      uri.fragment = nil unless tag.nil?
      hash = Hash.new
      hash[:repo_type] = scheme.to_sym
      hash[:url] = uri.to_s
      hash[:first_credential] = username unless username.nil?
      hash[:second_credential] = password unless password.nil?
      hash[:tag] = tag unless tag.nil?
      [hash, position]
    end
  end
end
