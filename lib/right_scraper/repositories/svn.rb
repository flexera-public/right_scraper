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

module RightScraper
  module Repositories
    # A repository that is stored in a Subversion server.
    class Svn < ::RightScraper::Repositories::Base

      # (String) Optional, tag or branch of repository that should be downloaded
      attr_accessor :tag
      alias_method :revision, :tag

      # (String) Optional, SVN username
      attr_accessor :first_credential
      alias_method :username, :first_credential

      # (String) Optional, SVN password
      attr_accessor :second_credential
      alias_method :password, :second_credential

      # Create a new SvnRepository.  If the tag is not specified,
      # defaults to HEAD.
      def initialize(*args)
        super
        @tag = "HEAD" if @tag.nil?
      end

      # (String) Type of the repository, here 'svn'.
      def repo_type
        :svn
      end

      # Return a unique identifier for this revision in this repository.
      #
      # === Returns
      # String:: opaque unique ID for this revision in this repository
      def checkout_hash
        digest("#{PROTOCOL_VERSION}\000#{repo_type}\000#{url}\000#{tag}")
      end

      # Convert this repository to a URL in the style of resource URLs.
      #
      # === Returns
      # URI:: URL representing this repository
      def to_url
        if first_credential
          uri = add_users_to(url, first_credential, second_credential)
        else
          uri = URI.parse(url)
        end
        uri
      end

      # Instantiate retriever for this kind of repository
      #
      # === Options
      # <tt>:max_bytes</tt>:: Maximum number of bytes to read
      # <tt>:max_seconds</tt>:: Maximum number of seconds to spend reading
      # <tt>:basedir</tt>:: Destination directory, use temp dir if not specified
      # <tt>:logger</tt>:: Logger to use
      #
      # === Return
      # retriever(Retrivers::Svn):: Retriever for this repository
      def retriever(options)
        RightScraper::Retrievers::Svn.new(self, options)
      end

      # self-register
      register_self
      register_url_schemas('svn', 'svn+ssh')
    end
  end
end
