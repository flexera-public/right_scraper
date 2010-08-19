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
  class Repository
    # (String) Human readable repository name used for progress reports
    attr_accessor :display_name

    # (String) Type of the repository.  Currently one of 'git', 'svn'
    # or 'download', implemented by the appropriate subclass.  Needs
    # to be overridden by subclasses.
    def repo_type
      raise NotImplementedError
    end

    # (ScraperBase class) Appropriate class for scraping this sort of
    # repository.  Needs to be overridden appropriately by subclasses.
    def scraper
      raise NotImplementedError
    end

    # (String) URL to repository (e.g 'git://github.com/rightscale/right_scraper.git')
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

    def to_url
      "#{repo_type}:#{url}"
    end

    def revision
      nil
    end

    def repository_hash
      digest("#{repo_type} #{url}")
    end

    def checkout_hash
      repository_hash
    end

    protected
    def digest(string)
      Digest::SHA1.hexdigest(string)
    end

    USERPW = Regexp.new("[^#{URI::PATTERN::UNRESERVED}#{URI::PATTERN::RESERVED}]|[:@/]", false, 'N').freeze

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
