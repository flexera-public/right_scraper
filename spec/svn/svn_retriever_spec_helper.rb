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

require File.expand_path(File.join(File.dirname(__FILE__), '..', 'retriever_spec_helper'))

require 'fileutils'

module RightScraper

  # SVN implementation of retriever spec helper
  # See parent class for methods headers comments
  class SvnRetrieverSpecHelper < RetrieverSpecHelper
    def svn_repo_path
      File.join(@tmpdir, "svn")
    end

    attr_reader :repo
    alias_method :repository, :repo

    def scraper_path
      File.join(@tmpdir, "scraper")
    end

    def repo_url
      file_prefix = 'file://'
      file_prefix += '/' if RUBY_PLATFORM =~ /mswin|mingw/
      url = "#{file_prefix}#{svn_repo_path}"
    end

    alias_method :repo_dir, :repo_path

    def initialize
      super()
      FileUtils.mkdir(svn_repo_path)
      @repo = RightScraper::Repositories::Base.from_hash(
                                                 :display_name => 'test repo',
                                                 :repo_type    => :svn,
                                                 :url          => repo_url)
      output = `svnadmin create #{svn_repo_path}`
      raise "Can't create repo: #{output}" unless $?.success?
      svn_client.execute('checkout', repo_url, repo_dir, '-r', 'HEAD')
      make_cookbooks
      commit_content
    end

    def svn_client
      @svn_client ||= ::RightScraper::Processes::SvnClient.new(
        repository,
        make_scraper_logger,
        ::RightScraper::Processes::Shell.new(
          :initial_directory => self.repo_dir))
    end

    def make_cookbooks
      create_cookbook(repo_dir, repo_content)
    end

    def delete(location, log = '')
      svn_client.execute('delete', location)
    end

    def commit_content(commit_message = 'commit message')
      svn_client.execute('add', Dir.glob(File.join(repo_dir, '**/*')))
      svn_client.execute("commit --message #{commit_message.inspect}")
    end

    def commit_id(index_from_last=0)
      lines = svn_client.output_for(
        'log', '-l', (index_from_last + 1).to_s, '-r', 'HEAD:0').lines
      id = nil
      lines.each do |line|
        if line =~ /^r(\d+)/
          id = $1
        end
      end
      id
    end
  end
end
