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

  shared_examples_for 'git repositories' do
    it_should_behave_like 'generic repositories'

    it 'should have the right position' do
      parse_url(@repository, "/a")[:position].should == "/a"
    end
    it 'should have the appropriate credentials' do
      parse_url(@repository)[:username].should == @repository.first_credential
      parse_url(@repository)[:password].should be_nil
    end
  end

  context 'with a git repository' do
    before(:each) do
      @repository = RightScale::Repository.from_hash(:display_name => 'test repo',
                                                     :repo_type => :git,
                                                     :url => "http://a.site/foo/bar/baz",
                                                     :first_credential => "a-key")
    end

    it_should_behave_like 'git repositories'

    it 'should have a tag' do
      parse_url(@repository)[:tag].should == "master"
    end
  end
  context 'with a git repository with a tag' do
    before(:each) do
      @repository = RightScale::Repository.from_hash(:display_name => 'test repo',
                                                     :repo_type => :git,
                                                     :url => "http://a.site/foo/bar/baz",
                                                     :tag => "DEADBEEF",
                                                     :first_credential => "a-key")
    end

    it_should_behave_like 'git repositories'

    it 'should have a tag' do
      parse_url(@repository)[:tag].should == "DEADBEEF"
    end
  end

  context 'when built from a Cookbook URL' do
    context 'for a git repository with a tag' do
      before(:each) do
        @url = "git:http://sshkey@baz.com/foo/bar/baz?a=z;a=b;q=blah;b=blah&p=foo#DEADBEEF"
        @cookbook = RightScale::Cookbook.from_url @url
      end
      it 'should resolve to a git repository' do
        @cookbook.repository.repo_type.should == :git
      end
      it 'should have the same url (with sorted key/value pairs)' do
        @cookbook.repository.url.should == "http://baz.com/foo/bar/baz?a=b;a=z;b=blah;q=blah"
      end
      it 'should have a tag' do
        @cookbook.repository.tag.should == "DEADBEEF"
      end
      it 'should have the appropriate credentials' do
        @cookbook.repository.first_credential.should == "sshkey"
      end
      it 'should record the position' do
        @cookbook.position.should == "foo"
      end
    end
    context 'for a git repository without a tag' do
      before(:each) do
        @url = "git:http://sshkey@baz.com/foo/bar/baz?q=blah;b=blah&p=foo"
        @cookbook = RightScale::Cookbook.from_url @url
      end
      it 'should point to master' do
        @cookbook.repository.tag.should == "master"
      end
    end
    context 'for a git repository without a position' do
      before(:each) do
        @url = "git:http://sshkey@baz.com/foo/bar/baz?b=blah;q=blah"
        @cookbook = RightScale::Cookbook.from_url @url
      end
      it 'should not have a position' do
        @cookbook.position.should be_nil
      end
    end
  end
end
