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

module RightScale
  # A cookbook repository stored in a Git repository.
  class GitRepository < Repository
    def initialize(*args)
      super
      @tag = "master" if @tag.nil?
    end

    # (String) Type of the repository, here 'git'.
    def repo_type
      :git
    end

    # (String) Optional, tag or branch of repository that should be downloaded
    attr_accessor :tag
    alias_method :revision, :tag
    
    # (String) Optional, git private SSH key content
    attr_accessor :first_credential

    # Unique representation for this repo, should resolve to the same string
    # for repos that should be cloned in same directory
    #
    # === Returns
    # res(String):: Unique representation for this repo
    def to_s
      res = "git #{url}:#{tag}"
    end

    def to_url
      if first_credential
        uri = add_users_to(url, first_credential)
      else
        uri = URI.parse(url)
      end
      uri
    end

    # (ScraperBase class) Appropriate class for scraping this sort of
    # repository.
    def scraper
      RightScale::GitScraper
    end

    # Add this repository to the list of available types.
    @@types[:git] = RightScale::GitRepository
  end
end
