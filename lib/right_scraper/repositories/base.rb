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
require 'right_scraper/repositories'

require 'uri'
require 'digest/sha1'
require 'set'
require 'socket'

module RightScraper::Repositories

  # Description of remote repository that needs to be scraped.
  #
  # Repository definitions inherit from this base class.  A repository must
  # register its #repo_type in @@types so that they can be used with
  # Repositories::Base::from_hash, as follows:
  #
  #  class Foo < ::RightScraper::Repositories::Base
  #    ...
  #
  #    # self-register
  #    register_self
  #    register_url_schemas('foo')
  #  end
  #
  # Subclasses should override #repo_type, #retriever and #to_url; when
  # sensible, #revision should also be overridden.  The most important
  # methods are #to_url, which will return a +URI+ that completely
  # characterizes the repository, and #retriever which returns the
  # appropriate RightScraper::Retrievers::Base to scan that repository.
  class Base < ::RightScraper::RegisteredBase

    # exceptions
    class RepositoryError < ::StandardError; end

    # @return [Module] module for registered repository types
    def self.registration_module
      ::RightScraper::Repositories
    end

    # @return [Set] set of registered repo url schemas
    def self.registered_url_schemas
      unless schemas = registration_module.instance_variable_get(:@registered_url_schemas)
        schemas = ::Set.new(['http', 'https', 'ftp'])
        registration_module.instance_variable_set(:@registered_url_schemas, schemas)
      end
      schemas
    end

    # Registers any unknown URL schemas for validation.
    #
    # @param [Array] args to register as URL schema(s)
    #
    # @return [TrueClass] always true
    def self.register_url_schemas(*args)
      # note that set += blah seems to be badly implemented as set = set + blah
      # for the Set class, which leaves the original set object unchanged and
      # will return a new set object with the new data. only use the << operator
      # to update an existing set object.
      schemas = registered_url_schemas
      Array(args).flatten.each { |schema| schemas << schema }
      true
    end

    # Factory method for a new repository.
    #
    # @param [Hash] repo_hash describing repository to create
    #
    # @return [RightScraper::Repositories::Base] repository created
    def self.from_hash(repo_hash)
      repo_type = repo_hash[:repo_type].to_s
      raise ::ArgumentError, ':repo_type is required' if repo_type.empty?
      repo_class = query_registered_type(repo_type)
      repo = repo_class.new
      validate_uri(repo_hash[:url]) unless ENV['DEVELOPMENT']
      repo_hash.each do |k, v|
        k = k.to_sym
        next if k == :repo_type
        if [:first_credential, :second_credential].include?(k) && is_useful?(v)
          v = useful_part(v)
        end
        repo.__send__("#{k.to_s}=".to_sym, v)
      end
      repo
    end

    # (String) Human readable repository name used for progress reports
    attr_accessor :display_name

    # (Array of String) Subdirectories in the repository to search for resources
    attr_accessor :resources_path

    # (String) URL to repository (e.g 'git://github.com/rightscale/right_scraper.git')
    attr_accessor :url

    # (String) Type of the repository.  Currently one of 'git', 'svn'
    # or 'download', implemented by the appropriate subclass.  Needs
    # to be overridden by subclasses.
    def repo_type
      raise NotImplementedError
    end

    # (RightScraper::Retrievers::Base class) Appropriate class for retrieving this sort of
    # repository.  Needs to be overridden appropriately by subclasses.
    #
    # === Options
    # <tt>:max_bytes</tt>:: Maximum number of bytes to read
    # <tt>:max_seconds</tt>:: Maximum number of seconds to spend reading
    # <tt>:basedir</tt>:: Destination directory, use temp dir if not specified
    # <tt>:logger</tt>:: Logger to use
    #
    # === Returns
    # retriever(Retrievers::Base):: Corresponding retriever instance
    def retriever(options)
      raise NotImplementedError
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
      digest("#{::RightScraper::PROTOCOL_VERSION}\000#{repo_type}\000#{url}")
    end

    # Return a unique identifier for this revision in this repository.
    #
    # === Returns
    # String:: opaque unique ID for this revision in this repository
    def checkout_hash
      repository_hash
    end

    # Unique representation for this repo, should resolve to the same string
    # for repos that should be cloned in same directory
    #
    # === Returns
    # res(String):: Unique representation for this repo
    def to_s
      res = "#{repo_type} #{url}"
    end

    # Convert this repository to a URL in the style of resource URLs.
    #
    # === Returns
    # URI:: URL representing this repository
    def to_url
      URI.parse(url)
    end

    # Return true if this repository and +other+ represent the same
    # repository including the same checkout tag.
    #
    # === Parameters
    # other(Repositories::Base):: repository to compare with
    #
    # === Returns
    # Boolean:: true iff this repository and +other+ are the same
    def ==(other)
      if other.is_a?(RightScraper::Repositories::Base)
        checkout_hash == other.checkout_hash
      else
        false
      end
    end

    # Return true if this repository and +other+ represent the same
    # repository, excluding the checkout tag.
    #
    # === Parameters
    # other(Repositories::Base):: repository to compare with
    #
    # === Returns
    # Boolean:: true iff this repository and +other+ are the same
    def equal_repo?(other)
      if other.is_a?(RightScraper::Repositories::Base)
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
        unless registered_url_schemas.include?(uri.scheme)
          raise RepositoryError,
                "Invalid URI #{uri}: don't know how to interpret scheme #{uri.scheme}"
        end
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
        if possibles.nil? || possibles.empty?
          raise RepositoryError, "Invalid URI #{uri}: no hosts for #{host}:#{port}"
        end
        possibles.each do |possible|
          family, port, hostname, address, protocol_family, socket_type, protocol = possible

          # Our EC2 gateway is not permitted.
          if address == '169.254.169.254'
            raise RepositoryError, "Invalid URI #{uri}"
          end

          # Loopbacks are not permitted.
          if address =~ /^127\.[0-9]+\.[0-9]+\.[0-9]+$/
            raise RepositoryError, "Invalid URI #{uri}"
          end

            # Private networks are not permitted
          if address =~ /^10\.[0-9]+\.[0-9]+\.[0-9]+$/
            raise RepositoryError, "Invalid URI #{uri}"
          end
          if address =~ /^172\.(1[6-9]|[23][0-9])\.[0-9]+\.[0-9]+$/
            raise RepositoryError, "Invalid URI #{uri}"
          end
          if address =~ /^192\.168\.[0-9]+\.[0-9]+$/
            raise RepositoryError, "Invalid URI #{uri}"
          end
        end
        true
      rescue SocketError
        # means the host doesn't exist
        raise RepositoryError, "Invalid URI #{uri}: no hosts for #{host}:#{port}"
      end
    end

  end
end
