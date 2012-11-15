#--  -*- mode: ruby; encoding: utf-8 -*-
# Copyright: Copyright (c) 2011 RightScale, Inc.
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
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib', 'right_scraper'))


module RightScraper::Scanners
  describe CookbookManifest do
    it 'should accumulate files' do
      resource = flexmock(:resource)
      resource.should_receive(:manifest=).with({"foo" => Digest::MD5.hexdigest("bar"),
                                                 "baz" => Digest::MD5.hexdigest("quux")
                                               }).once
      manifest = CookbookManifest.new
      manifest.notice("foo") { "bar" }
      manifest.notice("baz") { "quux" }
      manifest.end(resource)
    end
    it 'should keep different resources separated' do
      resource = flexmock(:resource)
      resource.should_receive(:manifest=).with({"foo" => Digest::MD5.hexdigest("bar"),
                                                 "baz" => Digest::MD5.hexdigest("quux")
                                               }).once
      resource.should_receive(:manifest=).with({"bar" => Digest::MD5.hexdigest("fred")
                                               }).once
      manifest = CookbookManifest.new
      manifest.notice("foo") { "bar" }
      manifest.notice("baz") { "quux" }
      manifest.end(resource)
      manifest.notice("bar") { "fred" }
      manifest.end(resource)
    end
  end
end
