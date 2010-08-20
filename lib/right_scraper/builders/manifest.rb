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

require File.expand_path(File.join(File.dirname(__FILE__), 'base'))
require 'json'
require 'digest/sha1'

module RightScale
  class ManifestBuilder < Builder
    def initialize(options={})
      super
      @scraper = options.fetch(:scraper)
    end

    def go(dir, cookbook)
      @logger.operation(:creating_manifest) do
        cookbook.manifest = make_manifest(dir)
      end
    end

    def make_manifest(path)
      hash = {}
      scan(Dir.new(path), hash, nil)
      hash
    end

    def scan(directory, hash, position)
      directory.each do |entry|
        next if entry == '.' || entry == '..'
        next if @scraper.ignorable?(entry)

        fullpath = File.join(directory.path, entry)
        relative_position = position ? File.join(position, entry) : entry

        if File.directory?(fullpath)
          scan(Dir.new(fullpath), hash, relative_position)
        else
          digest = Digest::SHA1.new
          open(fullpath) do |f|
            digest << f.read(2048) until f.eof?
          end
          hash[relative_position] = digest.hexdigest
        end
      end
    end
    private :scan
  end
end
