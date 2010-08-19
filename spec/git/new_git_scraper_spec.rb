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
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'new_scraper_helper'))
require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'lib', 'right_scraper'))
require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'lib', 'right_scraper', 'scrapers', 'git'))
require 'set'
require 'libarchive_ruby'

describe RightScale::NewGitScraper do
  include RightScale::ScraperHelper

  SCRAPERCLASS = RightScale::NewGitScraper
  IGNORE = ['.git']

  context 'given a git repository' do
    before(:each) do
      @helper = RightScale::GitScraperSpecHelper.new
      @repo = RightScale::Repository.from_hash(:display_name => 'test repo',
                                               :repo_type    => :git,
                                               :url          => @helper.repo_path)
    end

    after(:each) do
      @helper.close unless @helper.nil?
      @helper = nil
    end

    context 'with one cookbook' do
      it_should_behave_like "From-scratch scraping"

      it 'should scrape the master branch' do
        check_cookbook @scraper.next
      end

      it 'should only see one cookbook' do
        @scraper.next.should_not == nil
        @scraper.next.should == nil
      end
    end

    context 'with multiple cookbooks' do
      def secondary_cookbook(where)
        FileUtils.mkdir_p(where)
        @helper.create_cookbook(where, @helper.repo_content)
      end

      before(:each) do
        FileUtils.rm(File.join(@helper.repo_path, "metadata.json"))
        @cookbook_places = [File.join(@helper.repo_path, "cookbooks", "first"),
                            File.join(@helper.repo_path, "cookbooks", "second"),
                            File.join(@helper.repo_path, "other_random_place")]
        @cookbook_places.each {|place| secondary_cookbook(place)}
        @helper.commit_content("secondary cookbooks added")
      end

      it_should_behave_like "From-scratch scraping"

      it 'should scrape' do
        @cookbook_places.each do |place|
          check_cookbook @scraper.next, :position => place[@helper.repo_path.length+1..-1]
        end
      end

      it 'should be able to seek' do
        @scraper.seek "cookbooks/second"
        check_cookbook @scraper.next, :position => "cookbooks/second"
        check_cookbook @scraper.next, :position => "other_random_place"
      end
    end

    context 'and a branch' do
      before(:each) do
        @helper.setup_branch('test_branch', @helper.branch_content)
        @repo = RightScale::Repository.from_hash(:display_name => 'test repo',
                                                 :repo_type    => :git,
                                                 :url          => @helper.repo_path,
                                                 :tag          => 'test_branch')
      end

      it_should_behave_like "From-scratch scraping"

      it 'should scrape a branch' do
        check_cookbook @scraper.next
      end
    end

    context 'and a sha ref' do
      before(:each) do
        @oldmetadata = @helper.repo_content
        @helper.create_file_layout(@helper.repo_path, @helper.branch_content)
        @helper.commit_content
        @repo = RightScale::Repository.from_hash(:display_name => 'test repo',
                                                 :repo_type    => :git,
                                                 :url          => @helper.repo_path,
                                                 :tag          => @helper.commit_id(1))
      end

      it_should_behave_like "From-scratch scraping"

      it 'should scrape a sha' do
        check_cookbook @scraper.next, :metadata => @oldmetadata, :rootdir => @scraper.checkout_path
      end
    end

    context 'and an incremental scraper' do
      before(:each) do
        @scraper = RightScale::NewGitScraper.new(@repo,
                                                 :directory => @helper.scraper_path,
                                                 :max_bytes => 1024**2,
                                                 :max_seconds => 20)
      end

      after(:each) do
        @scraper.close
        @scraper = nil
      end

      it 'the scraper should store intermediate versions where we expect' do
        @scraper.checkout_path.should begin_with @helper.scraper_path
      end

      it 'the scraper should scrape' do
        check_cookbook @scraper.next
      end

      it 'the scraper should only see one cookbook' do
        @scraper.next.should_not == nil
        @scraper.next.should == nil
      end

      context 'when a change is made to the master repo' do
        before(:each) do
          @helper.create_file_layout(@helper.repo_path, @helper.branch_content)
          @helper.commit_content
        end

        context 'a new scraper' do
          before(:each) do
            @olddir = @scraper.checkout_path
            @scraper.close
            @scraper = RightScale::NewGitScraper.new(@repo,
                                                     :directory => @helper.scraper_path,
                                                     :max_bytes => 1024**2,
                                                     :max_seconds => 20)
          end

          it 'should use the same directory for files' do
            @olddir.should == @scraper.checkout_path
          end

          it 'should see the new change' do
            File.exists?(File.join(@olddir, 'branch_folder', 'bfile1')).should be_true
          end
        end
      end
    end
  end
end
