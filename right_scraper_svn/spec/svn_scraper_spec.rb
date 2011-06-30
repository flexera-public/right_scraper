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

require File.expand_path(File.join(File.dirname(__FILE__), 'spec_helper'))
require File.expand_path(File.join(File.dirname(__FILE__), 'svn_scraper_spec_helper'))
require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'right_scraper_base', 'spec', 'scraper_helper'))
require 'set'

describe RightScraper::Scrapers::Svn do
  include RightScraper::SpecHelpers::DevelopmentModeEnvironment

  include RightScraper::ScraperHelper

  before(:all) do
    @scraperclass = RightScraper::Scrapers::Svn
    @ignore = ['.svn']
  end

  context 'given a remote SVN repository' do
    before(:each) do
      pending "Not run unless REMOTE_USER and REMOTE_PASSWORD set" unless ENV['REMOTE_USER'] && ENV['REMOTE_PASSWORD']
      url = 'https://wush.net/svn/rightscale/cookbooks_test/'
      @repo = RightScraper::Repository.from_hash(:display_name => 'wush',
                                               :repo_type    => :svn,
                                               :url          => url,
                                               :first_credential => ENV['REMOTE_USER'],
                                               :second_credential => ENV['REMOTE_PASSWORD'])
      @scraper = @scraperclass.new(@repo, :max_bytes => 1024**2,
                                   :max_seconds => 20)
    end

    def reopen_scraper
      @scraper.close
      @scraper = @scraperclass.new(@repo, :max_bytes => 1024**2,
                                   :max_seconds => 20)
    end

    after(:each) do
      @scraper.close if @scraper
    end

    it 'should scrape' do
      first = @scraper.next
      first.should_not == nil
    end

    # quick_start not actually being a cookbook
    it 'should scrape 5 repositories' do
      locations = Set.new
      (1..5).each {|n|
        cookbook = @scraper.next
        locations << cookbook.pos
        cookbook.should_not == nil
      }
      @scraper.next.should == nil
      locations.should == Set.new(["cookbooks/app_rails",
                                   "cookbooks/db_mysql",
                                   "cookbooks/repo_git",
                                   "cookbooks/rs_utils",
                                   "cookbooks/web_apache"])
    end
  end

  context 'given a SVN repository' do
    before(:each) do
      @helper = RightScraper::SvnScraperSpecHelper.new
      @repo = @helper.repo
    end

    after(:each) do
      @helper.close unless @helper.nil?
      @helper = nil
    end

    context 'with one cookbook' do
      include RightScraper::SpecHelpers::FromScratchScraping

      it 'should scrape the master branch' do
        check_cookbook @scraper.next
      end

      it 'should only see one cookbook' do
        @scraper.next.should_not == nil
        @scraper.next.should == nil
      end

      it 'should record the head SHA' do
        tag = @scraper.next.repository.tag
        tag.should_not == "master"
        tag.should =~ /^[0-9]+$/
      end
    end

    context 'with multiple cookbooks' do
      def secondary_cookbook(where)
        FileUtils.mkdir_p(where)
        @helper.create_cookbook(where, @helper.repo_content)
      end

      before(:each) do
        @helper.delete(File.join(@helper.repo_path, "metadata.json"))
        @cookbook_places = [File.join(@helper.repo_path, "cookbooks", "first"),
                            File.join(@helper.repo_path, "cookbooks", "second"),
                            File.join(@helper.repo_path, "other_random_place")]
        @cookbook_places.each {|place| secondary_cookbook(place)}
        @helper.commit_content("secondary cookbooks added")
      end

      include RightScraper::SpecHelpers::FromScratchScraping

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

    context 'and a revision' do
      before(:each) do
        @oldmetadata = @helper.repo_content
        @helper.create_file_layout(@helper.repo_path, @helper.branch_content)
        @helper.commit_content('added branch content')
        @repo.tag = @helper.commit_id(1).to_s
      end

      include RightScraper::SpecHelpers::FromScratchScraping

      it 'should scrape a revision' do
        check_cookbook @scraper.next, :metadata => @oldmetadata, :rootdir => @scraper.basedir
      end
    end

    context 'and an incremental scraper' do
      before(:each) do
        @scraper = @scraperclass.new(@repo,
                                     :directory => @helper.scraper_path,
                                     :max_bytes => 1024**2,
                                     :max_seconds => 20)
      end

      after(:each) do
        @scraper.close
        @scraper = nil
      end

      it 'the scraper should store intermediate versions where we expect' do
        @scraper.basedir.should begin_with @helper.scraper_path
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
            @olddir = @scraper.basedir
            @scraper.close
            @scraper = @scraperclass.new(@repo,
                                         :directory => @helper.scraper_path,
                                         :max_bytes => 1024**2,
                                         :max_seconds => 20)
          end

          it 'should use the same directory for files' do
            @olddir.should == @scraper.basedir
          end

          it 'should see the new change' do
            File.exists?(File.join(@olddir, 'branch_folder', 'bfile1')).should be_true
          end
        end
      end

      context 'when a textual change is made to the master repo' do
        before(:each) do
          File.open(File.join(@helper.repo_path, "file1"), 'w') do |f|
            f.puts "bar"
          end
          @helper.commit_content("appended bar")
          File.open(File.join(@helper.repo_path, "file1"), 'a+') do |f|
            f.puts "bar"
          end
          @helper.commit_content("appended bar again")
          File.open(File.join(@helper.repo_path, "file1"), 'a+') do |f|
            f.puts "bar"
          end
          @helper.commit_content("appended bar again^2")
          File.open(File.join(@helper.repo_path, "file1"), 'a+') do |f|
            f.puts "bar"
          end
          @helper.commit_content("appended bar again^3")
        end

        context 'a new scraper' do
          before(:each) do
            @olddir = @scraper.basedir
            @scraper.close
            @scraper = @scraperclass.new(@repo,
                                         :directory => @helper.scraper_path,
                                         :max_bytes => 1024**2,
                                         :max_seconds => 20)
          end

          it 'should notice the new revision' do
            cookbook = @scraper.next
            cookbook.repository.tag.should == "5"
          end

          it 'should see the new change' do
            File.open(File.join(@olddir, 'file1')).read.should == "bar\n" * 4
          end
        end
      end
    end
  end
end
