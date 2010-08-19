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
require 'json'
require 'uri'

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

    def to_url
      repo_url = @repository.to_url
      position_portion = position.nil? ? "" : "?p=#{position}"
      tag_portion = @repository.revision.nil? ? "" : "\##{@repository.revision}"
      "#{@repository.repo_type}:#{repo_url}#{position_portion}#{tag_portion}"
    end

    def cookbook_hash
      Digest::SHA1.hexdigest("#{@repository.checkout_hash} #{position}")
    end

    def self.from_url(url)
      hash, position = split_url(url)
      @repo = Repository.from_hash(hash)
      Cookbook.new(@repo, nil, nil, position)
    end

    def self.parse_query(string)
      CGI::parse(string)
    end

    def self.unparse_query(hash)
      keys = hash.keys.sort
      keys.map do |key|
        hash[key].sort.map do |value|
          CGI::escape(key) + "=" + CGI::escape(value)
        end.join(";")
      end.join(';')
    end

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
