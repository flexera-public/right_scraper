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
require 'right_scraper/scrapers'

module RightScraper::Scrapers

  # Chef cookbook scraper
  class Cookbook < ::RightScraper::Scrapers::Base
    COOKBOOK_SENTINELS = ['metadata.json', 'metadata.rb']

    # Find the next cookbook, starting in dir.
    #
    # === Parameters
    # dir(Dir):: directory to begin search in
    def find_next(dir)
      @logger.operation(:finding_next_cookbook, "in #{dir.path}") do
        if COOKBOOK_SENTINELS.any? { |f| File.exists?(File.join(dir.path, f)) }
          @logger.operation(:reading_cookbook, "from #{dir.path}") do
            cookbook = RightScraper::Resources::Cookbook.new(
              @repository,
              strip_repo_dir(dir.path),
              repo_dir)
            @builder.go(dir.path, cookbook)
            cookbook
          end
        else
          @stack << dir
          search_dirs
        end
      end
    end

    # List of default scanners for this scaper
    #
    # === Return
    # Array<Scanner>:: Default scanners
    def default_scanners
      [RightScraper::Scanners::CookbookMetadata,
        RightScraper::Scanners::CookbookManifest]
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
