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
require 'set'
require 'socket'
require File.expand_path(File.join(File.dirname(__FILE__), 'version'))

module RightScraper
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
  # characterizes the RightScraper::Repository, and #scraper which
  # returns the appropriate RightScraper::Scrapers::ScraperBase to scan
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

    # (RightScraper::Scrapers::ScraperBase class) Appropriate class for scraping this sort of
    # repository.  Needs to be overridden appropriately by subclasses.
    def scraper
      raise NotImplementedError
    end

    # (Array of String):: subdirectories in the repository to search for cookbooks
    attr_accessor :cookbooks_path

    # (String) URL to repository (e.g 'git://github.com/rightscale/right_scraper_base.git')
    attr_accessor :url

    # (Hash) Lookup table from textual description of repository type
    # ('git', 'svn' or 'download' currently) to the class that
    # represents that repository.
    @@types = {} unless class_variable_defined?(:@@types)

    # (Set) list of acceptable URI schemes.  Initially just http, https and ftp.
    @@okay_schemes = Set.new(["http", "https", "ftp"])

    # Initialize repository from given hash
    # Hash keys should correspond to attributes of this class
    #
    # === Parameters
    # opts(Hash):: Hash to be converted into a RightScraper::Repository instance
    #
    # === Return
    # repo(RightScraper::Repository):: Resulting repository instance
    def self.from_hash(opts)
      repo_class = @@types[opts[:repo_type]]
      raise "Can't understand how to make #{opts[:repo_type]} repos" if repo_class.nil?
      repo = repo_class.new
      unless ENV['DEVELOPMENT']
        validate_uri opts[:url]
      end
      opts.each do |k, v|
        next if k == :repo_type
        if [:first_credential, :second_credential].include?(k) && is_useful?(v)
          v = useful_part(v)
        end
        repo.__send__("#{k.to_s}=".to_sym, v)
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
      digest("#{RS_PROTOCOL_VERSION}\000#{repo_type}\000#{url}")
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
      if other.is_a?(RightScraper::Repository)
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
      if other.is_a?(RightScraper::Repository)
        repository_hash == other.repository_hash
      else
        false
      end
    end

    protected
    # Return true iff this credential is useful.  Currently "useful"
    # means "nonempty and not all spaces".
    def self.is_useful?(credential)
      credential && !credential.strip.empty?
    end

    # Return the useful portion of this credential.  Currently strips
    # out any spaces.
    def self.useful_part(credential)
      credential.strip
    end

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
      begin
        uri = URI.parse(uri) if uri.instance_of?(String)
        if username
          userinfo = URI.escape(username, USERPW)
          userinfo += ":" + URI.escape(password, USERPW) unless password.nil?
          uri.userinfo = userinfo
        end
        uri
      rescue URI::InvalidURIError
        if uri =~ PATTERN::GIT_URI
          user, host, path = $1, $2, $3
          userinfo = URI.escape(user, USERPW)
          userinfo += ":" + URI.escape(username, USERPW) unless username.nil?
          path = "/" + path unless path.start_with?('/')
          URI::Generic::build({:scheme => "ssh",
                                :userinfo => userinfo,
                                :host => host,
                                :path => path
                              })
        else
          raise
        end
      end
    end

    module PATTERN
      include URI::REGEXP::PATTERN
      GIT_URI = Regexp.new("^((?:[#{UNRESERVED}]|#{ESCAPED})*)@(#{HOST}):(#{ABS_PATH}|#{REL_PATH})$")
    end

    SSH_PORT = 22

    def self.validate_uri(uri)
      begin
        uri = URI.parse(uri) if uri.instance_of?(String)
        raise "Invalid URI #{uri}: don't know how to interpret scheme #{uri.scheme}" unless @@okay_schemes.include?(uri.scheme)
        check_host(uri, uri.host, uri.port)
      rescue URI::InvalidURIError
        # could be a Git type URI.
        if uri =~ PATTERN::GIT_URI
          check_host(uri, $2, SSH_PORT)
        else
          raise
        end
      end
    end

    def self.check_host(uri, host, port)
      begin
        possibles = Socket.getaddrinfo(host, port, Socket::AF_INET, Socket::SOCK_STREAM, Socket::IPPROTO_TCP)
        raise "Invalid URI #{uri}: no hosts for #{host}:#{port}" if possibles.nil? || possibles.empty?
        possibles.each do |possible|
          family, port, hostname, address, protocol_family, socket_type, protocol = possible

          # Our EC2 gateway is not permitted.
          raise "Invalid URI #{uri}" if address == "169.254.169.254"
          # Loopbacks are not permitted.
          raise "Invalid URI #{uri}" if address =~ /^127\.[0-9]+\.[0-9]+\.[0-9]+$/

          # Private networks are not permitted
          raise "Invalid URI #{uri}" if address =~ /^10\.[0-9]+\.[0-9]+\.[0-9]+$/
          raise "Invalid URI #{uri}" if address =~ /^172\.(1[6-9]|[23][0-9])\.[0-9]+\.[0-9]+$/
          raise "Invalid URI #{uri}" if address =~ /^192\.168\.[0-9]+\.[0-9]+$/
        end
        true
      rescue SocketError
        # means the host doesn't exist
        raise "Invalid URI #{uri}: no hosts for #{host}:#{port}"
      end
    end
  end
end
