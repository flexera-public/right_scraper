#--
# Copyright: Copyright (c) 2010-2011 RightScale, Inc.
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
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))
require File.expand_path(File.join(File.dirname(__FILE__), 'svn_retriever_spec_helper'))
require 'tmpdir'
require 'flexmock'

describe RightScraper::Scraper do
  include RightScraper::SpecHelpers::DevelopmentModeEnvironment

  include RightScraper::SharedExamples

  before(:each) do
    @stream = StringIO.new()
    @tmpdir = Dir.mktmpdir
    @scraper = RightScraper::Scraper.new(:basedir => @tmpdir, :kind => :cookbook)
  end

  after(:each) do
    FileUtils.remove_entry_secure @tmpdir
  end

  context 'given a SVN repository' do
    before(:each) do
      @helper = RightScraper::SvnRetrieverSpecHelper.new
      @repo = @helper.repo
    end

    after(:each) do
      @helper.close
    end

    it_should_behave_like "a normal repository"

    it 'should log correctly as it scrapes' do
      callback = flexmock("callback")
      callback.should_receive(:call).with(:begin, :retrieving, "from #{@repo}", nil).once.ordered
      callback.should_receive(:call).with(:begin, :initialize, String, nil).once.ordered
      callback.should_receive(:call).with(:commit, :initialize, String, nil).once.ordered
      callback.should_receive(:call).with(:begin, :checkout, "", nil).once.ordered
      callback.should_receive(:call).with(:begin, :checkout_revision, "", nil).once.ordered
      callback.should_receive(:call).with(:commit, :checkout_revision, "", nil).once.ordered
      callback.should_receive(:call).with(:commit, :checkout, "", nil).once.ordered
      callback.should_receive(:call).with(:commit, :retrieving, "from #{@repo}", nil).once.ordered
      callback.should_receive(:call).with(:begin, :scraping, String, nil).once.ordered
      callback.should_receive(:call).with(:begin, :finding_next_cookbook, String, nil).once.ordered
      callback.should_receive(:call).with(:begin, :reading_cookbook, String, nil).once.ordered
      callback.should_receive(:call).with(:begin, :scanning_filesystem, String, nil).once.ordered
      callback.should_receive(:call).with(:begin, :metadata_parsing, "", nil).once.ordered
      callback.should_receive(:call).with(:commit, :metadata_parsing, "", nil).once.ordered
      callback.should_receive(:call).with(:commit, :scanning_filesystem, String, nil).once.ordered
      callback.should_receive(:call).with(:commit, :reading_cookbook, String, nil).once.ordered
      callback.should_receive(:call).with(:commit, :finding_next_cookbook, String, nil).once.ordered
      callback.should_receive(:call).with(:begin, :next, "", nil).once.ordered
      callback.should_receive(:call).with(:begin, :searching, "", nil).once.ordered
      callback.should_receive(:call).with(:commit, :searching, "", nil).once.ordered
      callback.should_receive(:call).with(:commit, :next, "", nil).once.ordered
      callback.should_receive(:call).with(:begin, :next, "", nil).once.ordered
      callback.should_receive(:call).with(:commit, :next, "", nil).once.ordered
      callback.should_receive(:call).with(:commit, :scraping, String, nil).once.ordered
      @scraper.scrape(@repo) do |phase, operation, explanation, exception|
        callback.call(phase, operation, explanation, exception)
      end
      @scraper.errors.should == []
      @scraper.succeeded?.should be_true
    end
  end
end
