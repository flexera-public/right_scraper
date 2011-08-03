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

require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'cookbook_helper'))

describe RightScraper::Resources::Cookbook do
  include RightScraper::SpecHelpers::DevelopmentModeEnvironment

  include RightScraper::CookbookHelper

  shared_examples_for 'svn repositories' do
    it_should_behave_like 'a generic repository'

    it 'should have the appropriate credentials' do
      @repository.username.should == 'username'
      @repository.password.should == 'password'
    end
  end

  context 'with a SVN repository' do
    before(:each) do
      @repository = RightScraper::Repositories::Svn.from_hash(:display_name => 'test repo',
                                                     :repo_type => :svn,
                                                     :url => "http://a.site/foo/bar/baz",
                                                     :first_credential => "username",
                                                     :second_credential => "password")
    end

    it_should_behave_like 'svn repositories'

    it 'should have a tag' do
      @repository.tag.should == "HEAD"
    end

    it 'should have a cookbook hash' do
      repo_hash = Digest::SHA1.hexdigest("1\000svn\000http://a.site/foo/bar/baz\000HEAD")
      example_cookbook(@repository).resource_hash.should ==
        Digest::SHA1.hexdigest("1\000#{repo_hash}\000")
    end

    it 'should have a cookbook hash invariant under credential changes' do
      old_hash = example_cookbook(@repository).resource_hash
      @repository.first_credential = "b-key"
      example_cookbook(@repository).resource_hash.should == old_hash
    end

    it 'should have a cookbook hash that varies when the tag changes' do
      old_hash = example_cookbook(@repository).resource_hash
      @repository.tag = "tag"
      example_cookbook(@repository).resource_hash.should_not == old_hash
    end

    it 'should have a cookbook hash that varies when the position changes' do
      example_cookbook(@repository, "foo").resource_hash.should_not ==
        example_cookbook(@repository, "bar").resource_hash
    end
  end

  context 'with a SVN repository with a tag' do
    before(:each) do
      @repository = RightScraper::Repositories::Svn.from_hash(:display_name => 'test repo',
                                                     :repo_type => :svn,
                                                     :url => "http://a.site/foo/bar/baz",
                                                     :tag => "foo",
                                                     :first_credential => "username",
                                                     :second_credential => "password")
    end

    it_should_behave_like 'svn repositories'

    it 'should have a tag' do
      @repository.tag.should == "foo"
    end
  end

end
