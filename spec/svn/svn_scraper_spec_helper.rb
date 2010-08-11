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

module RightScale

  # SVN implementation of scraper spec helper
  # See parent class for methods headers comments
  class SvnScraperSpecHelper < ScraperSpecHelperBase

    def svn_repo_path
      svn_repo_path = File.expand_path(File.join(File.dirname(__FILE__), '__svn_repo'))
    end

    def repo_url
      file_prefix = 'file://'
      file_prefix += '/' if RUBY_PLATFORM =~ /mswin/
      url = "#{file_prefix}#{svn_repo_path}"
    end

    def setup_test_repo
      FileUtils.rm_rf(repo_path)
      FileUtils.mkdir_p(repo_path)
      FileUtils.rm_rf(svn_repo_path)
      res, status = exec("svnadmin create \"#{svn_repo_path}\"")
      raise "Failed to initialize SVN repository: #{res}" unless status.success?
      res, status = exec("svn checkout \"#{repo_url}\" \"#{repo_path}\"")
      raise "Failed to checkout repository: #{res}" unless status.success?
      create_file_layout(repo_path, repo_content)
      commit_content
    end

    def commit_content(commit_message='commit message')
      Dir.chdir(repo_path) do
        res, status = exec('svn add *')
        res, status = exec("svn commit --quiet -m \"#{commit_message}\"") if status.success?
        raise "Failed to commit changes from #{branch}: #{res}" unless status.success?
      end
    end

    def commit_id(index_from_last=0)
      res = nil
      Dir.chdir(repo_path) do
        res, status = exec("svn log --quiet #{repo_url}")
        raise "Failed to retrieve commit revision #{index_from_last}: #{res}" unless status.success?
      end
      commit_id = res.split("\n")[ 1 + index_from_last * 2].split(' ').first
    end

  end
end
