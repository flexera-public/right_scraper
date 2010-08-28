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
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'repository'))

module RightScale
  module Repositories
    # A "cookbook repository" that is just an archive file hanging off a
    # web server somewhere.
    class Download < Repository
      # (String) Type of the repository, here 'download'.
      def repo_type
        :download
      end

      # (String) Optional, username
      attr_accessor :first_credential

      # (String) Optional, password
      attr_accessor :second_credential

      # Unique representation for this repo, should resolve to the same string
      # for repos that should be cloned in same directory
      #
      # === Returns
      # res(String):: Unique representation for this repo
      def to_s
        res = "download #{url}"
      end

      # Convert this repository to a URL in the style of Cookbook URLs.
      #
      # === Returns
      # URI:: URL representing this repository
      def to_url
        add_users_to(url, first_credential, second_credential)
      end

      # (ScraperBase class) Appropriate class for scraping this sort of
      # repository.
      def scraper
        RightScale::Scrapers::Download
      end

      # Add this repository to the list of available types.
      @@types[:download] = RightScale::Repositories::Download
    end
  end
end
