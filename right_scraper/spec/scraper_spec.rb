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

require File.expand_path(File.join(File.dirname(__FILE__), "spec_helper"))
require 'stringio'
require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'right_scraper_base', 'spec', 'download', 'command_line_download_scraper_spec_helper'))
require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'right_scraper_git', 'spec', 'git_scraper_spec_helper'))
require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'right_scraper_libcurl', 'spec', 'libcurl_download_scraper_spec_helper'))
require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'right_scraper_svn', 'spec', 'svn_scraper_spec_helper'))
require 'tmpdir'
require 'flexmock'

describe RightScale::Scraper do
  it_should_behave_like "Development mode environment"

  before(:each) do
    @stream = StringIO.new()
    @tmpdir = Dir.mktmpdir
    @scraper = RightScale::Scraper.new(@tmpdir)
  end

  after(:each) do
    FileUtils.remove_entry_secure @tmpdir
  end

  context 'given several repositories' do
    it 'should continue to scrape even if errors occur' do
      GC.start
      repo = RightScale::Repository.from_hash(:display_name => 'illegal repo',
                                              :repo_type    => :download,
                                              :url          => "http://example.com/foo")
      @scraper.scrape(repo)
      helpers = [RightScale::CommandLineDownloadScraperSpecHelper,
                 RightScale::LibCurlDownloadScraperSpecHelper,
                 RightScale::GitScraperSpecHelper,
                 RightScale::SvnScraperSpecHelper]
      helpers.each do |klass|
        helper = klass.new
        @scraper.scrape(helper.repo)
        helper.close
      end
      @scraper.succeeded?.should be_false
      @scraper.cookbooks.size.should == 4
      @scraper.errors.size.should == 1
    end
  end
end
