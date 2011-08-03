#--
# Copyright: Copyright (c) 2010-2011 RightScale, Inc.
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

require File.expand_path(File.join(File.dirname(__FILE__), 'retriever_spec_helper'))
require 'uri'
require 'cgi'

module RightScraper
  module CookbookHelper

   def example_cookbook(repository, position=nil)
      @helper = RightScraper::RetrieverSpecHelper.new if @helper.nil?
      RightScraper::Resources::Cookbook.new(@repository, position)
    end

    def parse_url(repository)
      uri = URI.parse(repository.url)
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
        result = hash.map do |key, values|
          values.map {|value| CGI::escape(key) + "=" + CGI::escape(value)}.join(";")
        end.join(';')
 
        if result == ""
          uri.query = nil
        else
          uri.query = result
        end
      end
      uri.fragment = nil unless tag.nil?
      { :url => uri.to_s,
        :username => username,
        :password => password,
        :position => position,
        :tag => tag}
    end

    shared_examples_for 'a generic repository' do
      it 'should have the same url' do
        parse_url(@repository)[:url].should == @repository.url
      end
    end

  end
end
