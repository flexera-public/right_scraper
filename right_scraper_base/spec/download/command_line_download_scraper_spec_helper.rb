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

require File.expand_path(File.join(File.dirname(__FILE__), '..', 'scraper_spec_helper_base'))
require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'lib', 'right_scraper_base'))

module RightScraper
  class CommandLineDownloadScraperSpecHelper < ScraperSpecHelperBase
    def download_repo_path
      File.join(@tmpdir, "download")
    end

    attr_reader :download_file

    def repo
      RightScraper::Repository.from_hash(:display_name => 'test repo',
                                       :repo_type    => :download_command_line,
                                       :url          => "file://#{@download_file}",
                                       :first_credential => ENV['REMOTE_USER'],
                                       :second_credential => ENV['REMOTE_PASSWORD'])
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

    def check_cookbook(cookbook, tarball, repository, position=".")
      cookbook.should_not == nil
      if cookbook.data.key?(:archive)
        example = File.open(tarball, 'r').read
        cookbook.data[:archive].should == example
      end
      cookbook.repository.should == repository
      cookbook.pos.should == position
      cookbook.metadata.should == repo_content
      cookbook.manifest.should == manifest
    end
  end
end
