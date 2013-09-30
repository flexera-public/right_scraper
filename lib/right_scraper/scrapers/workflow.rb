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

require File.expand_path(File.join(File.dirname(__FILE__), 'base'))

# ancestor
require 'right_scraper/scrapers'

module RightScraper::Scrapers

  # Workflow scraper
  class Workflow < ::RightScraper::Scrapers::Base

   # Initialize list of known workflows on top of
    def initialize(options)
      @known_workflows = []
      super(options)
    end

    # Find the next workflows, starting in dir.
    #
    # === Parameters
    # dir(Dir):: directory to begin search in
    def find_next(dir)
      @logger.operation(:finding_next_workflow, "in #{dir.path}") do

        # Note: there could be multiple workflow definitions in one directory
        # so we need to record the current position whether we found a workflow
        # or not. The next iteration will search again in the current directory
        # event if we found one. If we don't find one then we call
        # 'search_dirs' which will recurse in the sub-directories.
        @stack << dir

        def_ext = RightScraper::Resources::Workflow::DEFINITION_EXT
        meta_ext = RightScraper::Resources::Workflow::METADATA_EXT
        potentials = Dir[File.join(dir.path, "*#{def_ext}")]
        potentials.reject! { |wdef| !File.exists?(wdef.chomp(File.extname(wdef)) + meta_ext) }
        potentials.reject! { |wdef| @known_workflows.include?(wdef) }
        unless potentials.empty?
          wdef = potentials.first
          relative_def = strip_repo_dir(wdef)
          @logger.operation(:reading_workflow, "#{relative_def}") do
            workflow = RightScraper::Resources::Workflow.new(@repository, relative_def)
            @builder.go(File.dirname(wdef), workflow)
            @known_workflows << wdef
            workflow
          end
        else
          search_dirs
        end
      end
    end

    # List of default scanners for this scaper
    #
    # === Return
    # Array<Scanner>:: Default scanners
    def default_scanners
      [RightScraper::Scanners::WorkflowMetadata,
        RightScraper::Scanners::WorkflowManifest]
    end

    # List of default builders for this scaper
    #
    # === Return
    # Array<Builder>:: Default builders
    def default_builders
      [RightScraper::Builders::Filesystem]
    end

    # self-register
    register_self
  end
end
