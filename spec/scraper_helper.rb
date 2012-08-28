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

module RightScraper
  module SpecHelpers
    module FromScratchScraping
      def FromScratchScraping.included(mod)
        mod.module_eval do
          before(:each) do
            @basedir = Dir.mktmpdir
            @retriever = @retriever_class.new(@repo,
                                         :basedir => @basedir,
                                         :max_bytes => 1024**2,
                                         :max_seconds => 20)
            @retriever.retrieve
          end

          after(:each) do
            if @basedir && File.directory?(@basedir)
              FileUtils.remove_entry_secure(@basedir)
            end
            @scraper = nil
          end
        end
      end
    end

    module CookbookScraping
      def CookbookScraping.included(mod)
        mod.module_eval do
          before(:each) do
            @scraper = RightScraper::Scrapers::Base.scraper(:repo_dir        => @retriever.repo_dir,
                                                            :kind            => :cookbook,
                                                            :repository      => @retriever.repository,
                                                            :ignorable_paths => @retriever.ignorable_paths)
          end
        end
      end
    end

    module WorkflowScraping
      def WorkflowScraping.included(mod)
        mod.module_eval do
          before(:each) do
            @scraper = RightScraper::Scrapers::Base.scraper(:repo_dir        => @retriever.repo_dir,
                                                            :kind            => :workflow,
                                                            :repository      => @retriever.repository,
                                                            :ignorable_paths => @retriever.ignorable_paths)
          end
        end
      end
    end

  end
  module ScraperHelper
    def archive_skeleton(archive)
      files = Set.new
      Archive.read_open_memory(archive) do |ar|
        while entry = ar.next_header
          files << [entry.pathname, ar.read_data]
        end
      end
      files
    end

    def check_resource(resource, params={})
      position = params[:position] || "."
      resource.should_not == nil
      resource.repository.should be_an_equal_repo @repo
      resource.pos.should == position
      resource.metadata.should == (params[:metadata] || @helper.repo_content)
      resource.manifest.should == (params[:manifest] || @helper.manifest)
    end
  end
end
