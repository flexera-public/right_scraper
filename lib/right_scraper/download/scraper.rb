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
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'checkout_scraper_base'))
require 'curb'
require 'libarchive_ruby'

module RightScale
  class DownloadScraper < ScraperBase
    def initialize(*args)
      super(*args)
      @done = false
    end
    # Return the position of the scraper.  This always returns true,
    # because we only support one cookbook per tarball and so it is
    # always at the same position.
    def position
      true
    end

    # Seek to the given position.  This is a noop, because we only
    # support one cookbook per tarball and so it is always at the same
    # position.
    def seek(position)
      true
    end

    def is_useful?(credential)
      credential && !credential.strip.empty?
    end
    def useful_part(credential)
      credential.strip
    end
    def next
      return nil if @done

      archive = @logger.operation(:downloading) do
        Curl::Easy.http_get(@repository.url) { |curl|
          if is_useful?(@repository.first_credential) && is_useful?(@repository.second_credential)
            curl.http_auth_types = [:any]
            curl.timeout = @max_seconds if @max_seconds
            # Curl::Easy doesn't support bailing if too large
            curl.username = useful_part(@repository.first_credential)
            curl.password = useful_part(@repository.second_credential)
          end
        }.body_str
      end

      cookbook = RightScale::Cookbook.new(@repository, archive, nil, position)

      @logger.operation(:reading_metadata) do
        Archive.read_open_memory(archive) do |ar|
          while entry = ar.next_header
            if File.basename(entry.pathname) == "metadata.json"
              cookbook.metadata = JSON.parse(ar.read_data)
              @done = true
              return cookbook
            end
          end
        end
      end

      raise "No metadata found for {#repository}"
    end
  end
end
