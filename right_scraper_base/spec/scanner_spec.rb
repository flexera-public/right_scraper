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
require File.expand_path(File.join(File.dirname(__FILE__), 'download', 'command_line_download_scraper_spec_helper'))

describe RightScraper::Scanners::Scanner do
  it_should_behave_like "Development mode environment"

  before(:each) do
    @helper = RightScraper::CommandLineDownloadScraperSpecHelper.new
    @repo = @helper.repo
  end

  after(:each) do
    @helper.close
  end

  it 'should be called correctly' do
    scanner = flexmock("scanner")
    scanner.should_receive(:new).with(Hash).once.and_return(scanner)
    scanner.should_receive(:begin).with(RightScraper::Cookbook).once
    scanner.should_receive(:notice_dir).with(nil).once.and_return(true)
    scanner.should_receive(:notice).with("file1", Proc).once
    scanner.should_receive(:notice_dir).with("folder1").once.and_return(true)
    scanner.should_receive(:notice).with("folder1/file2", Proc).once
    scanner.should_receive(:notice).with("folder1/file3", Proc).once
    scanner.should_receive(:notice_dir).with("folder2").once.and_return(false)
    scanner.should_receive(:notice).with("metadata.json", Proc).once
    scanner.should_receive(:end).with(RightScraper::Cookbook).once
    scanner.should_receive(:finish).with().once

    @scraper = @repo.scraper.new(@repo, :scanners => [scanner])
    @scraper.next.should_not be_nil
    @scraper.next.should be_nil
    @scraper.close
  end
end
