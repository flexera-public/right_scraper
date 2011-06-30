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
require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'right_scraper_base', 'spec', 'cookbooks', 'cookbook_helper'))

describe RightScraper::Cookbook do
  include RightScraper::SpecHelpers::DevelopmentModeEnvironment

  include RightScraper::CookbookHelper

  shared_examples_for 'a git repository' do
    it_should_behave_like 'a generic repository'

    it 'should have the right position' do
      parse_url(@repository, "/a")[:position].should == "/a"
    end
    it 'should have no password' do
      parse_url(@repository)[:password].should be_nil
    end
  end

  context 'with an invalid git repository' do
    before(:each) do
      @repository = RightScraper::Repository.from_hash(:display_name => 'test repo',
                                                     :repo_type => :git,
                                                     :url => "http://a.site/foo/bar/baz")
    end

    it_should_behave_like 'a git repository'

    it 'should fail to scrape' do
      lambda {
      scraper = nil
      begin
        scraper = @repository.scraper.new(@repository)
        scraper.next
      ensure
        scraper.close unless scraper.nil?
      end
      }.should raise_exception(Git::GitExecuteError)
    end
  end

  context 'with a git repository with a credential that requires a password' do
    before(:each) do
      passwd_key = File.open(File.join(File.dirname(__FILE__), 'password_key')).read
      @repository = RightScraper::Repository.from_hash(:display_name => 'test repo',
                                                     :repo_type => :git,
                                                     :url => "http://a.site/foo/bar/baz",
                                                     :first_credential => passwd_key)
    end

    it_should_behave_like 'a git repository'

    it 'should close the connection to the agent' do
      oldpid = ENV['SSH_AGENT_PID']
      lambda {
        scraper = @repository.scraper.new(@repository)
      }.should raise_exception(ProcessWatcher::NonzeroExitCode)
      ENV['SSH_AGENT_PID'].should == oldpid
    end
  end

  context 'with an invalid git repository with a real credential' do
    before(:each) do
      passwd_key = File.open(File.join(File.dirname(__FILE__), 'demokey')).read
      @repository = RightScraper::Repository.from_hash(:display_name => 'test repo',
                                                     :repo_type => :git,
                                                     :url => "http://example.example/foo/bar/baz",
                                                     :first_credential => passwd_key)
    end

    it_should_behave_like 'a git repository'

    it 'should close the connection to the agent' do
      oldpid = ENV['SSH_AGENT_PID']
      lambda {
        scraper = @repository.scraper.new(@repository)
      }.should raise_exception(Git::GitExecuteError)
      ENV['SSH_AGENT_PID'].should == oldpid
    end
  end

  context 'with a git repository' do
    before(:each) do
      @repository = RightScraper::Repository.from_hash(:display_name => 'test repo',
                                                     :repo_type => :git,
                                                     :url => "http://a.site/foo/bar/baz",
                                                     :first_credential => "a-key")
    end

    it_should_behave_like 'a git repository'

    it 'should have a tag' do
      parse_url(@repository)[:tag].should == "master"
    end

    it 'should have a cookbook hash' do
      repo_hash = Digest::SHA1.hexdigest("1\000git\000http://a.site/foo/bar/baz\000master")
      example_cookbook(@repository).cookbook_hash.should ==
        Digest::SHA1.hexdigest("1\000#{repo_hash}\000")
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
  context 'with a git repository with a tag' do
    before(:each) do
      @repository = RightScraper::Repository.from_hash(:display_name => 'test repo',
                                                     :repo_type => :git,
                                                     :url => "http://a.site/foo/bar/baz",
                                                     :tag => "DEADBEEF",
                                                     :first_credential => "a-key")
    end

    it_should_behave_like 'a git repository'

    it 'should have a tag' do
      parse_url(@repository)[:tag].should == "DEADBEEF"
    end
  end

  context 'when built from a Cookbook URL' do
    context 'for a git repository with a tag' do
      before(:each) do
        @url = "git:http://sshkey@baz.com/foo/bar/baz?a=z;a=b;q=blah;b=blah&p=foo#DEADBEEF"
        @cookbook = RightScraper::Cookbook.from_url @url
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
        @cookbook.pos.should == "foo"
      end
    end
    context 'for a git repository without a tag' do
      before(:each) do
        @url = "git:http://sshkey@baz.com/foo/bar/baz?q=blah;b=blah&p=foo"
        @cookbook = RightScraper::Cookbook.from_url @url
      end
      it 'should point to master' do
        @cookbook.repository.tag.should == "master"
      end
    end
    context 'for a git repository without a position' do
      before(:each) do
        @url = "git:http://sshkey@baz.com/foo/bar/baz?b=blah;q=blah"
        @cookbook = RightScraper::Cookbook.from_url @url
      end
      it 'should not have a position' do
        @cookbook.pos.should be_nil
      end
    end
  end
end
