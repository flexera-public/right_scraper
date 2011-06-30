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
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib', 'right_scraper_base'))
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib', 'right_scraper_base', 'repositories', 'mock'))

describe RightScraper::Repository do
  include RightScraper::SpecHelpers::DevelopmentModeEnvironment

  context 'with a repository type that doesn\'t exist' do
    it 'should throw a comprehensible error when you try to create it' do
      lambda {
        RightScraper::Repository.from_hash(:display_name      => 'display_name',
                                           :repo_type         => :nonexistent,
                                           :url               => 'url',
                                           :tag               => 'tag',
                                           :first_credential  => 'first_credential',
                                           :second_credential => 'second_credential')
      }.should raise_error(/Can't understand how to make nonexistent repos/)
    end
  end

  context 'with a mock repository' do
    before(:each) do
      @repo = RightScraper::Repository.from_hash(:display_name      => 'display_name',
                                                 :repo_type         => :mock,
                                                 :url               => 'url',
                                                 :tag               => 'tag',
                                                 :first_credential  => 'first_credential',
                                                 :second_credential => 'second_credential')
    end

    it 'should be initializable from a hash' do
      @repo.should be_kind_of(RightScraper::Repository)
      @repo.display_name.should      == 'display_name'
      @repo.repo_type.should         == :mock
      @repo.url.should               == 'url'
      @repo.tag.should               == 'tag'
      @repo.first_credential.should  == 'first_credential'
      @repo.second_credential.should == 'second_credential'
    end

    it 'should know the SHA-1 of its root location' do
      @repo.repository_hash.should ==
        Digest::SHA1.hexdigest("1\000mock\000url")
    end

    it 'should know the SHA-1 of the identifier for this specific checkout' do
      @repo.checkout_hash.should ==
        Digest::SHA1.hexdigest("1\000mock\000url")
    end
  end
end

describe RightScraper::Repositories::Download do
  include RightScraper::SpecHelpers::DevelopmentModeEnvironment

  before(:each) do
    @repo = RightScraper::Repository.from_hash(:display_name => 'test repo',
                                               :repo_type => :download,
                                               :url => "http://foo.bar.baz.quux/%20CBLAH",
                                               :tag => "412530982323",
                                               :first_credential => "foo:b/ar",
                                               :second_credential => "foo@bar")
  end

  it 'should have a tag' do
    @repo.tag.should == '412530982323'
  end

  it 'should include the tag in the checkout hash' do
    @repo.checkout_hash.should_not == @repo.repository_hash
    oldhash = @repo.checkout_hash
    @repo.tag = "42398"
    @repo.checkout_hash.should_not == oldhash
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
