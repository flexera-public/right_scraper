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

# Not supported on Windows
unless RUBY_PLATFORM=~/mswin/

require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))
require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'lib', 'right_scraper'))
require 'tmpdir'
require 'highline/import'

describe RightScale::DownloadScraper do

  include RightScale::SpecHelpers

  # Create download repository following given layout
  # Update @repo_path with path to repository
  # Delete any previously created repo
  def setup_download_repo
    @tmpdir = Dir.mktmpdir
    @download_repo_path = File.join(@tmpdir, "download")
    @repo_path = File.join(@tmpdir, "repo")
    @repo_content = [ { 'folder1' => [ 'file2', 'file3' ] }, { 'folder2' => [ { 'folder3' => [ 'file4' ] } ] }, 'file1' ]
    create_cookbook(@download_repo_path, @repo_content)
    @download_file = File.join(@tmpdir, "file.tar")
    Dir.chdir(@download_repo_path) do
      res, status = exec("tar cf \"#{@download_file}\" *")
      raise "Failed to create tarball: #{res}" unless status.success?
    end
  end

  # Cleanup after ourselves
  def delete_download_repo
    FileUtils.remove_entry_secure @tmpdir
  end

  before(:all) do
    @scraperclass = RightScale::DownloadScraper
  end

  context 'given a password protected repository' do
    before(:all) do
      @username = ask('Username: ')
      @password = ask('Password: ') {|q| q.echo = '*'}
    end

    before(:each) do
      url = 'https://wush.net/svn/rightscale/cookbooks_test/cookbooks/app_rails.tar.gz'
      @repo = RightScale::Repository.from_hash(:display_name => 'wush',
                                               :repo_type    => :download,
                                               :url          => url,
                                               :first_credential => @username,
                                               :second_credential => @password)
      @scraper = @scraperclass.new(@repo,
                                   :max_bytes => 1024**2,
                                   :max_seconds => 20)
    end

    it 'should scrape' do
      cookbook = @scraper.next
      cookbook.should_not == nil
      cookbook.metadata.should_not == nil
      cookbook.metadata["name"].should == "app_rails"
    end
  end if ENV['TEST_REMOTE']

  context 'given a download repository' do

    before(:all) do
      setup_download_repo
    end

    before(:each) do
      @repo = RightScale::Repository.from_hash(:display_name => 'test repo',
                                               :repo_type    => :download,
                                               :url          => "file:///#{@download_file}")
      @scraper = @scraperclass.new(@repo,
                                   :max_bytes => 1024**2,
                                   :max_seconds => 20)
      FileUtils.rm_rf(RightScale::ScraperBase.repo_dir(@repo_path, @repo))
    end

    after(:all) do
      delete_download_repo
    end

    it 'should always have position be the same' do
      first = @scraper.position
      @scraper.next
      @scraper.position.should == first
    end

    it 'should ignore seek' do
      @scraper.seek(42)
      @scraper.next
    end

    it 'should only return one cookbook' do
      @scraper.next
      @scraper.next.should == nil
    end

    it 'should scrape' do
      cookbook = @scraper.next
      cookbook.should_not == nil
      example = File.open(@download_file, 'r').read
      cookbook.data[:archive].should == example
      cookbook.repository.should == @repo
      cookbook.position.should == true
      cookbook.metadata.should == @repo_content
    end

    it 'should scrape a gzipped tarball' do
      res, status = exec("gzip -c #{@download_file} > #{@download_file}.gz")
      raise "Failed to gzip tarball: #{res}" unless status.success?
      begin
        @repo.url += ".gz"
        cookbook = @scraper.next
        cookbook.should_not == nil
        example = File.open(@download_file + ".gz", 'r').read
        cookbook.data[:archive].should == example
        cookbook.repository.should == @repo
        cookbook.position.should == true
        cookbook.metadata.should == @repo_content
      ensure
        File.unlink(@download_file + ".gz")
      end
    end

    it 'should scrape a bzipped tarball' do
      res, status = exec("bzip2 -c #{@download_file} > #{@download_file}.bz2")
      raise "Failed to bzip tarball: #{res}" unless status.success?
      begin
        @repo.url += ".bz2"
        cookbook = @scraper.next
        cookbook.should_not == nil
        example = File.open(@download_file + ".bz2", 'r').read
        cookbook.data[:archive].should == example
        cookbook.repository.should == @repo
        cookbook.position.should == true
        cookbook.metadata.should == @repo_content
      ensure
        File.unlink(@download_file + ".bz2")
      end
    end

  end

end

end # unless RUBY_PLATFORM=~/mswin/
