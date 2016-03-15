#--
# Copyright: Copyright (c) 2016 RightScale, Inc.
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

module RightScraper::Scanners

  # Loads existing cookbook metadata from a filesystem.
  class CookbookMetadataReadOnly < CookbookMetadata

    # Notice a file during scanning.
    #
    # === Block
    # Return the data for this file.  We use a block because it may
    # not always be necessary to read the data.
    #
    # === Parameters
    # relative_position(String):: relative pathname for the file from root of cookbook
    def notice(relative_position, &blk)
      case relative_position
      when JSON_METADATA
        # preferred over RUBY_METADATA.
        @read_blk = blk
      when RUBY_METADATA
        # defer to any JSON_METADATA, which we hope refers to the same info.
        @read_blk ||= self.method(:generated_metadata_json_readonly)
      end
      true
    end

    private

    # Reads the existing generated 'metadata.json' or else fails.
    #
    # === Returns
    # @return [String] metadata JSON text
    def generated_metadata_json_readonly
      @logger.operation(:metadata_readonly) do
        # path constants
        freed_metadata_dir = (@cookbook.pos == '.' && freed_dir) || ::File.join(freed_dir, @cookbook.pos)
        freed_metadata_json_path = ::File.join(freed_metadata_dir, JSON_METADATA)

        # in the multi-pass case we will run this scanner only on the second
        # and any subsequent passed, which are outside of containment. the
        # metadata must have already been generated at this point or else it
        # should be considered an internal error.
        return ::File.read(freed_metadata_json_path)
      end
    end

  end # CookbookMetadataReadOnly
end # RightScraper::Scanners
