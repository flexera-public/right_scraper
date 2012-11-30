#--
# Copyright: Copyright (c) 2010-2012 RightScale, Inc.
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
require 'right_aws'
require 'json'
require 'digest/md5'

module RightScraper
  module Scanners
    # Upload scanned files to an S3 bucket.
    class CookbookS3Upload < Base
      # Create a new S3Upload.  In addition to the options recognized
      # by Scanner, this class recognizes <tt>:s3_key</tt>,
      # <tt>:s3_secret</tt>, and <tt>:s3_bucket</tt> and requires all
      # of those.
      #
      # === Options
      # <tt>:s3_key</tt>:: Required.  S3 access key.
      # <tt>:s3_secret</tt>:: Required.  S3 secret key.
      # <tt>:s3_bucket</tt>:: Required.  Bucket to upload cookbooks to.
      #
      # === Parameters
      # options(Hash):: scanner options
      def initialize(options={})
        super
        s3_key = options.fetch(:s3_key)
        s3_secret = options.fetch(:s3_secret)
        s3 = RightAws::S3.new(aws_access_key_id=s3_key,
                              aws_secret_access_key=s3_secret,
                              :logger => Logger.new)
        @bucket = s3.bucket(options.fetch(:s3_bucket))
        raise "Need an actual, existing S3 bucket!" if @bucket.nil?
      end

      # Upon ending a scan for a cookbook, upload the cookbook
      # contents to S3.
      #
      # === Parameters
      # cookbook(RightScraper::Cookbook):: cookbook to scan
      def end(cookbook)
        path = File.join('Cooks', cookbook.resource_hash)
        unless @bucket.key(path).exists?
          contents = cookbook.manifest_json
          @bucket.put(path, contents)
        end
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
        contents = yield
        name = Digest::MD5.hexdigest(contents)
        path = File.join('Files', name)
        unless @bucket.key(path).exists?
          @bucket.put(path, contents)
        end
      end
    end
  end
end
