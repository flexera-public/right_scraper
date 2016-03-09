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

require File.expand_path(File.join(File.dirname(__FILE__), 'retriever_spec_helper'))

require 'fileutils'
require 'set'

describe RightScraper::Retrievers::Git do
  include RightScraper::SpecHelpers::DevelopmentModeEnvironment

  include RightScraper::ScraperHelper
  include RightScraper::SpecHelpers

  def secondary_cookbook(where)
    FileUtils.mkdir_p(where)
    @helper.create_cookbook(where, @helper.repo_content)
  end

  def secondary_workflow(where, name=nil, definition=nil, metadata=nil)
    FileUtils.mkdir_p(where)
    @helper.create_workflow(where, name || 'workflow',
                            definition || "sequence\n  a\n  b",
                            metadata || {"random" => 42 })
  end

  def get_scraper(repo, basedir)
    @retriever = make_retriever(repo, basedir)
    @retriever.retrieve
    @scraper = make_scraper(@retriever)
  end

  before(:all) do
    @ignore = ['.git']
    @retriever_class = RightScraper::Retrievers::Git
  end

  context 'given a git repository' do
    before(:each) do
      @helper = RightScraper::GitRetrieverSpecHelper.new
      @repo = RightScraper::Repositories::Base.from_hash(
        :display_name => 'test repo',
        :repo_type    => :git,
        :url          => @helper.repo_path)
    end

    after(:each) do
      @helper.close unless @helper.nil?
      @helper = nil
    end

    context 'of workflows' do

      before(:each) do
        @helper.setup_workflows
      end

      context 'with one workflow' do
        include RightScraper::SpecHelpers::FromScratchScraping
        include RightScraper::SpecHelpers::WorkflowScraping

        it 'should scrape the master branch' do
          check_resource @scraper.next_resource,
            :position => 'workflow.def',
            :metadata => {},
            :manifest => {"workflow.def"=>"15ce480ea6c94b51056e028b0e0bd7da8024d924",
              "workflow.meta"=>"5f36b2ea290645ee34d943220a14b54ee5ea5be5"}
        end

        it 'should only see one workflow' do
          @scraper.next_resource.should_not == nil
          @scraper.next_resource.should == nil
        end

        it 'should record the head SHA' do
          tag = @scraper.next_resource.repository.tag
          tag.should_not == "master"
          tag.should =~ /^[A-Fa-f0-9]+$/
        end
      end

      context 'with a subworkflow' do
        before(:each) do
          subdir = File.join(@helper.repo_path, "workflow")
          secondary_workflow(subdir)
          @helper.commit_content("subworkflow added")
        end

        include RightScraper::SpecHelpers::FromScratchScraping
        include RightScraper::SpecHelpers::WorkflowScraping

        it 'should see two workflows' do
          @scraper.next_resource.should_not == nil
          @scraper.next_resource.should_not == nil
          @scraper.next_resource.should == nil
        end

        it 'should have the subworkflow in the manifest' do
          workflow = @scraper.next_resource
          workflow = @scraper.next_resource
          workflow.manifest["workflow.def"].should == "e687ad52d8fba8010a255e3c2a9e891264a24910"
          workflow.manifest["workflow.meta"].should == "58060413e90f84add5b2dace3ba7e30d2689336f"
        end
      end

      context 'with multiple workflows' do
        before(:each) do
          FileUtils.rm(File.join(@helper.repo_path, "workflow.meta"))
          @workflow_places = [File.join(@helper.repo_path, "workflows", "first"),
            File.join(@helper.repo_path, "workflows", "second"),
            File.join(@helper.repo_path, "other_random_place")]
          @workflow_places.each {|place| secondary_workflow(place)}
          @helper.commit_content("secondary workflows added")
        end

        include RightScraper::SpecHelpers::FromScratchScraping
        include RightScraper::SpecHelpers::WorkflowScraping

        it 'should scrape' do
          scraped = []
          while scrape = @scraper.next_resource
            place = (@workflow_places - scraped).detect {|place| File.join(@helper.repo_path, scrape.pos) == place}
            scraped << place
            check_resource scrape, :position => scrape.pos, 
              :metadata => {"random" => 42 },
              :manifest => {"workflow.def" =>"e687ad52d8fba8010a255e3c2a9e891264a24910",
                "workflow.meta"=>"58060413e90f84add5b2dace3ba7e30d2689336f"}
          end
          scraped.should have(@workflow_places.size).repositories
        end
      end

      context 'with two-level deep workflows' do
        before(:each) do
          @workflow_places = [File.join(@helper.repo_path, "workflows", "first"),
            File.join(@helper.repo_path, "workflows", "some_dir", "some_subdir", "second"),
            File.join(@helper.repo_path, "workflows", "some_dir", "some_subdir", "third")]
          @workflow_places.each {|place| secondary_workflow(place)}
          @helper.commit_content("secondary workflows added")
        end

        include RightScraper::SpecHelpers::FromScratchScraping
        include RightScraper::SpecHelpers::WorkflowScraping

        it 'should scrape' do
          @scraper.scrape
          @scraper.resources.each do |res|
            res.metadata_path.should_not be_nil
            res.definition_path.should_not be_nil
          end
          @scraper.resources.size.should == @workflow_places.size + 1 # One in the root repo_path
        end
      end

    end

    context 'of cookbooks' do

      before(:each) do
        @helper.setup_cookbooks
      end

      context 'with one cookbook' do
        include RightScraper::SpecHelpers::FromScratchScraping
        include RightScraper::SpecHelpers::CookbookScraping

        it 'should scrape the master branch' do
          check_resource @scraper.next_resource
        end

        it 'should only see one cookbook' do
          @scraper.next_resource.should_not == nil
          @scraper.next_resource.should == nil
        end

        it 'should record the head SHA' do
          tag = @scraper.next_resource.repository.tag
          tag.should_not == "master"
          tag.should =~ /^[A-Fa-f0-9]+$/
        end
      end

      context 'with a subcookbook' do
        before(:each) do
          @subdir = File.join(@helper.repo_path, "cookbook")
          secondary_cookbook(@subdir)
          @helper.commit_content("subcookbook added")
        end

        include RightScraper::SpecHelpers::FromScratchScraping
        include RightScraper::SpecHelpers::CookbookScraping

        it 'should still see only one cookbook' do
          @scraper.next_resource.should_not == nil
          @scraper.next_resource.should == nil
        end

        it 'should have the subcookbook in the manifest' do
          cookbook = @scraper.next_resource
          contents = ::File.read(::File.join(@subdir, "metadata.json"))
          cookbook.manifest["cookbook/metadata.json"].should ==  ::Digest::MD5.hexdigest(contents)
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
        include RightScraper::SpecHelpers::CookbookScraping

        it 'should scrape' do
          scraped = []
          while scrape = @scraper.next_resource
            place = (@cookbook_places - scraped).detect {|place| File.join(@helper.repo_path, scrape.pos) == place}
            scraped << place
            check_resource scrape, :position => scrape.pos
          end
          scraped.should have(@cookbook_places.size).repositories
        end

      end

      context 'and a branch' do
        before(:each) do
          @helper.setup_branch('test_branch', @helper.branch_content)
          @repo = RightScraper::Repositories::Base.from_hash(:display_name => 'test repo',
                                                             :repo_type    => :git,
                                                             :url          => @helper.repo_path,
                                                             :tag          => 'test_branch')
        end

        include RightScraper::SpecHelpers::FromScratchScraping
        include RightScraper::SpecHelpers::CookbookScraping

        it 'should scrape a branch' do
          check_resource @scraper.next_resource
        end
      end

      context 'and a branch and a tag that are named the same' do
        let(:branch_name) { 'test_branch' }

        before(:each) do
          @helper.setup_branch(branch_name)
          @helper.setup_tag(branch_name)
          @repo = RightScraper::Repositories::Base.from_hash(:display_name => 'test repo',
                                                             :repo_type    => :git,
                                                             :url          => @helper.repo_path,
                                                             :tag          => 'test_branch')
        end

        it 'should fail to scrape' do
          expect do
            @scraper = get_scraper(@repo, @helper.scraper_path)
            @scraper.next_resource
            @scraper.close
          end.to raise_exception(
            ::RightScraper::Retrievers::Base::RetrieverError,
            "Ambiguous name is both a remote branch and a tag: #{branch_name.inspect}")
        end
      end

      context 'and a tag' do
        before(:each) do
          @helper.setup_tag('test_tag')
          @repo = RightScraper::Repositories::Base.from_hash(:display_name => 'test repo',
                                                             :repo_type    => :git,
                                                             :url          => @helper.repo_path,
                                                             :tag          => 'test_tag')
        end

        include RightScraper::SpecHelpers::FromScratchScraping
        include RightScraper::SpecHelpers::CookbookScraping

        it 'should scrape a tag' do
          check_resource @scraper.next_resource
        end
      end

      context 'and a sha ref' do
        before(:each) do
          @oldmetadata = @helper.repo_content
          @helper.create_file_layout(@helper.repo_path, @helper.branch_content)
          @helper.commit_content
          @repo = RightScraper::Repositories::Base.from_hash(:display_name => 'test repo',
                                                             :repo_type    => :git,
                                                             :url          => @helper.repo_path,
                                                             :tag          => @helper.commit_id(1))
        end

        include RightScraper::SpecHelpers::FromScratchScraping
        include RightScraper::SpecHelpers::CookbookScraping

        it 'should scrape a sha' do
          check_resource @scraper.next_resource, :metadata => @oldmetadata, :rootdir => @scraper.send(:repo_dir)
        end
      end

      context 'and an incremental scraper' do

        def reset_scraper
          @olddir = @scraper.send(:repo_dir)
          @scraper.close
          @scraper = get_scraper(@repo, @helper.scraper_path)
        end

        before(:each) do
          @scraper = get_scraper(@repo, @helper.scraper_path)
        end

        after(:each) do
          @scraper.close if @scraper
          @scraper = nil
        end

        it 'the scraper should store intermediate versions where we expect' do
          @scraper.send(:repo_dir).should begin_with @helper.scraper_path
        end

        it 'the scraper should scrape' do
          check_resource @scraper.next_resource
        end

        it 'the scraper should only see one cookbook' do
          @scraper.next_resource.should_not == nil
          @scraper.next_resource.should == nil
        end

        context 'after the scraper runs once' do
          before(:each) do
            check_resource @scraper.next_resource
          end

          context 'and a branch is made on the master repo' do
            before(:each) do
              @helper.setup_branch("foo")
              @helper.create_file_layout(@helper.repo_path, ['fredbarney'])
              @helper.commit_content("branch")
              @helper.setup_branch("master")
            end

            it 'should be able to check the new branch out' do
              @repo.tag = "foo"
              reset_scraper
              @scraper.next_resource
              File.exists?(File.join(@retriever.repo_dir, 'fredbarney')).should be_true
            end
          end
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
                reset_scraper
                @scraper.next_resource
              end

              context 'and the branch is deleted' do
                before(:each) do
                  @helper.delete_branch("foo")
                end

                context 'a new scraper' do
                  before(:each) do
                    reset_scraper
                  end

                  it 'should not see any such branch exists' do
                    @helper.branch?("foo").should be_false
                  end
                end
              end
            end

            context 'a new scraper' do
              before(:each) do
                reset_scraper
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
              reset_scraper
            end

            context 'when an incompatible change is made to the master repo' do
              before(:each) do
                @scraper.next_resource
              end

              before(:each) do
                @helper.create_file_layout(@helper.repo_path, [{'other_branch_folder' => ['file7']}])
                @helper.commit_content("2nd change to master")
                @helper.force_rebase('master^', 'master^^^^^')
              end

              context 'a new scraper' do
                before(:each) do
                  reset_scraper
                end

                it 'should use the same directory for files' do
                  @olddir.should == @scraper.send(:repo_dir)
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
              @olddir.should == @scraper.send(:repo_dir)
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
              reset_scraper
            end

            it 'should use the same directory for files' do
              @olddir.should == @scraper.send(:repo_dir)
            end

            it 'should see the new change' do
              File.exists?(File.join(@olddir, 'branch_folder', 'bfile1')).should be_true
            end
          end
        end
      end
    end
  end

  context 'given a remote git repository requiring a credential' do
    before(:each) do
      @helper = RightScraper::GitRetrieverSpecHelper.new
      credential_file = File.expand_path(File.join(File.dirname(__FILE__), 'demokey'))
      credential = File.open(credential_file) { |f| f.read }
      @repo = RightScraper::Repositories::Base.from_hash(
        :display_name     => 'test repo',
        :repo_type        => :git,
        :url              => 'git@github.com:xeger/cookbooks_test_fixture.git',
        :first_credential => credential)
        @helper.setup_cookbooks
    end

    after(:each) do
      @helper.close unless @helper.nil?
      @helper = nil
    end

    include RightScraper::SpecHelpers::FromScratchScraping
    include RightScraper::SpecHelpers::CookbookScraping

    it 'should see a cookbook' do
      # note that this will make a request to Github with current user
      # credentials, which are normally available on CI.
      @scraper.next_resource.should_not be_nil
    end

    context :without_host_key_checking do
      before(:each) do
        @retriever = @retriever_class.new(
          @repo,
          :basedir => @helper.scraper_path,
          :logger  => make_scraper_logger)
      end


      it 'should override the git-SSH command' do
        ENV['GIT_SSH'] = nil
        @retriever.method(:without_host_key_checking).call do
          ENV['GIT_SSH'].should =~ /ssh/
          # Run the git-ssh command, make sure it invokes the SSH client
          `#{ENV['GIT_SSH']} -V 2>&1`.should =~ /OpenSSH_[0-9]+\.[0-9]+/
        end
      end

      it 'should clean up after itself' do
        ENV['GIT_SSH'] = 'banana'
        @retriever.method(:without_host_key_checking).call do
          ENV['GIT_SSH'].should =~ /ssh/
        end
        ENV['GIT_SSH'].should == 'banana'
      end
    end
  end
end
