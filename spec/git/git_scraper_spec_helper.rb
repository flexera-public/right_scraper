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

  # Git implementation of scraper spec helper
  # See parent class for methods headers comments
  class GitScraperSpecHelper < ScraperSpecHelperBase

    def setup_test_repo
      FileUtils.rm_rf(repo_path)
      FileUtils.mkdir_p(repo_path)
      Dir.chdir(repo_path) do
        res, status = exec('git init')
        raise "Failed to initialize bare git repository: #{res}" unless status.success?
      end
      create_file_layout(repo_path, repo_content)
      commit_content(repo_path)
    end

    def commit_content(commit_message='commit')
      Dir.chdir(repo_path) do
        res, status = exec('git add .')
        res, status = exec("git commit --quiet -m \"#{commit_message}\"") if status.success?
        raise "Failed to commit changes from #{repo_path}: #{res}" unless status.success?
      end
    end

    def setup_branch(branch, new_content=nil)
      Dir.chdir(repo_path) do
        res, status = exec("git checkout -b #{branch}")
        raise "Failed to setup branch #{branch}: #{res}" unless status.success?
      end
      unless new_content.nil?
        create_file_layout(repo_path, new_content)
        commit_content("Branch #{branch}")
      end
    end

    def commit_id(index_from_last=0)
      res = nil
      Dir.chdir(repo_path) do
        res, status = exec("git log --format=%H -#{index_from_last + 1}")
        raise "Failed to retrieve commit sha #{index_from_last}: #{res}" unless status.success?
      end
      commit_id = res.split("\n").last
    end

  end
end
