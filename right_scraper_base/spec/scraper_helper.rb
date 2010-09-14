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

require File.expand_path(File.join(File.dirname(__FILE__), 'spec_helper'))
require 'tmpdir'

module RightScale
  module ScraperHelper
    shared_examples_for "From-scratch scraping" do
      before(:each) do
        @scraper = @scraperclass.new(@repo,
                                     :max_bytes => 1024**2,
                                     :max_seconds => 20)
      end

      after(:each) do
        @scraper.close
        @scraper = nil
      end
    end

    def archive_skeleton(archive)
      files = Set.new
      Archive.read_open_memory(archive) do |ar|
        while entry = ar.next_header
          files << [entry.pathname, ar.read_data]
        end
      end
      files
    end

    def check_cookbook(cookbook, params={})
      position = params[:position] || "."
      cookbook.should_not == nil
      cookbook.repository.should be_an_equal_repo @repo
      cookbook.pos.should == position
      cookbook.metadata.should == (params[:metadata] || @helper.repo_content)
      if cookbook.data.key?(:archive)
        root = File.join(params[:rootdir] || @helper.repo_path, position)
        exclude_declarations =
          @ignore.map {|path| "--exclude #{path}"}.join(' ')
        tarball = `tar -C #{root} -c #{exclude_declarations} .`
        # We would compare these literally, but minor metadata changes
        # will completely hose you, so it's enough to make sure that the
        # files are in the same place and have the same content.
        archive_skeleton(cookbook.data[:archive]).should ==
          archive_skeleton(tarball)
      end
      cookbook.manifest.should == @helper.manifest
    end
  end
end
