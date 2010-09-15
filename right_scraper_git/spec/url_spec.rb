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

describe RightScale::Repository do
  def make_repo(url)
    @repo = RightScale::Repository.from_hash(:display_name => 'test repo',
                                             :repo_type => :git,
                                             :url => url,
                                             :first_credential => "foo:b/ar")
  end
  it_should_behave_like "Production mode environment"

  it 'should not throw an error when creating a repository for Git URIs' do
    lambda do
      make_repo "http://rightscale.com/%20CBLAH"
    end.should_not raise_exception
    lambda do
      make_repo "git://rightscale.com/%20CBLAH"
    end.should_not raise_exception
    lambda do
      make_repo "git+ssh://rightscale.com/%20CBLAH"
    end.should_not raise_exception
    lambda do
      make_repo "ssh://rightscale.com/%20CBLAH"
    end.should_not raise_exception
  end
end
