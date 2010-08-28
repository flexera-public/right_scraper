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

require File.expand_path(File.join(File.dirname(__FILE__), 'base'))
require 'right_aws'
require 'json'

module RightScale
  module Scanners
    # Upload files to an S3 bucket.
    class S3Upload < Scanner
      # Create a new S3Upload.  In addition to the options recognized
      # by Scanner, this class recognizes _:s3_key_, _:s3_secret_, and
      # _:s3_bucket_ and requires all of those.
      #
      # === Options ===
      # _:s3_key_:: Required.  S3 access key.
      # _:s3_secret_:: Required.  S3 secret key.
      # _:s3_bucket_:: Required.  Bucket to upload cookbooks to.
      #
      # === Parameters ===
      # options(Hash):: scanner options
      def initialize(options={})
        super
        s3_key = options.fetch(:s3_key)
        s3_secret = options.fetch(:s3_secret)
        s3 = RightAws::S3.new(aws_access_key_id=s3_key,
                              aws_secret_access_key=s3_secret,
                              :logger => Logger.new)
        @bucket = s3.bucket(options.fetch(:s3_bucket))
      end

      # Complete a scan for the given cookbook.
      #
      # === Parameters ===
      # cookbook(RightScale::Cookbook):: cookbook to scan
      def end(cookbook)
        @bucket.put(File.join('Cooks', cookbook.cookbook_hash),
                    {
                      :url => cookbook.to_url,
                      :metadata => cookbook.metadata,
                      :manifest => cookbook.manifest,
                    }.to_json)
      end

      # Notice a file during scanning.
      #
      # === Block ===
      # Return the data for this file.  We use a block because it may
      # not always be necessary to read the data.
      #
      # === Parameters ===
      # relative_position(String):: relative pathname for file from root of cookbook
      def notice(relative_position)
        contents = yield
        name = Digest::SHA1.hexdigest(contents)
        path = File.join('Files', name)
        unless @bucket.key(path).exists?
          @bucket.put(path, contents)
        end
      end
    end
  end
end
