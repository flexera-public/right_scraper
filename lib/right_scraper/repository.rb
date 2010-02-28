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

  # Description of remote repository that needs to be scraped.
  class Repository
    
    # (String) Human readable repository name used for progress reports
    attr_accessor :display_name
    
    # (String) One of 'git', 'svn' or 'download'
    attr_accessor :repo_type
    
    # (String) URL to repository (e.g 'git://github.com/rightscale/right_scraper.git')
    attr_accessor :url
    
    # (String) Optional, tag or branch of repository that should be downloaded
    # Not used for 'download' repositories
    attr_accessor :tag
    
    # (String) Optional, SVN username or git private SSH key content
    attr_accessor :first_credential
    
    # (String) Optional, SVN password
    attr_accessor :second_credential
   
    # Initialize repository from given hash
    # Hash keys should correspond to attributes of this class
    #
    # === Parameters
    # opts(Hash):: Hash to be converted into a RightScale::Repository instance
    #
    # === Return
    # repo(RightScale::Repository):: Resulting repository instance
    def self.from_hash(opts)
      repo = RightScale::Repository.new
      opts.each do |k, v|
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
      res = "#{repo_type} #{url}:#{tag}"
    end
  end
  
end