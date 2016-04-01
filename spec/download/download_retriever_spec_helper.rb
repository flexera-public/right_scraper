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

require File.expand_path(File.join(File.dirname(__FILE__), '..', 'retriever_spec_helper'))
require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'lib', 'right_scraper'))

module RightScraper
  class DownloadRetrieverSpecHelper < RetrieverSpecHelper
    def download_repo_path
      File.join(@tmpdir, "download")
    end

    attr_reader :download_file

    def repo
      RightScraper::Repositories::Base.from_hash(
        :display_name => 'test repo',
        :repo_type    => :download,
        :url          => "file://#{@download_file}")
    end

    # Create download repository following given layout
    # Update @repo_path with path to repository
    # Delete any previously created repo
    def initialize
      super
      @download_repo_path = File.join(@tmpdir, "download")
      make_cookbooks
      @download_file = File.join(@tmpdir, "file.tar")
      Dir.chdir(download_repo_path) do
        res, status = exec("tar cf \"#{@download_file}\" *")
        raise "Failed to create tarball: #{res}" unless status.success?
      end
    end

    # Cookbook creation method.  Meant to be extended by subclasses.
    def make_cookbooks
      create_cookbook(download_repo_path, repo_content)
    end

    def check_resource(resource, tarball, repository, position=".")
      resource.should_not == nil
      resource.repository.tag.should_not == nil
      resource.repository.repository_hash.should == repository.repository_hash
      resource.repository.checkout_hash.should_not == repository.checkout_hash
      resource.pos.should == position
      resource.metadata.should == repo_content
      resource.manifest.should == manifest
    end
  end
end
