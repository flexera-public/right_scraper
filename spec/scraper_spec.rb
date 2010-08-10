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

require File.join(File.dirname(__FILE__), 'spec_helper')
require File.join(File.dirname(__FILE__), '..', 'lib', 'right_scraper', 'scraper_base')
require File.join(File.dirname(__FILE__), '..', 'lib', 'right_scraper', 'scrapers', 'git_scraper')
require File.join(File.dirname(__FILE__), '..', 'lib', 'right_scraper', 'scrapers', 'svn_scraper')
require File.join(File.dirname(__FILE__), '..', 'lib', 'right_scraper', 'scrapers', 'download_scraper')
require File.join(File.dirname(__FILE__), '..', 'lib', 'right_scraper', 'repository')
require File.join(File.dirname(__FILE__), '..', 'lib', 'right_scraper', 'repositories', 'mock_repository')
require File.join(File.dirname(__FILE__), '..', 'lib', 'right_scraper', 'scraper')

describe RightScale::Scraper do

  before(:each) do
    @scraper = RightScale::Scraper.new('/tmp')
    @mock_scraper = flexmock('MockScraper')
    mock_scraper_klass = flexmock('MockScraperClass', :new => @mock_scraper)
    RightScale::MockRepository.scraper = mock_scraper_klass
  end
  
  after(:all) do
    RightScale::MockRepository.scraper = nil
  end
  
  it 'should scrape' do
    repo = RightScale::MockRepository.new
    repo.repo_type = :mock
    @mock_scraper.should_receive(:scrape).with(repo, true, Proc).and_return(true)
    @mock_scraper.should_receive(:succeeded?).and_return(true)
    @mock_scraper.should_receive(:current_repo_dir).and_return('42')
    @scraper.scrape(repo) { }.should be_true
    @scraper.last_repo_dir.should == '42'
  end
  
  it 'should scrape from a hash' do
    @mock_scraper.should_receive(:scrape).with(RightScale::MockRepository, true, Proc).and_return(true)
    @mock_scraper.should_receive(:succeeded?).and_return(true)
    @mock_scraper.should_receive(:current_repo_dir).and_return('42')
    @scraper.scrape({:repo_type => :mock}) { }.should be_true
  end
  
  it 'should report failures' do
    @mock_scraper.should_receive(:scrape).with(RightScale::MockRepository, true, Proc).and_return(true)
    @mock_scraper.should_receive(:succeeded?).and_return(false)
    @mock_scraper.should_receive(:current_repo_dir).and_return('42')
    @scraper.scrape({:repo_type => :mock}) { }.should be_false
  end
    
end
