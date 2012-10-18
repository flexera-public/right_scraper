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
require 'tmpdir'
require 'digest/sha1'

describe RightScraper::Scanners::CookbookS3Upload do
  include RightScraper::SpecHelpers::DevelopmentModeEnvironment

  include RightScraper::SpecHelpers

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
    FileUtils.remove_entry_secure @tmpdir unless @tmpdir.nil?
  end

  before(:all) do
    @scraperclass = RightScraper::Scrapers::Cookbook
  end

  before(:each) do
    pending "Not run unless AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY set" unless
            ENV['AWS_ACCESS_KEY_ID'] && ENV['AWS_SECRET_ACCESS_KEY']
  end

  context "given a bucket that doesn't exist" do
    before(:each) do
      setup_download_repo
    end

    after(:each) do
      delete_download_repo
    end

    before(:each) do
      @repo = RightScraper::Repositories::Base.from_hash(:display_name => 'test repo',
                                               :repo_type    => :download,
                                               :url          => "file:///#{@download_file}")
      @s3 = RightAws::S3.new(aws_access_key_id=ENV['AWS_ACCESS_KEY_ID'],
                            aws_secret_access_key=ENV['AWS_SECRET_ACCESS_KEY'],
                            :logger => RightScraper::Logger.new)
      FileUtils.rm_rf(RightScraper::Retrievers::Base.repo_dir(@repo_path, @repo))
    end

    it 'should raise an exception immediately' do
      bucket_name = 'this-bucket-does-not-exist'
      @s3.bucket(bucket_name).should be_nil
      lambda {
      @scraper = @scraperclass.new(:repository => @repo,
                                   :repo_dir => @download_repo_path,
                                   :scanners => [RightScraper::Scanners::CookbookMetadata,
                                                 RightScraper::Scanners::CookbookManifest,
                                                 RightScraper::Scanners::CookbookS3Upload],
                                   :s3_key => ENV['AWS_ACCESS_KEY_ID'],
                                   :s3_secret => ENV['AWS_SECRET_ACCESS_KEY'],
                                   :s3_bucket => bucket_name,
                                   :max_bytes => 1024**2,
                                   :max_seconds => 20)
        }.should raise_exception(/Need an actual, existing S3 bucket!/)
    end
  end

  context 'given a download repository with the S3UploadScanner' do
    before(:each) do
      setup_download_repo
    end

    before(:each) do
      @repo = RightScraper::Repositories::Base.from_hash(:display_name => 'test repo',
                                               :repo_type    => :download,
                                               :url          => "file:///#{@download_file}")
      bucket_name = 'com.rightscale.test.20100823'
      @scraper = @scraperclass.new(:repository => @repo,
                                   :repo_dir => @download_repo_path,
                                   :scanners => [RightScraper::Scanners::CookbookMetadata,
                                                 RightScraper::Scanners::CookbookManifest,
                                                 RightScraper::Scanners::CookbookS3Upload],
                                   :s3_key => ENV['AWS_ACCESS_KEY_ID'],
                                   :s3_secret => ENV['AWS_SECRET_ACCESS_KEY'],
                                   :s3_bucket => bucket_name,
                                   :max_bytes => 1024**2,
                                   :max_seconds => 20)
      s3 = RightAws::S3.new(aws_access_key_id=ENV['AWS_ACCESS_KEY_ID'],
                            aws_secret_access_key=ENV['AWS_SECRET_ACCESS_KEY'],
                            :logger => RightScraper::Logger.new)

      # create=true is prone to the too-many-buckets error even when the bucket
      # already exists. since the bucket always exists for the test account
      # there is no need to try creating it programmatically and fail specs.
      @bucket = s3.bucket(bucket_name, create=false)
      FileUtils.rm_rf(RightScraper::Retrievers::Base.repo_dir(@repo_path, @repo))
    end

    after(:each) do
      delete_download_repo
    end

    context 'that has scraped' do
      before(:each) do
        @cookbook = @scraper.next_resource
        @cookbook.should_not be_nil
      end

      it 'the cookbook should exist' do
        s3cookbook = @bucket.get(File.join('Cooks', @cookbook.resource_hash))
        s3cookbook.should_not be_nil
        hash = JSON.parse(s3cookbook)
        hash["metadata"].should == @cookbook.metadata
        hash["manifest"].should == @cookbook.manifest
      end

      it 'every file in the manifest should exist' do
        @cookbook.manifest.each do |key, value|
          file = @bucket.get(File.join('Files', value))
          file.should_not be_nil
          Digest::SHA1.hexdigest(file).should == value
        end
      end
    end
  end
end
