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

describe RightScraper::Repository do
  def make_repo(url)
    @repo = RightScraper::Repository.from_hash(:display_name => 'test repo',
                                             :repo_type => :git,
                                             :url => url,
                                             :first_credential => "foo")
  end
  include RightScraper::SpecHelpers::ProductionModeEnvironment

  context 'with Git URIs' do
    it 'should not throw an error for http URIs' do
      lambda do
        make_repo "http://rightscale.com/%20CBLAH"
      end.should_not raise_exception
    end
    it 'should not throw an error for git URIs' do
      lambda do
        make_repo "git://rightscale.com/%20CBLAH"
      end.should_not raise_exception
    end
    it 'should not throw an error for absolute SCP URIs' do
      lambda do
        make_repo "git@rightscale.com:/%20CBLAH"
      end.should_not raise_exception
    end
    it 'should not throw an error for SCP URIs with dashes in the username' do
      lambda do
        make_repo "git-foo@rightscale.com:/%20CBLAH"
      end.should_not raise_exception
    end
    it 'should not throw an error for relative SCP URIs' do
      lambda do
        make_repo "git-foo@rightscale.com:%20CBLAH"
      end.should_not raise_exception
    end
    it 'should not throw an error for git+ssh URIs' do
      lambda do
        make_repo "git+ssh://rightscale.com/%20CBLAH"
      end.should_not raise_exception
    end
    it 'should not throw an error for ssh URIs' do
      lambda do
        make_repo "ssh://rightscale.com/%20CBLAH"
      end.should_not raise_exception
    end
  end

  context '#to_url' do
    it 'should correctly convert http URIs' do
      make_repo("http://rightscale.com/%20CBLAH").to_url.to_s.should ==
        "http://foo@rightscale.com/%20CBLAH"
    end
    it 'should correctly convert git URIs' do
      make_repo("git://rightscale.com/%20CBLAH").to_url.to_s.should ==
        "git://foo@rightscale.com/%20CBLAH"
    end
    it 'should correctly convert SCP URIs' do
      make_repo("git@rightscale.com:/%20CBLAH").to_url.to_s.should ==
        "ssh://git:foo@rightscale.com/%20CBLAH"
    end
    it 'should correctly convert SCP URIs with dashes in the username' do
      make_repo("git-foo@rightscale.com:/%20CBLAH").to_url.to_s.should ==
        "ssh://git-foo:foo@rightscale.com/%20CBLAH"
    end
    it 'should correctly convert relative SCP URIs' do
      make_repo("git-foo@rightscale.com:%20CBLAH").to_url.to_s.should ==
        "ssh://git-foo:foo@rightscale.com/%20CBLAH"
    end
    it 'should correctly convert git+ssh URIs' do
      make_repo("git+ssh://rightscale.com/%20CBLAH").to_url.to_s.should ==
        "git+ssh://foo@rightscale.com/%20CBLAH"
    end
    it 'should correctly convert ssh URIs' do
      make_repo("ssh://rightscale.com/%20CBLAH").to_url.to_s.should ==
        "ssh://foo@rightscale.com/%20CBLAH"
    end
  end
end
