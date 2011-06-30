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
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib', 'right_scraper_libcurl'))

describe RightScraper::Repositories::Download do
  include RightScraper::SpecHelpers::DevelopmentModeEnvironment

  before(:each) do
    @repo = RightScraper::Repository.from_hash(:display_name => 'test repo',
                                             :repo_type => :download,
                                             :url => "http://foo.bar.baz.quux/%20CBLAH",
                                             :first_credential => "foo:b/ar",
                                             :second_credential => "foo@bar")
  end

  it 'should have the same repository hash with or without credentials' do
    initial_hash = @repo.repository_hash
    @repo.first_credential = nil
    @repo.second_credential = nil
    @repo.repository_hash.should == initial_hash
  end

  it 'should have the same checkout hash with or without credentials' do
    initial_hash = @repo.checkout_hash
    @repo.first_credential = nil
    @repo.second_credential = nil
    @repo.checkout_hash.should == initial_hash
  end

  it 'should tell us to use the libcurl downloader' do
    pending {
      @repo.scraper.should == RightScraper::Scrapers::LibCurlDownload
    }
  end
end
