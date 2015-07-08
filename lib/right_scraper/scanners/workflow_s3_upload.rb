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

# ancestor
require 'right_scraper/scanners'

require 'right_aws_api'
require 'right_scraper/utils/s3_helper'
require 'json'

module RightScraper::Scanners

  # Upload workflow definition and metadata to an S3 bucket.
  class WorkflowS3Upload < ::RightScraper::Scanners::Base
    include ::RightScraper::S3Helper

    # Create a new S3Upload.  In addition to the options recognized
    # by Scanner, this class recognizes <tt>:s3_key</tt>,
    # <tt>:s3_secret</tt>, and <tt>:s3_bucket</tt> and requires all
    # of those.
    #
    # === Options
    # <tt>:s3_key</tt>:: Required.  S3 access key.
    # <tt>:s3_secret</tt>:: Required.  S3 secret key.
    # <tt>:s3_bucket</tt>:: Required.  Bucket to upload workflows to.
    #
    # === Parameters
    # options(Hash):: scanner options
    def initialize(options={})
      super
      s3_key = options.fetch(:s3_key)
      s3_secret = options.fetch(:s3_secret)
      @bucket = s3.bucket(options.fetch(:s3_bucket))
      @s3 = get_s3(s3_key, s3_secret, :logger => @logger)
      raise "Need an actual, existing S3 bucket!" unless s3_exists?(@bucket)
    end

    # Upon ending a scan for a workflows, upload the workflows
    # contents to S3.
    #
    # === Parameters
    # workflows(RightScraper::Workflows):: Workflow to scan
    def end(workflow)
      path = File.join('Workflows', workflow.resource_hash)
      @s3.PutObject("Bucket" => @bucket, "Object" => path, :body => {
        :metadata => workflow.metadata,
        :manifest => workflow.manifest
      }.to_json)
    end

    # Upload a file during scanning.
    #
    # === Block
    # Return the data for this file.  We use a block because it may
    # not always be necessary to read the data.
    #
    # === Parameters
    # relative_position(String):: relative pathname for file from root of cookbook
    def notice(relative_position)
      # TBD: Only uplad definition and metadata, will there be more files?
      contents = yield
      name = Digest::SHA1.hexdigest(contents)
      path = File.join('Files', name)
      unless s3_exists?(@bucket, path)
        @s3.PutObject("Bucket" => @bucket, "Object" => path, :body => contents)
      end
    end
  end
end
