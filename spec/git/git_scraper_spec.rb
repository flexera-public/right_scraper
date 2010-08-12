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

require File.expand_path(File.join(File.dirname(__FILE__), 'git_scraper_spec_helper'))
require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'lib', 'right_scraper'))
require 'set'

describe RightScale::GitScraper do

  context 'given a git repository' do

    before(:each) do
      @helper = RightScale::GitScraperSpecHelper.new
      @helper.setup_test_repo
      @scrape_dir = File.expand_path(File.join(File.dirname(__FILE__), '__scrape'))
      @scraper = RightScale::GitScraper.new(@scrape_dir, max_bytes=1024**2, max_seconds=20)
      @repo = RightScale::Repository.from_hash(:display_name => 'test repo',
                                               :repo_type    => :git,
                                               :url          => @helper.repo_path)
      @current_repo_dir = RightScale::ScraperBase.repo_dir(@scrape_dir, @repo)
      FileUtils.rm_rf(@current_repo_dir)
    end
    
    after(:each) do
      @helper.delete_test_repo
      FileUtils.rm_rf(@scrape_dir)
    end

    it 'should scrape the master branch' do
      messages = []
      @scraper.instance_variable_set(:@current_repo_dir, @current_repo_dir)
      @scraper.incremental_update?.should be_false
      @scraper.scrape(@repo) { |m, progress| messages << m if progress }
      puts "\n **ERRORS: #{@scraper.errors.join("\n")}\n" unless @scraper.succeeded?
      @scraper.succeeded?.should be_true
      messages.size.should == 1
      File.directory?(@scraper.current_repo_dir).should be_true
      Set.new(@helper.extract_file_layout(@scraper.current_repo_dir, [ '.git', '.ssh', 'metadata.json' ])).should ==
        Set.new(@helper.repo_content)
    end
    
    it 'should scrape the master branch incrementally' do
      @scraper.scrape(@repo)
      puts "\n **ERRORS: #{@scraper.errors.join("\n")}\n" unless @scraper.succeeded?
      @scraper.incremental_update?.should be_true
      @helper.create_file_layout(@helper.repo_path, @helper.additional_content)
      @helper.commit_content
      messages = []
      @scraper.scrape(@repo) { |m, progress| messages << m if progress }
      puts "\n **ERRORS: #{@scraper.errors.join("\n")}\n" unless @scraper.succeeded?
      @scraper.succeeded?.should be_true
      messages.size.should == 1
      @scraper.instance_variable_get(:@incremental).should == true
      File.directory?(@scraper.current_repo_dir).should be_true
      Set.new(@helper.extract_file_layout(@scraper.current_repo_dir, [ '.git', '.ssh', 'metadata.json' ])).should ==
        Set.new(@helper.repo_content + @helper.additional_content)
    end

    context 'and a branch' do

      before(:each) do
        @helper.setup_branch('test_branch', @helper.branch_content)
        @branch_repo = RightScale::Repository.from_hash(:display_name => 'test repo',
                                                        :repo_type    => :git,
                                                        :url          => @helper.repo_path,
                                                        :tag          => 'test_branch')
      end

      it 'should scrape a branch' do
        messages = []
        @scraper.scrape(@branch_repo) { |m, progress| messages << m if progress }
        puts "\n **ERRORS: #{@scraper.errors.join("\n")}\n" unless @scraper.succeeded?
        @scraper.succeeded?.should be_true
        messages.size.should == 1
        File.directory?(@scraper.current_repo_dir).should be_true
        Set.new(@helper.extract_file_layout(@scraper.current_repo_dir, [ '.git', '.ssh', 'metadata.json' ])).should ==
          Set.new((@helper.repo_content + @helper.branch_content))
      end

      it 'should scrape a branch incrementally' do
        @scraper.scrape(@branch_repo)
        puts "\n **ERRORS: #{@scraper.errors.join("\n")}\n" unless @scraper.succeeded?
        @scraper.incremental_update?.should be_true
        @helper.create_file_layout(@helper.repo_path, @helper.additional_content)
        @helper.commit_content
        messages = []
        @scraper.scrape(@branch_repo) { |m, progress| messages << m if progress }
        puts "\n **ERRORS: #{@scraper.errors.join("\n")}\n" unless @scraper.succeeded?
        @scraper.succeeded?.should be_true
        messages.size.should == 1
        @scraper.instance_variable_get(:@incremental).should == true
        File.directory?(@scraper.current_repo_dir).should be_true
        Set.new(@helper.extract_file_layout(@scraper.current_repo_dir, [ '.git', '.ssh', 'metadata.json' ])).should ==
          Set.new((@helper.repo_content + @helper.branch_content + @helper.additional_content))
      end

    end

    context 'and a sha ref' do

      before(:each) do
        @helper.create_file_layout(@helper.repo_path, @helper.branch_content)
        @helper.commit_content
        @sha_repo = RightScale::Repository.from_hash(:display_name => 'test repo',
                                                     :repo_type    => :git,
                                                     :url          => @helper.repo_path,
                                                     :tag          => @helper.commit_id(1))
      end

      it 'should scrape a sha' do
        messages = []
        @scraper.scrape(@sha_repo) { |m, progress| messages << m if progress }
        puts "\n **ERRORS: #{@scraper.errors.join("\n")}\n" unless @scraper.succeeded?
        @scraper.succeeded?.should be_true
        messages.size.should == 1
        File.directory?(@scraper.current_repo_dir).should be_true
        Set.new(@helper.extract_file_layout(@scraper.current_repo_dir, [ '.git', '.ssh', 'metadata.json' ])).should ==
          Set.new(@helper.repo_content)
      end

      it 'should scrape a sha incrementally' do
        @scraper.scrape(@sha_repo)
        puts "\n **ERRORS: #{@scraper.errors.join("\n")}\n" unless @scraper.succeeded?
        @scraper.incremental_update?.should be_true
        @helper.create_file_layout(@helper.repo_path, @helper.additional_content)
        @helper.commit_content
        messages = []
        @scraper.scrape(@sha_repo) { |m, progress| messages << m if progress }
        puts "\n **ERRORS: #{@scraper.errors.join("\n")}\n" unless @scraper.succeeded?
        @scraper.succeeded?.should be_true
        messages.size.should == 1
        @scraper.instance_variable_get(:@incremental).should == true
        File.directory?(@scraper.current_repo_dir).should be_true
        Set.new(@helper.extract_file_layout(@scraper.current_repo_dir, [ '.git', '.ssh', 'metadata.json' ])).should ==
          Set.new(@helper.repo_content)
      end

    end

  end

end
