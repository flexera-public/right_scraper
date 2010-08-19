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

  shared_examples_for 'svn repositories' do
    it_should_behave_like 'generic repositories'

    it 'should have the right position' do
      parse_url(@repository, "/a")[:position].should == "/a"
    end
    it 'should have the appropriate credentials' do
      parse_url(@repository)[:username].should == @repository.first_credential
      parse_url(@repository)[:password].should == @repository.second_credential
    end
  end

  context 'with a SVN repository' do
    before(:each) do
      @repository = RightScale::Repository.from_hash(:display_name => 'test repo',
                                                     :repo_type => :svn,
                                                     :url => "http://a.site/foo/bar/baz",
                                                     :first_credential => "username",
                                                     :second_credential => "password")
    end

    it_should_behave_like 'svn repositories'

    it 'should have a tag' do
      parse_url(@repository)[:tag].should == "HEAD"
    end

    it 'should have a cookbook hash' do
      example_cookbook(@repository).cookbook_hash.should == 'bac54f7e9b87f35fd63f8f6e79f3428c374ddb10'
    end

    it 'should have a cookbook hash invariant under credential changes' do
      old_hash = example_cookbook(@repository).cookbook_hash
      @repository.first_credential = "b-key"
      example_cookbook(@repository).cookbook_hash.should == old_hash
    end

    it 'should have a cookbook hash that varies when the tag changes' do
      old_hash = example_cookbook(@repository).cookbook_hash
      @repository.tag = "tag"
      example_cookbook(@repository).cookbook_hash.should_not == old_hash
    end

    it 'should have a cookbook hash that varies when the position changes' do
      example_cookbook(@repository, "foo").cookbook_hash.should_not ==
        example_cookbook(@repository, "bar").cookbook_hash
    end
  end

  context 'with a SVN repository with a tag' do
    before(:each) do
      @repository = RightScale::Repository.from_hash(:display_name => 'test repo',
                                                     :repo_type => :svn,
                                                     :url => "http://a.site/foo/bar/baz",
                                                     :tag => "foo",
                                                     :first_credential => "username",
                                                     :second_credential => "password")
    end

    it_should_behave_like 'svn repositories'

    it 'should have a tag' do
      parse_url(@repository)[:tag].should == "foo"
    end
  end

  context 'when built from a Cookbook URL' do
    context 'for a SVN repository' do
      before(:each) do
        @url = "svn:http://username:password@baz.com/foo/bar/baz?a=z;a=b;q=blah;b=blah&p=foo#DEADBEEF"
        @cookbook = RightScale::Cookbook.from_url @url
      end
      it 'should resolve to a SVN repository' do
        @cookbook.repository.repo_type.should == :svn
      end
      it 'should have the same url (with sorted key/value pairs)' do
        @cookbook.repository.url.should == "http://baz.com/foo/bar/baz?a=b;a=z;b=blah;q=blah"
      end
      it 'should have a tag' do
        @cookbook.repository.tag.should == "DEADBEEF"
      end
      it 'should have the appropriate credentials' do
        @cookbook.repository.first_credential.should == "username"
        @cookbook.repository.second_credential.should == "password"
      end
      it 'should record the position' do
        @cookbook.position.should == "foo"
      end
    end

    context 'for a SVN repository with strange credentials' do
      before(:each) do
        @url = "svn:http://foo%3Ab%2Far:foo%40bar@baz.com/foo/bar/baz?a=z;a=b;q=blah;b=blah&p=foo#DEADBEEF"
        @cookbook = RightScale::Cookbook.from_url @url
      end
      it 'should have the same url (with sorted key/value pairs)' do
        @cookbook.repository.url.should == "http://baz.com/foo/bar/baz?a=b;a=z;b=blah;q=blah"
      end
      it 'should have the appropriate credentials' do
        @cookbook.repository.first_credential.should == "foo:b/ar"
        @cookbook.repository.second_credential.should == "foo@bar"
      end
    end

    context 'for a SVN repository with no tag' do
      before(:each) do
        @url = "svn:http://baz.com/foo/bar/baz?a=z;a=b;q=blah;b=blah&p=foo"
        @cookbook = RightScale::Cookbook.from_url @url
      end
      it 'should have the same url (with sorted key/value pairs)' do
        @cookbook.repository.url.should == "http://baz.com/foo/bar/baz?a=b;a=z;b=blah;q=blah"
      end
      it 'should point to HEAD' do
        @cookbook.repository.tag.should == "HEAD"
      end
    end

    context 'for a SVN repository with no credentials' do
      before(:each) do
        @url = "svn:http://baz.com/foo/bar/baz?a=z;a=b;q=blah;b=blah&p=foo"
        @cookbook = RightScale::Cookbook.from_url @url
      end
      it 'should have the same url (with sorted key/value pairs)' do
        @cookbook.repository.url.should == "http://baz.com/foo/bar/baz?a=b;a=z;b=blah;q=blah"
      end
      it 'should have no credentials' do
        @cookbook.repository.first_credential.should be_nil
        @cookbook.repository.second_credential.should be_nil
      end
    end

    context 'for a SVN repository with no position' do
      before(:each) do
        @url = "svn:http://baz.com/foo/bar/baz?a=z;a=b;q=blah;b=blah#foo"
        @cookbook = RightScale::Cookbook.from_url @url
      end
      it 'should have the same url (with sorted key/value pairs)' do
        @cookbook.repository.url.should == "http://baz.com/foo/bar/baz?a=b;a=z;b=blah;q=blah"
      end
      it 'should have no position' do
        @cookbook.position.should be_nil
      end
    end
  end
end
