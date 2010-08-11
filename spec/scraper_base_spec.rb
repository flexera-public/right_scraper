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
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib', 'right_scraper', 'scraper_base'))

describe RightScale::ScraperBase do

  before(:each) do
    @base = RightScale::ScraperBase.new('/tmp', max_bytes=1024**2, max_seconds=20)
  end
  
  it 'should initialize the scrape directory' do
    @base.root_dir.should == '/tmp'
  end
  
  it 'should default to non incremental updates' do
    @base.send(:incremental_update?).should be_false
  end
    
  it 'should allow retrieving the download directory path' do
    repo_dir = RightScale::ScraperBase.repo_dir('root_dir', { :repo_type => :git, :url => 'git://github.com/rightscale/right_scraper.git' })
    repo_dir.should =~ /^root_dir\//
  end
  
end 
