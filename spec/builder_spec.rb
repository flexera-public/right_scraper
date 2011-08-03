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

require File.expand_path(File.join(File.dirname(__FILE__), 'spec_helper'))
require File.expand_path(File.join(File.dirname(__FILE__), 'download', 'download_retriever_spec_helper'))

describe RightScraper::Builders::Builder do

  include RightScraper::SpecHelpers::DevelopmentModeEnvironment
  
  before(:each) do
    @helper = RightScraper::DownloadRetrieverSpecHelper.new
    @repo_dir = @helper.download_repo_path
  end

  it 'should be called correctly' do
    builder = flexmock("builder")
    builder.should_receive(:new).with(Hash).once.and_return(builder)
    builder.should_receive(:go).with(String, RightScraper::Resources::Cookbook).once
    builder.should_receive(:finish).with().once

    @scraper = RightScraper::Scrapers::Cookbook.new(:repository => @helper.repo,
                                                    :repo_dir   => @repo_dir,
                                                    :builders   => [builder])
    @scraper.next_resource.should_not be_nil
    @scraper.next_resource.should be_nil
    @scraper.close
  end

end
