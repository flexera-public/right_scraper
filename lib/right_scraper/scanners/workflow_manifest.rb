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

require 'digest/sha1'

module RightScraper::Scanners

  # Build manifests from a filesystem.
  class WorkflowManifest < ::RightScraper::Scanners::Base
    # Create a new manifest scanner.  Does not accept any new arguments.
    def initialize(*args)
      super
      @manifest = {}
    end

    # Retrieve relative workflow files positions
    #
    # === Parameters
    # workflow(Resources::Workflow):: Workflow whose manifest is being built
    def begin(workflow)
      @workflow = workflow
      @metadata_filename = File.basename(@workflow.metadata_path)
      @definition_filename = File.basename(@workflow.definition_path)
    end

    # Complete a scan for the given resource.
    #
    # === Parameters ===
    # resource(RightScraper::Resources::Base):: resource to scan
    def end(resource)
      resource.manifest = @manifest
      @manifest = {}
    end

    # Notice a file during scanning.
    #
    # === Block ===
    # Return the data for this file.  We use a block because it may
    # not always be necessary to read the data.
    #
    # === Parameters ===
    # relative_position(String):: relative pathname for file from root of resource
    def notice(relative_position)
      if [ @metadata_filename, @definition_filename ].include?(relative_position)
        @manifest[relative_position] = Digest::SHA1.hexdigest(yield)
      end
    end

    # Notice a directory during scanning.  Since the workflow definition and
    # metadata live in the root directory we don't need to recurse,
    # but we do need to go into the first directory (identified by
    # +relative_position+ being +nil+).
    #
    # === Parameters
    # relative_position(String):: relative pathname for the directory from root of workflow
    #
    # === Returns
    # Boolean:: should the scanning recurse into the directory
    def notice_dir(relative_position)
      relative_position == nil
    end

  end
end
