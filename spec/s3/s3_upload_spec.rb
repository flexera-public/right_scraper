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

require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))
require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'lib', 'right_scraper'))
require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'lib', 'right_scraper', 'scanners', 's3'))
require 'tmpdir'
require 'digest/sha1'

describe RightScale::S3UploadScanner do

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

  context 'given a download repository with the S3UploadScanner' do

    before(:all) do
      setup_download_repo
    end

    before(:all) do
      @repo = RightScale::Repository.from_hash(:display_name => 'test repo',
                                               :repo_type    => :download,
                                               :url          => "file:///#{@download_file}")
      @bucket = 'com.rightscale.test.20100823'
      @scraper = @scraperclass.new(@repo,
                                   :scanners => [RightScale::MetadataScanner,
                                                 RightScale::ManifestScanner,
                                                 RightScale::S3UploadScanner],
                                   :s3_key => ENV['AMAZON_ACCESS_KEY_ID'],
                                   :s3_secret => ENV['AMAZON_SECRET_ACCESS_KEY'],
                                   :s3_bucket => @bucket,
                                   :max_bytes => 1024**2,
                                   :max_seconds => 20)
      FileUtils.rm_rf(RightScale::ScraperBase.repo_dir(@repo_path, @repo))
    end

    after(:all) do
      delete_download_repo
    end

    context 'that has scraped' do
      before(:all) do
        @cookbook = @scraper.next
        @cookbook.should_not be_nil
      end

      it 'the cookbook should exist' do
        s3cookbook = AWS::S3::S3Object.find(File.join('Cooks', @cookbook.cookbook_hash), @bucket)
        s3cookbook.should_not be_nil
        hash = JSON.parse(s3cookbook.value)
        hash["url"].should == @cookbook.to_url
        hash["metadata"].should == @cookbook.metadata
        hash["manifest"].should == @cookbook.manifest
      end

      it 'every file in the manifest should exist' do
        @cookbook.manifest.each do |key, value|
          file = AWS::S3::S3Object.find(File.join('Files', value), @bucket)
          file.should_not be_nil
          Digest::SHA1.hexdigest(file.value).should == value
        end
      end
    end
  end if ENV['AMAZON_ACCESS_KEY_ID'] && ENV['AMAZON_SECRET_ACCESS_KEY']
end
