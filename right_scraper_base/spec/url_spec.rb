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

describe RightScale::Repository do
  def make_repo(url)
    @repo = RightScale::Repository.from_hash(:display_name => 'test repo',
                                             :repo_type => :download,
                                             :url => url,
                                             :first_credential => "foo:b/ar",
                                             :second_credential => "foo@bar")
  end
  before(:each) do
    @oldtest = ENV['DEVELOPMENT']
  end
  after(:each) do
    if @oldtest.nil?
      ENV.delete('DEVELOPMENT')
    else
      ENV['DEVELOPMENT'] = @oldtest
    end
  end

  context 'in production mode' do
    before(:each) do
      ENV.delete('DEVELOPMENT')
    end

    it 'should not throw an error when creating a repository for a normal URI' do
      lambda do
        make_repo "http://rightscale.com/%20CBLAH"
      end.should_not raise_exception
      lambda do
        make_repo "http://172.12.3.42/%20CBLAH"
      end.should_not raise_exception
      lambda do
        make_repo "http://110.12.3.42/%20CBLAH"
      end.should_not raise_exception
    end

    it 'should refuse to create repositories for hosts that don\'t exist' do
      lambda do
        make_repo "http://nonexistent.invalid/%20CBLAH"
      end.should raise_exception(RuntimeError, /Invalid URI/)
    end

    it 'should refuse to create repositories for private networks' do
      ["10.0.2.43", "172.18.3.42", "192.168.4.2"].each do |ip|
        lambda do
          make_repo "http://#{ip}/%20CBLAH"
        end.should raise_exception(RuntimeError, /Invalid URI/)
      end
    end

    it 'should refuse to create repositories for loopback addresses' do
      lambda do
        make_repo "http://localhost/%20CBLAH"
      end.should raise_exception(RuntimeError, /Invalid URI/)
      lambda do
        make_repo "http://127.0.0.1/%20CBLAH"
      end.should raise_exception(RuntimeError, /Invalid URI/)
      lambda do
        make_repo "http://127.3.2.1/%20CBLAH"
      end.should raise_exception(RuntimeError, /Invalid URI/)
    end

    it 'should refuse to create repositories for file:/// URIs' do
      lambda do
        make_repo "file://var/run/something/%20CBLAH"
      end.should raise_exception(RuntimeError, /Invalid URI/)
    end

    it 'should refuse to create repositories for our EC2 metadata server' do
      lambda do
        make_repo "http://169.254.169.254/%20CBLAH"
      end.should raise_exception(RuntimeError, /Invalid URI/)
    end

    it 'should refuse to create repositories for even valid IPv6 addresses' do
      lambda do
        make_repo "http://[::ffff:128.111.1.1]/%20CBLAH"
      end.should raise_exception(RuntimeError, /Invalid URI/)
    end
  end

  context 'in development mode' do
    before(:each) do
      ENV['DEVELOPMENT'] = "yes"
    end

    it 'should not throw an error when creating a repository for a normal URI' do
      lambda do
        make_repo "http://rightscale.com/%20CBLAH"
      end.should_not raise_exception
    end

    it 'should create repositories for hosts that don\'t exist' do
      lambda do
        make_repo "http://nonexistent.invalid/%20CBLAH"
      end.should_not raise_exception
    end

    it 'should create repositories for private networks' do
      ["10.0.2.43", "172.18.3.42", "192.168.4.2"].each do |ip|
        lambda do
          make_repo "http://#{ip}/%20CBLAH"
        end.should_not raise_exception
      end
    end

    it 'should create repositories for loopback addresses' do
      lambda do
        make_repo "http://localhost/%20CBLAH"
      end.should_not raise_exception
      lambda do
        make_repo "http://127.0.0.1/%20CBLAH"
      end.should_not raise_exception
      lambda do
        make_repo "http://127.3.2.1/%20CBLAH"
      end.should_not raise_exception
    end

    it 'should create repositories for file:/// URIs' do
      lambda do
        make_repo "file://var/run/something/%20CBLAH"
      end.should_not raise_exception
    end

    it 'should create repositories for our EC2 metadata server' do
      lambda do
        make_repo "http://169.254.169.254/%20CBLAH"
      end.should_not raise_exception
    end

    it 'should create repositories for even valid IPv6 addresses' do
      lambda do
        make_repo "http://[::ffff:128.111.1.1]/%20CBLAH"
      end.should_not raise_exception
    end
  end
end
