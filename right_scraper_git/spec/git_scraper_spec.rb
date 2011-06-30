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
require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'right_scraper_base', 'spec', 'scraper_helper'))
require 'set'
require 'libarchive_ruby'

describe RightScraper::Scrapers::Git do
  include RightScraper::SpecHelpers::DevelopmentModeEnvironment

  include RightScraper::ScraperHelper

  def secondary_cookbook(where)
    FileUtils.mkdir_p(where)
    @helper.create_cookbook(where, @helper.repo_content)
  end

  before(:all) do
    @scraperclass = RightScraper::Scrapers::Git
    @ignore = ['.git']
  end

  context 'given a git repository' do
    before(:each) do
      @helper = RightScraper::GitScraperSpecHelper.new
      @repo = RightScraper::Repository.from_hash(:display_name => 'test repo',
                                               :repo_type    => :git,
                                               :url          => @helper.repo_path)
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
        tag.should =~ /^[A-Fa-f0-9]+$/
      end
    end

    context 'with a subcookbook' do
      before(:each) do
        subdir = File.join(@helper.repo_path, "cookbook")
        secondary_cookbook(subdir)
        @helper.commit_content("subcookbook added")
      end

      include RightScraper::SpecHelpers::FromScratchScraping

      it 'should still see only one cookbook' do
        @scraper.next.should_not == nil
        @scraper.next.should == nil
      end

      it 'should have the subcookbook in the manifest' do
        cookbook = @scraper.next
        cookbook.manifest["cookbook/metadata.json"].should == "c2901d21c81ba5a152a37a5cfae35a8e092f7b39"
      end
    end

    context 'with multiple cookbooks' do
      before(:each) do
        FileUtils.rm(File.join(@helper.repo_path, "metadata.json"))
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

    context 'and a branch' do
      before(:each) do
        @helper.setup_branch('test_branch', @helper.branch_content)
        @repo = RightScraper::Repository.from_hash(:display_name => 'test repo',
                                                 :repo_type    => :git,
                                                 :url          => @helper.repo_path,
                                                 :tag          => 'test_branch')
      end

      include RightScraper::SpecHelpers::FromScratchScraping

      it 'should scrape a branch' do
        check_cookbook @scraper.next
      end
    end

    context 'and a branch and a tag that are named the same' do
      before(:each) do
        @helper.setup_branch('test_branch')
        @helper.setup_tag('test_branch')
        @repo = RightScraper::Repository.from_hash(:display_name => 'test repo',
                                                 :repo_type    => :git,
                                                 :url          => @helper.repo_path,
                                                 :tag          => 'test_branch')
      end

      it 'should fail to scrape' do
        lambda {
          @scraper = @scraperclass.new(@repo)
          @scraper.next
          @scraper.close
        }.should raise_exception(/Ambiguous reference/)
      end
    end

    context 'and a tag' do
      before(:each) do
        @helper.setup_tag('test_tag')
        @repo = RightScraper::Repository.from_hash(:display_name => 'test repo',
                                                 :repo_type    => :git,
                                                 :url          => @helper.repo_path,
                                                 :tag          => 'test_tag')
      end

      include RightScraper::SpecHelpers::FromScratchScraping

      it 'should scrape a tag' do
        check_cookbook @scraper.next
      end
    end

    context 'and a sha ref' do
      before(:each) do
        @oldmetadata = @helper.repo_content
        @helper.create_file_layout(@helper.repo_path, @helper.branch_content)
        @helper.commit_content
        @repo = RightScraper::Repository.from_hash(:display_name => 'test repo',
                                                 :repo_type    => :git,
                                                 :url          => @helper.repo_path,
                                                 :tag          => @helper.commit_id(1))
      end

      include RightScraper::SpecHelpers::FromScratchScraping

      it 'should scrape a sha' do
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
          @helper.commit_content("change to master")
          @helper.create_file_layout(@helper.repo_path, ['frob'])
          @helper.commit_content("alpha")
          @helper.create_file_layout(@helper.repo_path, ['botz'])
          @helper.commit_content("beta")
          @helper.create_file_layout(@helper.repo_path, ['fred'])
          @helper.commit_content("delta")
          @helper.create_file_layout(@helper.repo_path, ['barney'])
          @helper.commit_content("gamma")
        end

        context 'when a branch is made on the master repo' do
          before(:each) do
            @helper.setup_branch("foo")
            @helper.create_file_layout(@helper.repo_path, ['fredbarney'])
            @helper.commit_content("branch")
            @helper.setup_branch("master")
          end

          context 'and a scrape happens' do
            before(:each) do
              @olddir = @scraper.basedir
              @scraper.close
              @scraper = @scraperclass.new(@repo,
                                           :directory => @helper.scraper_path,
                                           :max_bytes => 1024**2,
                                           :max_seconds => 20)
              @scraper.next
            end

            context 'and the branch is deleted' do
              before(:each) do
                @helper.delete_branch("foo")
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

                it 'should not see any such branch exists' do
                  @helper.branch?("foo").should be_false
                end
              end
            end
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

            it 'should not see the new change' do
              File.exists?(File.join(@olddir, 'fredbarney')).should be_false
            end

            it 'should note that the branch exists' do
              @helper.branch?("foo").should be_true
            end
          end
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

          context 'when an incompatible change is made to the master repo' do
            before(:each) do
              @scraper.next
            end

            before(:each) do
              @helper.create_file_layout(@helper.repo_path, [{'other_branch_folder' => ['file7']}])
              @helper.commit_content("2nd change to master")
              @helper.force_rebase('master^', 'master^^^^^')
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
                File.exists?(File.join(@olddir, 'other_branch_folder', 'file7')).should be_true
              end

              it 'should not see the middle change' do
                File.exists?(File.join(@olddir, 'frob')).should_not be_true
              end
            end
          end

          it 'should use the same directory for files' do
            @olddir.should == @scraper.basedir
          end

          it 'should see the new change' do
            File.exists?(File.join(@olddir, 'branch_folder', 'bfile1')).should be_true
          end
        end

        context 'with tag being an empty string' do
          before(:each) do
            @repo.tag = ""
          end

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
    end
  end

  context 'given a remote git repository requiring a credential' do
    before(:each) do
      pending "Don't annoy GitHub unless ANNOY_GITHUB is set" unless ENV['ANNOY_GITHUB']
      @helper = RightScraper::GitScraperSpecHelper.new
      credential_file = File.expand_path(File.join(File.dirname(__FILE__), 'demokey'))
      credential = File.open(credential_file) { |f| f.read }
      @repo = RightScraper::Repository.from_hash(:display_name     => 'test repo',
                                               :repo_type        => :git,
                                               :url              => 'git@github.com:rightscale-test-account/cookbooks.git',
                                               :first_credential => credential)
    end

    after(:each) do
      @helper.close unless @helper.nil?
      @helper = nil
    end

    include RightScraper::SpecHelpers::FromScratchScraping

    it 'should see a cookbook' do
      @scraper.next.should_not be_nil
    end
  end
end
