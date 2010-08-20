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

require File.expand_path(File.join(File.dirname(__FILE__), '..', 'scraper_spec_helper_base'))
require 'svn/repos'

module RightScale

  # SVN implementation of scraper spec helper
  # See parent class for methods headers comments
  class SvnScraperSpecHelper < ScraperSpecHelperBase
    def svn_repo_path
      File.join(@tmpdir, "svn")
    end

    attr_reader :repo

    def scraper_path
      File.join(@tmpdir, "scraper")
    end

    def repo_url
      file_prefix = 'file://'
      file_prefix += '/' if RUBY_PLATFORM =~ /mswin/
      url = "#{file_prefix}#{svn_repo_path}"
    end

    def initialize
      super()
      FileUtils.mkdir(svn_repo_path)
      @repo = RightScale::Repository.from_hash(:display_name => 'test repo',
                                               :repo_type    => :svn,
                                               :url          => repo_url)
      @client = SvnClient.new(@repo)
      @svnrepo = Svn::Repos.create(svn_repo_path, {}, {})
      @client.with_context {|ctx| ctx.checkout(repo_url, repo_path)}
      create_cookbook(repo_path, repo_content)
      commit_content
    end

    def close
      @repository.close unless @repos.nil?
      @repository = nil
    end

    def delete(location, log="")
      @client.with_context(log) {|ctx|
        ctx.delete(location)
      }
    end

    def commit_content(commit_message='commit message')
      @client.with_context(commit_message) {|ctx|
        Dir.glob(File.join(repo_path, '*')) {|file| ctx.add(file, true, true) }
        ctx.commit(repo_path)
      }
    end

    def commit_id(index_from_last=0)
      @client.with_context('fetching logs') {|ctx|
        seen = []
        ctx.log(repo_path, 1, "HEAD", 0, true, nil,
                nil) {|changed, rev, author, date, message|
          seen << rev
          seen.shift if seen.length > index_from_last+1
        }
        seen.first
      }
    end
  end
end
