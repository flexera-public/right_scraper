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

require 'stringio'
require File.expand_path(File.join(File.dirname(__FILE__), 'spec_helper'))
require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'right_scraper_base', 'spec', 'full_scraper_helper'))
require File.expand_path(File.join(File.dirname(__FILE__), 'git_scraper_spec_helper'))
require 'tmpdir'
require 'flexmock'

describe RightScraper::Scraper do
  include RightScraper::SpecHelpers::DevelopmentModeEnvironment

  include RightScraper::FullScraperHelpers

  before(:each) do
    @stream = StringIO.new()
    @tmpdir = Dir.mktmpdir
    @scraper = RightScraper::Scraper.new(@tmpdir)
  end

  after(:each) do
    FileUtils.remove_entry_secure @tmpdir
  end

  it 'starts out successful' do
    @scraper.succeeded?.should be_true
    @scraper.errors.should == []
  end

  context 'given a Git repository' do
    before(:each) do
      @helper = RightScraper::GitScraperSpecHelper.new
      @repo = @helper.repo
    end

    after(:each) do
      @helper.close
    end

    it_should_behave_like "a normal repository"

    it 'should log correctly as it scrapes' do
      callback = flexmock("callback")
      callback.should_receive(:call).with(:begin, :scraping, "from git #{@repo.url}", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:begin, :checkout, "", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:begin, :cloning, "to #{@tmpdir}/#{@repo.repository_hash}", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:commit, :cloning, "to #{@tmpdir}/#{@repo.repository_hash}", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:begin, :fetch, "", nil).once
      callback.should_receive(:call).with(:commit, :fetch, "", nil).once
      callback.should_receive(:call).with(:begin, :checkout_revision, "", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:commit, :checkout_revision, "", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:commit, :checkout, "", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:begin, :initialize, "setting up in #{@tmpdir}/#{@repo.repository_hash}", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:begin, :finding_next_cookbook, "in #{@tmpdir}/#{@repo.repository_hash}/", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:begin, :reading_cookbook, "from #{@tmpdir}/#{@repo.repository_hash}/", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:begin, :scanning_filesystem, "rooted at #{@tmpdir}/#{@repo.repository_hash}/", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:begin, :metadata_parsing, "", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:commit, :metadata_parsing, "", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:commit, :scanning_filesystem, "rooted at #{@tmpdir}/#{@repo.repository_hash}/", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:commit, :reading_cookbook, "from #{@tmpdir}/#{@repo.repository_hash}/", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:commit, :finding_next_cookbook, "in #{@tmpdir}/#{@repo.repository_hash}/", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:commit, :initialize, "setting up in #{@tmpdir}/#{@repo.repository_hash}", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:begin, :next, "", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:begin, :searching, "", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:commit, :searching, "", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:commit, :next, "", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:begin, :next, "", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:commit, :next, "", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:commit, :scraping, "from git #{@repo.url}", nil).at_least.once.at_most.once
      @scraper.scrape(@repo) do |phase, operation, explanation, exception|
        callback.call(phase, operation, explanation, exception)
      end
      @scraper.succeeded?.should be_true
    end

    context 'with tag being an empty string' do
      before(:each) do
        @repo.tag = ""
      end

      it_should_behave_like "a normal repository"
    end

    context 'with some additional commits' do
      before(:each) do
        @helper.create_file_layout(@helper.repo_path, @helper.branch_content)
        @helper.commit_content("change to master")
      end

      context 'after a successful scraper run' do
        before(:each) do
          @scraper.scrape(@repo)
          @scraper.succeeded?.should be_true
        end

        context 'with some incompatible changes' do
          before(:each) do
            @helper.create_file_layout(@helper.repo_path, [{'other_branch_folder' => ['file7']}])
            @helper.commit_content("2nd change to master")
            @helper.force_rebase('master^', 'master^^')
          end

          it 'should still be successful' do
            @scraper.scrape(@repo)
            @scraper.errors.should == []
            @scraper.succeeded?.should be_true
          end
        end
      end
    end
  end
end
