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
require 'uri'
require 'digest/sha1'

module RightScale
  # Description of remote repository that needs to be scraped.
  #
  # Repository definitions inherit from this base class.  A repository must
  # register its #repo_type in @@types so that they can be used with
  # Repository::from_hash, as follows:
  #  class ARepository < Repository
  #    ...
  #
  #    # Add this repository to the list of available types.
  #    @@types[:arepository] = ARepository
  #  end
  #
  # Subclasses should override #repo_type, #scraper, and #to_url; when
  # sensible, #revision should also be overridden.  The most important
  # methods are #to_url, which will return a +URI+ that completely
  # characterizes the RightScale::Repository, and #scraper which
  # returns the appropriate RightScale::Scrapers::ScraperBase to scan
  # that repository.
  class Repository
    # (String) Human readable repository name used for progress reports
    attr_accessor :display_name

    # (String) Type of the repository.  Currently one of 'git', 'svn'
    # or 'download', implemented by the appropriate subclass.  Needs
    # to be overridden by subclasses.
    def repo_type
      raise NotImplementedError
    end

    # (RightScale::Scrapers::ScraperBase class) Appropriate class for scraping this sort of
    # repository.  Needs to be overridden appropriately by subclasses.
    def scraper
      raise NotImplementedError
    end

    # (String) URL to repository (e.g 'git://github.com/rightscale/right_scraper_base.git')
    attr_accessor :url

    # (Hash) Lookup table from textual description of repository type
    # ('git', 'svn' or 'download' currently) to the class that
    # represents that repository.
    @@types = {} unless class_variable_defined?(:@@types)

    # Initialize repository from given hash
    # Hash keys should correspond to attributes of this class
    #
    # === Parameters
    # opts(Hash):: Hash to be converted into a RightScale::Repository instance
    #
    # === Return
    # repo(RightScale::Repository):: Resulting repository instance
    def self.from_hash(opts)
      repo = @@types[opts[:repo_type]].new
      opts.each do |k, v|
        repo.__send__("#{k.to_s}=".to_sym, v) unless k == :repo_type
      end
      repo
    end

    # Unique representation for this repo, should resolve to the same string
    # for repos that should be cloned in same directory
    #
    # === Returns
    # res(String):: Unique representation for this repo
    def to_s
      res = "#{repo_type} #{url}"
    end

    # Convert this repository to a URL in the style of Cookbook URLs.
    #
    # === Returns
    # URI:: URL representing this repository
    def to_url
      URI.parse(url)
    end

    # Return the revision this repository is currently looking at.
    #
    # === Returns
    # String:: opaque revision type
    def revision
      nil
    end

    # Return a unique identifier for this repository ignoring the tags
    # to check out.
    #
    # === Returns
    # String:: opaque unique ID for this repository
    def repository_hash
      digest("#{repo_type} #{url}")
    end


    # Return a unique identifier for this revision in this repository.
    #
    # === Returns
    # String:: opaque unique ID for this revision in this repository
    def checkout_hash
      repository_hash
    end

    # Return true if this repository and +other+ represent the same
    # repository including the same checkout tag.
    #
    # === Parameters
    # other(Repository):: repository to compare with
    #
    # === Returns
    # Boolean:: true iff this repository and +other+ are the same
    def ==(other)
      if other.is_a?(RightScale::Repository)
        checkout_hash == other.checkout_hash
      else
        false
      end
    end

    # Return true if this repository and +other+ represent the same
    # repository, excluding the checkout tag.
    #
    # === Parameters
    # other(Repository):: repository to compare with
    #
    # === Returns
    # Boolean:: true iff this repository and +other+ are the same
    def equal_repo?(other)
      if other.is_a?(RightScale::Repository)
        repository_hash == other.repository_hash
      else
        false
      end
    end

    protected
    # Compute a unique identifier for the given string.  Currently uses SHA1.
    #
    # === Parameters
    # string(String):: string to compute unique identifier for
    #
    # === Returns
    # String:: unique identifier
    def digest(string)
      Digest::SHA1.hexdigest(string)
    end

    # Regexp matching everything not allowed in a URI and also ':',
    # '@' and '/', to be used for encoding usernames and passwords.
    USERPW = Regexp.new("[^#{URI::PATTERN::UNRESERVED}#{URI::PATTERN::RESERVED}]|[:@/]", false, 'N').freeze

    # Return a URI with the given username and password set.
    #
    # === Parameters
    # uri(URI or String):: URI to add user identification to
    #
    # === Returns
    # URI:: URI with username and password identification added
    def add_users_to(uri, username=nil, password=nil)
      uri = URI.parse(uri) if uri.instance_of?(String)
      if username
        userinfo = URI.escape(username, USERPW)
        userinfo += ":" + URI.escape(password, USERPW) unless password.nil?
        uri.userinfo = userinfo
      end
      uri
    end
  end
end
