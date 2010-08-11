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

require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))
require File.expand_path(File.join(File.dirname(__FILE__), 'svn_scraper_spec_helper'))
require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'lib', 'right_scraper'))
require 'set'

describe RightScale::SvnScraper do

  context 'given a SVN repository' do

    before(:each) do
      @helper = RightScale::SvnScraperSpecHelper.new
      @helper.setup_test_repo
      @scrape_dir = File.expand_path(File.join(File.dirname(__FILE__), '__scrape'))
      @scraper = RightScale::SvnScraper.new(@scrape_dir, max_bytes=1024**2, max_seconds=20)
      @repo = RightScale::Repository.from_hash(:display_name => 'test repo',
                                               :repo_type    => :svn,
                                               :url          => @helper.repo_url)
      FileUtils.rm_rf(RightScale::ScraperBase.repo_dir(@helper.repo_path, @repo))
    end
    
    after(:each) do
      @helper.delete_test_repo
      FileUtils.rm_rf(@helper.svn_repo_path)
      FileUtils.rm_rf(@scrape_dir)
    end

    it 'should scrape' do
      messages = []
      @scraper.scrape(@repo) { |m, progress| messages << m if progress }
      puts "\n **ERRORS: #{@scraper.errors.join("\n")}\n" unless @scraper.succeeded?
      @scraper.succeeded?.should be_true
      messages.size.should == 1
      File.directory?(@scraper.current_repo_dir).should be_true
      Set.new(@helper.extract_file_layout(@scraper.current_repo_dir, [ '.svn' ])).should ==
        Set.new(@helper.repo_content)
    end
    
    it 'should scrape incrementally' do
	  pending "File URLs comparison on Windows is tricky" if RUBY_PLATFORM=~/mswin/
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
      File.directory?(@scraper.current_repo_dir).should be_true
      Set.new(@helper.extract_file_layout(@scraper.current_repo_dir, [ '.svn' ])).should ==
        Set.new(@helper.repo_content + @helper.additional_content)
    end

    it 'should only scrape cookbooks directories' do
      messages = []
      @repo.cookbooks_path = [ 'folder1', File.join('folder2', 'folder3') ]
      @scraper.scrape(@repo) { |m, progress| messages << m if progress }
      puts "\n **ERRORS: #{@scraper.errors.join("\n")}\n" unless @scraper.succeeded?
      @scraper.succeeded?.should be_true
      messages.size.should == 1
      File.directory?(@scraper.current_repo_dir).should be_true
      @helper.extract_file_layout(@scraper.current_repo_dir, [ '.svn' ]).should == [ { 'folder1' => [ 'file2', 'file3' ] }, { 'folder2' => ['folder3' => [ 'file4' ] ] } ]
    end

    it 'should only scrape cookbooks directories incrementally' do
      pending "File URLs comparison on Windows is tricky" if RUBY_PLATFORM=~/mswin/
      @repo.cookbooks_path = [ 'folder1', File.join('folder2', 'folder3') ]
      @scraper.scrape(@repo)
      puts "\n **ERRORS: #{@scraper.errors.join("\n")}\n" unless @scraper.succeeded?
      @scraper.incremental_update?.should be_true
      messages = []
      @scraper.scrape(@repo) { |m, progress| messages << m if progress }
      puts "\n **ERRORS: #{@scraper.errors.join("\n")}\n" unless @scraper.succeeded?
      @scraper.succeeded?.should be_true
      messages.size.should == 1
      File.directory?(@scraper.current_repo_dir).should be_true
      @helper.extract_file_layout(@scraper.current_repo_dir, [ '.svn' ]).should == [ { 'folder1' => [ 'file2', 'file3' ] }, { 'folder2' => ['folder3' => [ 'file4' ] ] } ]
    end

    context 'and a revision' do

      before(:each) do
        @helper.create_file_layout(@helper.repo_path, @helper.branch_content)
        @helper.commit_content
        @rev_repo = RightScale::Repository.from_hash(:display_name => 'test repo',
                                                     :repo_type    => :svn,
                                                     :url          => @helper.repo_url,
                                                     :tag          => @helper.commit_id(1))
      end

      it 'should scrape a revision' do
        messages = []
        @scraper.scrape(@rev_repo) { |m, progress| messages << m if progress }
        puts "\n **ERRORS: #{@scraper.errors.join("\n")}\n" unless @scraper.succeeded?
        @scraper.succeeded?.should be_true
        messages.size.should == 1
        File.directory?(@scraper.current_repo_dir).should be_true
        Set.new(@helper.extract_file_layout(@scraper.current_repo_dir, [ '.svn' ])).should ==
          Set.new(@helper.repo_content)
      end

      it 'should scrape a revision incrementally' do
        @scraper.scrape(@rev_repo)
        puts "\n **ERRORS: #{@scraper.errors.join("\n")}\n" unless @scraper.succeeded?
        @scraper.incremental_update?.should be_true
        @helper.create_file_layout(@helper.repo_path, @helper.additional_content)
        @helper.commit_content
        messages = []
        @scraper.scrape(@rev_repo) { |m, progress| messages << m if progress }
        puts "\n **ERRORS: #{@scraper.errors.join("\n")}\n" unless @scraper.succeeded?
        @scraper.succeeded?.should be_true
        messages.size.should == 1
        @scraper.instance_variable_get(:@incremental).should == true
        File.directory?(@scraper.current_repo_dir).should be_true
        Set.new(@helper.extract_file_layout(@scraper.current_repo_dir, [ '.svn' ])).should ==
          Set.new(@helper.repo_content)
      end

    end
  end

end
