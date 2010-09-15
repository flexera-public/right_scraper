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
require File.expand_path(File.join(File.dirname(__FILE__), 'full_scraper_helper'))
require File.expand_path(File.join(File.dirname(__FILE__), 'download', 'command_line_download_scraper_spec_helper'))
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib', 'right_scraper_base'))
require 'tmpdir'
require 'flexmock'

describe RightScale::Scraper do
  it_should_behave_like "Development mode environment"

  include RightScale::FullScraperHelpers

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
                                               :repo_type    => :download_command_line,
                                               :url          => "http://example.invalid/foo")
    end

    it 'should not throw an exception, but still fail to scrape' do
      @scraper.scrape(@repo)
      @scraper.succeeded?.should be_false
      @scraper.errors.size.should == 1
      exception, activity, explanation = @scraper.errors[0]
      exception.should_not be_nil
      activity.should == :running_command
      explanation.should be_an_instance_of(String)
      explanation.should_not == ""
    end

    it 'should call the callback appropriately' do
      callback = flexmock("callback")
      callback.should_receive(:call).with(:begin, :scraping, "from download #{@repo.url}", nil).once
      callback.should_receive(:call).with(:begin, :downloading, "", nil).once
      callback.should_receive(:call).with(:begin, :running_command, String, nil).once
      callback.should_receive(:call).with(:abort, :running_command, String, RuntimeError).once
      callback.should_receive(:call).with(:abort, :downloading, "", RuntimeError).once
      callback.should_receive(:call).with(:abort, :scraping, "from download #{@repo.url}", RuntimeError).once
      @scraper.scrape(@repo, true) do |phase, operation, explanation, exception|
        callback.call(phase, operation, explanation, exception)
      end
    end
  end

  context 'given a legal download repository' do
    before(:each) do
      @helper = RightScale::CommandLineDownloadScraperSpecHelper.new
      @repo = @helper.repo
    end

    after(:each) do
      @helper.close
    end

    it_should_behave_like "Normal repository contents"

    it 'should log correctly as it scrapes' do
      callback = flexmock("callback")
      callback.should_receive(:call).with(:begin, :scraping, "from #{@repo}", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:begin, :downloading, "", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:begin, :running_command, String, nil).at_least.twice.at_most.twice
      callback.should_receive(:call).with(:commit, :running_command, String, nil).at_least.twice.at_most.twice
      callback.should_receive(:call).with(:commit, :downloading, "", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:begin, :unpacking, "", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:commit, :unpacking, "", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:begin, :initialize, String, nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:begin, :finding_next_cookbook, String, nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:begin, :reading_cookbook, String, nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:begin, :scanning_filesystem, String, nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:begin, :metadata_parsing, "", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:commit, :metadata_parsing, "", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:commit, :scanning_filesystem, String, nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:commit, :reading_cookbook, String, nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:commit, :finding_next_cookbook, String, nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:commit, :initialize, String, nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:begin, :next, "", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:begin, :searching, "", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:commit, :searching, "", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:commit, :next, "", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:begin, :next, "", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:commit, :next, "", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:begin, :close, "", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:commit, :close, "", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:commit, :scraping, "from #{@repo}", nil).at_least.once.at_most.once
      @scraper.scrape(@repo) do |phase, operation, explanation, exception|
        callback.call(phase, operation, explanation, exception)
      end
      @scraper.errors.should == []
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
      helpers = [RightScale::CommandLineDownloadScraperSpecHelper,
                 RightScale::CommandLineDownloadScraperSpecHelper,
                 RightScale::CommandLineDownloadScraperSpecHelper]
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
    logger.should_not be_nil
    logger.info("foo")
    logger.error("foo")
    @scraper.succeeded?.should be_false
    @scraper.errors.should == [[nil, :log, {:severity => Logger::ERROR,
                                  :message => "foo",
                                  :progname => nil}]]
  end
end
