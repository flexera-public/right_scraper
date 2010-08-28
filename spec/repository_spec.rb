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

require File.expand_path(File.join(File.dirname(__FILE__), 'spec_helper'))
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib', 'right_scraper'))
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib', 'right_scraper', 'repositories', 'mock'))

describe RightScale::Repository do
  before(:each) do
    @repo = RightScale::Repository.from_hash(:display_name      => 'display_name',
                                             :repo_type         => :mock,
                                             :url               => 'url',
                                             :tag               => 'tag',
                                             :first_credential  => 'first_credential',
                                             :second_credential => 'second_credential')
  end

  it 'should be initializable from a hash' do
    @repo.should be_kind_of(RightScale::Repository)
    @repo.display_name.should      == 'display_name'
    @repo.repo_type.should         == :mock
    @repo.url.should               == 'url'
    @repo.tag.should               == 'tag'
    @repo.first_credential.should  == 'first_credential'
    @repo.second_credential.should == 'second_credential'
  end

  it 'should know the SHA-1 of its root location' do
    @repo.repository_hash.should == 'fa8b5c4ab1d1a9731eeae937ed29ae31cbe811e5'
  end

  it 'should know the SHA-1 of the identifier for this specific checkout' do
    @repo.checkout_hash.should == 'fa8b5c4ab1d1a9731eeae937ed29ae31cbe811e5'
  end
end

describe RightScale::Repositories::Download do
  before(:each) do
    @repo = RightScale::Repository.from_hash(:display_name => 'test repo',
                                             :repo_type => :download,
                                             :url => "http://foo.bar.baz.quux/%20CBLAH",
                                             :first_credential => "foo:b/ar",
                                             :second_credential => "foo@bar")
  end

  it 'should have the same repository hash with or without credentials' do
    initial_hash = @repo.repository_hash
    @repo.first_credential = nil
    @repo.second_credential = nil
    @repo.repository_hash.should == initial_hash
  end

  it 'should have the same checkout hash with or without credentials' do
    initial_hash = @repo.checkout_hash
    @repo.first_credential = nil
    @repo.second_credential = nil
    @repo.checkout_hash.should == initial_hash
  end
end

describe RightScale::Repositories::Svn do
  before(:each) do
    @repo = RightScale::Repository.from_hash(:display_name => 'test repo',
                                             :repo_type => :svn,
                                             :url => "http://foo.bar.baz.quux/%20CBLAH",
                                             :tag => 'foo',
                                             :first_credential => "foo:b/ar",
                                             :second_credential => "foo@bar")
  end

  it 'should have the same repository hash with or without credentials' do
    initial_hash = @repo.repository_hash
    @repo.first_credential = nil
    @repo.second_credential = nil
    @repo.repository_hash.should == initial_hash
  end

  it 'should have the same checkout hash with or without credentials' do
    initial_hash = @repo.checkout_hash
    @repo.first_credential = nil
    @repo.second_credential = nil
    @repo.checkout_hash.should == initial_hash
  end

  it 'should have a checkout hash' do
    @repo.checkout_hash.should == '37023a219be58f4ee69eb1cb2960c5ce908e15da'
  end

  it 'should have a different checkout hash from repository hash' do
    @repo.repository_hash.should_not == @repo.checkout_hash
  end

  it 'should have the same repository hash regardless of tag' do
    initial_hash = @repo.repository_hash
    @repo.tag = 'bar'
    @repo.repository_hash.should == initial_hash
  end

  it 'should have different checkout hashes as tags change' do
    initial_hash = @repo.checkout_hash
    @repo.tag = 'bar'
    @repo.checkout_hash.should_not == initial_hash
  end
end

describe RightScale::Repositories::Git do
  before(:each) do
    @repo = RightScale::Repository.from_hash(:display_name => 'test repo',
                                             :repo_type => :git,
                                             :url => "http://foo.bar.baz.quux/%20CBLAH",
                                             :tag => 'foo',
                                             :first_credential => "foo:b/ar")
  end

  it 'should have the same repository hash with or without credentials' do
    initial_hash = @repo.repository_hash
    @repo.first_credential = nil
    @repo.repository_hash.should == initial_hash
  end

  it 'should have the same checkout hash with or without credentials' do
    initial_hash = @repo.checkout_hash
    @repo.first_credential = nil
    @repo.checkout_hash.should == initial_hash
  end

  it 'should have a checkout hash' do
    @repo.checkout_hash.should == '9985f68cc380c3f57315fb4055b469b643115382'
  end

  it 'should have a different checkout hash from repository hash' do
    @repo.repository_hash.should_not == @repo.checkout_hash
  end

  it 'should have the same repository hash regardless of tag' do
    initial_hash = @repo.repository_hash
    @repo.tag = 'bar'
    @repo.repository_hash.should == initial_hash
  end

  it 'should have different checkout hashes as tags change' do
    initial_hash = @repo.checkout_hash
    @repo.tag = 'bar'
    @repo.checkout_hash.should_not == initial_hash
  end
end
