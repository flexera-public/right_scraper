#--
# Copyright: Copyright (c) 2010-2013 RightScale, Inc.
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

require File.expand_path(File.join(File.dirname(__FILE__), 'multi_dir_spec_helper'))
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'scraper_helper'))

describe RightScraper::Retrievers::Download do
  context 'in a multiple directory situation with a resources_path set' do
    include RightScraper::SpecHelpers::DevelopmentModeEnvironment

    include RightScraper::ScraperHelper
    include RightScraper::SpecHelpers

    before(:each) do
      @helper = RightScraper::MultiDirectorySpecHelper.new
      @repo = @helper.repo
    end

    after(:each) do
      @helper.close unless @helper.nil?
      @helper = nil
    end

    context 'given a download repository' do
      before(:each) do
        @retriever = make_retriever(@repo, @helper.download_repo_path)
        @retriever.retrieve
        @scraper = make_scraper(@retriever)
        @download_file = @helper.download_file
      end

      it 'should return two cookbooks' do
        @scraper.next_resource.should_not == nil
        @scraper.next_resource.should_not == nil
        @scraper.next_resource.should == nil
      end

      it 'should scrape' do
        @helper.check_resource(@scraper.next_resource, @download_file, @repo, "subdir1")
        @helper.check_resource(@scraper.next_resource, @download_file, @repo, "subdir2")
      end
    end

    it 'should scrape a gzipped tarball' do
      @download_file = @helper.download_file
      res, status = exec("gzip -c #{@download_file} > #{@download_file}.gz")
      raise "Failed to gzip tarball: #{res}" unless status.success?
      begin
        @repo.url += ".gz"
        @retriever = make_retriever(@repo, @helper.download_repo_path)
        @retriever.retrieve
        @scraper = make_scraper(@retriever)
        @helper.check_resource(@scraper.next_resource, @download_file + ".gz", @repo, "subdir1")
        @helper.check_resource(@scraper.next_resource, @download_file + ".gz", @repo, "subdir2")
      ensure
        File.unlink(@download_file + ".gz")
      end
    end

    it 'should scrape a bzipped tarball' do
      @download_file = @helper.download_file
      res, status = exec("bzip2 -c #{@download_file} > #{@download_file}.bz2")
      raise "Failed to bzip tarball: #{res}" unless status.success?
      begin
        @repo.url += ".bz2"
        @retriever = make_retriever(@repo, @helper.download_repo_path)
        @retriever.retrieve
        @scraper = make_scraper(@retriever)
        @helper.check_resource(@scraper.next_resource, @download_file + ".bz2", @repo, "subdir1")
        @helper.check_resource(@scraper.next_resource, @download_file + ".bz2", @repo, "subdir2")
      ensure
        File.unlink(@download_file + ".bz2")
      end
    end
  end
end
