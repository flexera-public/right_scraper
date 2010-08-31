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
require File.expand_path(File.join(File.dirname(__FILE__), 'download', 'download_scraper_spec_helper'))
require File.expand_path(File.join(File.dirname(__FILE__), 'git', 'git_scraper_spec_helper'))
require File.expand_path(File.join(File.dirname(__FILE__), 'svn', 'svn_scraper_spec_helper'))
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib', 'right_scraper'))
require 'tmpdir'
require 'flexmock'

describe RightScale::Scraper do
  before(:each) do
    @stream = StringIO.new()
    @tmpdir = Dir.mktmpdir
    @scraper = RightScale::Scraper.new(@tmpdir)
  end

  after(:each) do
    FileUtils.remove_entry_secure @tmpdir
  end

  it 'starts out successful' do
    @scraper.succeeded?.should be_true
    @scraper.errors.should == []
  end

  context 'given an illegal download repository' do
    before(:each) do
      @repo = RightScale::Repository.from_hash(:display_name => 'illegal repo',
                                               :repo_type    => :download,
                                               :url          => "http://example.com/foo")
    end

    it 'should not throw an exception, but still fail to scrape' do
      @scraper.scrape(@repo)
      @scraper.succeeded?.should be_false
      @scraper.errors.size.should == 1
      exception, activity, explanation = @scraper.errors[0]
      exception.should be_an_instance_of(RuntimeError)
      activity.should == :downloading
      explanation.should == ""
    end

    it 'should call the callback appropriately' do
      callback = flexmock("callback")
      callback.should_receive(:call).with(:begin, :scraping, "from download #{@repo.url}", nil).once
      callback.should_receive(:call).with(:begin, :downloading, "", nil).once
      callback.should_receive(:call).with(:abort, :downloading, "", RuntimeError).once
      callback.should_receive(:call).with(:abort, :scraping, "from download #{@repo.url}", RuntimeError).once
      @scraper.scrape(@repo, true) do |phase, operation, explanation, exception|
        callback.call(phase, operation, explanation, exception)
      end
    end
  end

  shared_examples_for "Normal repository contents" do
    it 'should scrape' do
      @scraper.scrape(@repo)
      @scraper.succeeded?.should be_true
      @scraper.cookbooks.should_not == []
      @scraper.cookbooks.size.should == 1
      @scraper.cookbooks[0].data.should_not have_key(:archive)
      @scraper.cookbooks[0].manifest.should == {
        "folder1/file3"=>"1eb2267bae4e47cab81f8866bbc7e06764ea9be0",
        "file1"=>"38be7d1b981f2fb6a4a0a052453f887373dc1fe8",
        "folder2/folder3/file4"=>"a441d6d72884e442ef02692864eee99b4ad933f5",
        "metadata.json"=>"c2901d21c81ba5a152a37a5cfae35a8e092f7b39",
        "folder1/file2"=>"639daad06642a8eb86821ff7649e86f5f59c6139"}
      @scraper.cookbooks[0].metadata.should == [{"folder1"=>["file2", "file3"]},
                                                {"folder2"=>[{"folder3"=>["file4"]}]},
                                                "file1"]
    end
  end

  context 'given a legal download repository' do
    before(:each) do
      @helper = RightScale::DownloadScraperSpecHelper.new
      @repo = @helper.repo
    end

    after(:each) do
      @helper.close
    end

    it_should_behave_like "Normal repository contents"

    it 'should log correctly as it scrapes' do
      callback = flexmock("callback")
      callback.should_receive(:call).with(:begin, :scraping, "from download #{@repo.url}", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:begin, :downloading, "", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:begin, :reading_metadata, "", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:begin, :metadata_parsing, "", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:commit, :metadata_parsing, "", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:commit, :reading_metadata, "", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:commit, :downloading, "", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:commit, :scraping, "from download #{@repo.url}", nil).at_least.once.at_most.once
      @scraper.scrape(@repo) do |phase, operation, explanation, exception|
        callback.call(phase, operation, explanation, exception)
      end
      @scraper.succeeded?.should be_true
    end
  end

  context 'given a Git repository' do
    before(:each) do
      @helper = RightScale::GitScraperSpecHelper.new
      @repo = @helper.repo
    end

    after(:each) do
      @helper.close
    end

    it_should_behave_like "Normal repository contents"

    it 'should log correctly as it scrapes' do
      callback = flexmock("callback")
      callback.should_receive(:call).with(:begin, :scraping, "from git #{@repo.url}", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:begin, :checkout, "", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:begin, :cloning, "to #{@tmpdir}/#{@repo.repository_hash}", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:commit, :cloning, "to #{@tmpdir}/#{@repo.repository_hash}", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:begin, :checkout_revision, "", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:commit, :checkout_revision, "", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:commit, :checkout, "", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:begin, :initialize, "setting up in #{@tmpdir}/#{@repo.repository_hash}", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:begin, :finding_next_cookbook, "in #{@tmpdir}/#{@repo.repository_hash}", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:begin, :reading_cookbook, "from #{@tmpdir}/#{@repo.repository_hash}", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:begin, :scanning_filesystem, "rooted at #{@tmpdir}/#{@repo.repository_hash}", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:begin, :metadata_parsing, "", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:commit, :metadata_parsing, "", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:commit, :scanning_filesystem, "rooted at #{@tmpdir}/#{@repo.repository_hash}", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:commit, :reading_cookbook, "from #{@tmpdir}/#{@repo.repository_hash}", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:commit, :finding_next_cookbook, "in #{@tmpdir}/#{@repo.repository_hash}", nil).at_least.once.at_most.once
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
  end

  context 'given a SVN repository' do
    before(:each) do
      @helper = RightScale::SvnScraperSpecHelper.new
      @repo = @helper.repo
    end

    after(:each) do
      @helper.close
    end

    it_should_behave_like "Normal repository contents"

    it 'should log correctly as it scrapes' do
      callback = flexmock("callback")
      callback.should_receive(:call).with(:begin, :scraping, "from svn #{@repo.url}", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:begin, :checkout, "", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:begin, :checkout_revision, "", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:commit, :checkout_revision, "", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:commit, :checkout, "", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:begin, :initialize, "setting up in #{@tmpdir}/#{@repo.repository_hash}", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:begin, :finding_next_cookbook, "in #{@tmpdir}/#{@repo.repository_hash}", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:begin, :reading_cookbook, "from #{@tmpdir}/#{@repo.repository_hash}", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:begin, :scanning_filesystem, "rooted at #{@tmpdir}/#{@repo.repository_hash}", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:begin, :metadata_parsing, "", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:commit, :metadata_parsing, "", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:commit, :scanning_filesystem, "rooted at #{@tmpdir}/#{@repo.repository_hash}", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:commit, :reading_cookbook, "from #{@tmpdir}/#{@repo.repository_hash}", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:commit, :finding_next_cookbook, "in #{@tmpdir}/#{@repo.repository_hash}", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:commit, :initialize, "setting up in #{@tmpdir}/#{@repo.repository_hash}", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:begin, :next, "", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:begin, :searching, "", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:commit, :searching, "", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:commit, :next, "", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:begin, :next, "", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:commit, :next, "", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:commit, :scraping, "from svn #{@repo.url}", nil).at_least.once.at_most.once
      @scraper.scrape(@repo) do |phase, operation, explanation, exception|
        callback.call(phase, operation, explanation, exception)
      end
      @scraper.succeeded?.should be_true
    end
  end

  context 'given several repositories' do
    it 'should continue to scrape even if errors occur' do
      GC.start
      repo = RightScale::Repository.from_hash(:display_name => 'illegal repo',
                                              :repo_type    => :download,
                                              :url          => "http://example.com/foo")
      @scraper.scrape(repo)
      helpers = [RightScale::DownloadScraperSpecHelper,
                 RightScale::GitScraperSpecHelper,
                 RightScale::SvnScraperSpecHelper]
      helpers.each do |klass|
        helper = klass.new
        @scraper.scrape(helper.repo)
        helper.close
      end
      @scraper.succeeded?.should be_false
      @scraper.cookbooks.size.should == 3
      @scraper.errors.size.should == 1
    end
  end

  it 'catches normal logging behavior' do
    logger = @scraper.instance_variable_get(:@logger)
    logger.info("foo")
    logger.error("foo")
    @scraper.succeeded?.should be_false
    @scraper.errors.should == [[nil, :log, {:severity => Logger::ERROR,
                                  :message => "foo",
                                  :progname => nil}]]
  end
end
