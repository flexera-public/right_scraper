#--
# Copyright: Copyright (c) 2010-2013 RightScale, Inc.
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

describe RightScraper::Repositories::Base do
  include RightScraper::SpecHelpers::DevelopmentModeEnvironment

  context 'with a repository type that doesn\'t exist' do
    let(:unknown_type) { :nonexistent }

    it 'should throw a comprehensible error when you try to create it' do
      lambda {
        RightScraper::Repositories::Base.from_hash(:display_name      => 'display_name',
                                           :repo_type         => :nonexistent,
                                           :url               => 'url',
                                           :tag               => 'tag',
                                           :first_credential  => 'first_credential',
                                           :second_credential => 'second_credential')
      }.should raise_error(
        ::RightScraper::RegisteredBase::RegisteredTypeError,
        "Unknown registered type: #{unknown_type.to_s.inspect}")
    end
  end
end

describe RightScraper::Repositories::Download do
  include RightScraper::SpecHelpers::DevelopmentModeEnvironment

  before(:each) do
    @repo = RightScraper::Repositories::Base.from_hash(:display_name => 'test repo',
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
