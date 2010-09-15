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
require File.expand_path(File.join(File.dirname(__FILE__), 'libcurl_download_scraper_spec_helper'))
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

  context 'given an illegal download repository' do
    before(:each) do
      @repo = RightScale::Repository.from_hash(:display_name => 'illegal repo',
                                               :repo_type    => :download_libcurl,
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

  context 'given a legal download repository' do
    before(:each) do
      GC.start
      @helper = RightScale::LibCurlDownloadScraperSpecHelper.new
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
      callback.should_receive(:call).with(:commit, :downloading, "", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:begin, :reading_metadata, "", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:begin, :metadata_parsing, "", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:commit, :metadata_parsing, "", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:commit, :reading_metadata, "", nil).at_least.once.at_most.once
      callback.should_receive(:call).with(:commit, :scraping, "from download #{@repo.url}", nil).at_least.once.at_most.once
      @scraper.scrape(@repo) do |phase, operation, explanation, exception|
        callback.call(phase, operation, explanation, exception)
      end
      @scraper.errors.should == []
      @scraper.succeeded?.should be_true
    end
  end
end
