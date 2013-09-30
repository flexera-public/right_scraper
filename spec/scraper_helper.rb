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

require File.expand_path(File.join(File.dirname(__FILE__), 'spec_helper'))

require 'fileutils'
require 'tmpdir'

module RightScraper
  module SpecHelpers
    module FromScratchScraping
      def FromScratchScraping.included(mod)
        mod.module_eval do
          before(:each) do
            @basedir = Dir.mktmpdir
            @retriever = make_retriever(@repo, @basedir)
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
            @scraper = make_scraper(@retriever, kind = :cookbook)
          end
        end
      end
    end

    module WorkflowScraping
      def WorkflowScraping.included(mod)
        mod.module_eval do
          before(:each) do
            @scraper = make_scraper(@retriever, kind = :workflow)
          end
        end
      end
    end

  end
  module ScraperHelper
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
