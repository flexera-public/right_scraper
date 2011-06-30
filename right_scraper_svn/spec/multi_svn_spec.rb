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
require File.expand_path(File.join(File.dirname(__FILE__), 'multi_svn_spec_helper'))
require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'right_scraper_base', 'spec', 'scraper_helper'))

describe RightScraper::Scrapers::Svn do
  context 'in a multiple directory situation with a cookbooks_path set' do
    include RightScraper::SpecHelpers::DevelopmentModeEnvironment

    include RightScraper::ScraperHelper

    before(:all) do
      @scraperclass = RightScraper::Scrapers::Svn
      @ignore = ['.svn']
    end

    context 'given a SVN repository' do
      before(:each) do
        @helper = RightScraper::MultiSvnSpecHelper.new
        @repo = @helper.repo
      end

      after(:each) do
        @helper.close unless @helper.nil?
        @helper = nil
      end

      include RightScraper::SpecHelpers::FromScratchScraping

      it 'should see two cookbooks' do
        @scraper.next.should_not == nil
        @scraper.next.should_not == nil
        @scraper.next.should == nil
      end

      it 'should set the position correctly' do
        check_cookbook @scraper.next, :position => "subdir1"
        check_cookbook @scraper.next, :position => "subdir2"
      end
    end
  end
end
