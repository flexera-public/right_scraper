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
require File.expand_path(File.join(File.dirname(__FILE__), 'cookbook_helper'))

describe RightScale::Cookbook do
  include RightScale::CookbookHelper

  shared_examples_for 'download repositories' do
    it_should_behave_like 'generic repositories'

    it 'should have no tag' do
      parse_url(@repository)[:tag].should be_nil
    end
    it 'should have no position' do
      parse_url(@repository)[:position].should be_nil
    end
    it 'should have the appropriate credentials' do
      parse_url(@repository)[:username].should == @repository.first_credential
      parse_url(@repository)[:password].should == @repository.second_credential
    end
  end

  context 'with a download repository' do
    before(:each) do
      @repository = RightScale::Repository.from_hash(:display_name => 'test repo',
                                                     :repo_type => :download,
                                                     :url => "http://a.site/foo/bar/baz",
                                                     :first_credential => "user",
                                                     :second_credential => "password")
    end

    it_should_behave_like 'download repositories'
  end

  context 'with a download repository with a port' do
    before(:each) do
      @repository = RightScale::Repository.from_hash(:display_name => 'test repo',
                                                     :repo_type => :download,
                                                     :url => "http://a.site:23/foo/bar/baz",
                                                     :first_credential => "user",
                                                     :second_credential => "password")
    end

    it_should_behave_like 'download repositories'
  end

  context 'with a download repository with just a user' do
    before(:each) do
      @repository = RightScale::Repository.from_hash(:display_name => 'test repo',
                                                     :repo_type => :download,
                                                     :url => "http://a.site/foo/bar/baz",
                                                     :first_credential => "user")
    end

    it_should_behave_like 'download repositories'
  end

  context 'with a weird download repository' do
    before(:each) do
      @repository = RightScale::Repository.from_hash(:display_name => 'test repo',
                                                     :repo_type => :download,
                                                     :url => "urn:a.site:stuff")
    end

    it_should_behave_like 'download repositories'
  end

  context 'with a malicious download repository' do
    before(:each) do
      @repository = RightScale::Repository.from_hash(:display_name => 'test repo',
                                                     :repo_type => :download,
                                                     :url => "http://foo.bar.baz.quux/%20CBLAH",
                                                     :first_credential => "foo:b/ar",
                                                     :second_credential => "foo@bar")
    end

    it_should_behave_like 'download repositories'
  end

  context 'with a download repository that includes a query' do
    before(:each) do
      @repository = RightScale::Repository.from_hash(:display_name => 'test repo',
                                                     :repo_type => :download,
                                                     :url => "http://foo.bar.baz.quux/stuff?q=bar")
    end

    it_should_behave_like 'download repositories'
  end

  context 'when built from a Cookbook URL' do
    context 'for a download repository' do
      before(:each) do
        @url = "download:http://foo:bar@baz.com/foo/bar/baz?q=blah"
        @cookbook = RightScale::Cookbook.from_url @url
      end
      it 'should resolve to a download repository' do
        @cookbook.repository.repo_type.should == :download
      end
      it 'should have the same url' do
        @cookbook.repository.url.should == "http://baz.com/foo/bar/baz?q=blah"
      end
      it 'should have the appropriate credentials' do
        @cookbook.repository.first_credential.should == "foo"
        @cookbook.repository.second_credential.should == "bar"
      end
    end

    context 'for a download repository with strange credentials' do
      before(:each) do
        @url = "download:http://foo%3Ab%2Far:foo%40bar@baz.com/foo/bar/baz?q=blah"
        @cookbook = RightScale::Cookbook.from_url @url
      end
      it 'should resolve to a download repository' do
        @cookbook.repository.repo_type.should == :download
      end
      it 'should have the same url' do
        @cookbook.repository.url.should == "http://baz.com/foo/bar/baz?q=blah"
      end
      it 'should have the appropriate credentials' do
        @cookbook.repository.first_credential.should == "foo:b/ar"
        @cookbook.repository.second_credential.should == "foo@bar"
      end
    end
  end
end
