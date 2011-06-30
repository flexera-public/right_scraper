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

describe RightScraper::Repositories::Svn do
  include RightScraper::SpecHelpers::DevelopmentModeEnvironment

  before(:each) do
    @repo = RightScraper::Repository.from_hash(:display_name => 'test repo',
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
    @repo.checkout_hash.should ==
      Digest::SHA1.hexdigest("1\000svn\000http://foo.bar.baz.quux/%20CBLAH\000foo")
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
