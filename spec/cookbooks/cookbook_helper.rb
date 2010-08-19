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

require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'scraper_spec_helper_base'))
require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'lib', 'right_scraper'))
require 'uri'
require 'cgi'

module RightScale
  module CookbookHelper
    def parse_query(string)
      CGI::parse(string)
    end

    def unparse_query(hash)
      hash.map do |key, values|
        values.map {|value| CGI::escape(key) + "=" + CGI::escape(value)}.join(";")
      end.join(';')
    end

    def split_url(url)
      scheme, full_url = url.split(":", 2)
      uri = URI.parse(full_url)
      userinfo, query, tag = uri.select(:userinfo, :query, :fragment)
      unless userinfo.nil?
        username, password = userinfo.split(":", 2).map {|str| URI.unescape str}
        uri.user = nil
        uri.password = nil
      end
      unless query.nil?
        hash = CGI::parse(query)
        position = hash["p"][0]
        hash.delete("p")
        result = unparse_query(hash)
        if result == ""
          uri.query = nil
        else
          uri.query = result
        end
      end
      uri.fragment = nil unless tag.nil?
      {:scheme => scheme,
        :url => uri.to_s,
        :username => username,
        :password => password,
        :position => position,
        :tag => tag}
    end

    def example_cookbook(repository, position=nil)
      @helper = RightScale::ScraperSpecHelperBase.new if @helper.nil?
      RightScale::Cookbook.new(repository, "", @helper.repo_content, position)
    end

    def parse_url(*args)
      split_url(example_cookbook(*args).to_url)
    end

    shared_examples_for 'generic repositories' do
      it 'should have the right scheme' do
        parse_url(@repository)[:scheme].should == @repository.repo_type.to_s
      end
      it 'should have the same url' do
        parse_url(@repository)[:url].should == @repository.url
      end
    end
  end
end
