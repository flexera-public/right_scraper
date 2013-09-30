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
require 'right_scraper/resources'

require 'digest/md5'
require 'json'
require 'right_support'

module RightScraper::Resources
  class Cookbook < ::RightScraper::Resources::Base

    EMPTY_MANIFEST_JSON = ::JSON.dump(:manifest => {}).freeze

    # @return [String] repo_dir as local repo root dir (sans relative cookbook pos path)
    attr_reader :repo_dir

    def initialize(repo, pos, repo_dir)
      super(repo, pos)
      @repo_dir = repo_dir
    end

    def manifest=(value)
      @manifest_json = nil
      @resource_hash = nil
      @manifest      = value
    end

    def manifest_json
      unless @manifest_json
        if manifest && !manifest.empty?
          # note that we are preserving the :manifest key at the root only to
          # avoid having to change how the manifest is interpreted by Repose.
          manifest_hash = { :manifest => manifest }
          @manifest_json = ::RightSupport::Data::HashTools.deep_sorted_json(manifest_hash, pretty=true).freeze
        else
          @manifest_json = EMPTY_MANIFEST_JSON
        end
      end
      @manifest_json
    end

    def resource_hash
      unless @resource_hash
        @resource_hash = ::Digest::MD5.hexdigest(manifest_json).freeze
      end
      @resource_hash
    end

  end
end
