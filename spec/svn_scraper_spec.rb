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

require File.join(File.dirname(__FILE__), 'spec_helper')
require 'scraper_base'
require 'repository'
require 'watcher'
require File.join('scrapers', 'svn_scraper')

describe RightScale::SvnScraper do
  
  include RightScale::SpecHelpers
  
  # Create svn repository following given layout
  # Update @repo_path with path to repository
  # Delete any previously created repo
  def setup_svn_repo
    @svn_repo_path = File.expand_path(File.join(File.dirname(__FILE__), '__svn_repo'))
    @repo_path = File.join(File.dirname(__FILE__), '__repo')
    @repo_content = [ 'file1', { 'folder1' => [ 'file2', 'file3' ] }, { 'folder2' => [ { 'folder3' => [ 'file4' ] } ] } ]
    FileUtils.rm_rf(@svn_repo_path)
    res, status = exec("svnadmin create \"#{@svn_repo_path}\"")
    raise "Failed to initialize SVN repository: #{res}" unless status.success?
    FileUtils.rm_rf(@repo_path)
    res, status = exec("svn checkout \"file:///#{@svn_repo_path}\" \"#{@repo_path}\"")
    raise "Failed to checkout repository: #{res}" unless status.success?
    create_file_layout(@repo_path, @repo_content)
    Dir.chdir(@repo_path) do
      res, status = exec("svn add *")
      res, status = exec("svn commit --quiet -m \"Initial Commit\"") if status.success?
      raise "Failed to setup repository: #{res}" unless status.success?
    end
  end

  # Cleanup after ourselves
  def delete_svn_repo
    FileUtils.rm_rf(@svn_repo_path) if @svn_repo_path
    @svn_repo_path = nil
    FileUtils.rm_rf(@repo_path) if @repo_path
    @repo_path = nil
  end

  context 'given a SVN repository' do

    before(:all) do
      setup_svn_repo
    end

    before(:each) do
	  file_prefix = 'file://'
	  file_prefix += '/' if RUBY_PLATFORM =~ /mswin/
      @scraper = RightScale::SvnScraper.new(@repo_path, max_bytes=1024**2, max_seconds=20)      
      @repo = RightScale::Repository.from_hash(:display_name => 'test repo',
                                               :repo_type    => :svn,
                                               :url          => "#{file_prefix}#{@svn_repo_path}")
    end
    
    after(:all) do
      delete_svn_repo
    end

    it 'should scrape' do
      messages = []
      @scraper.scrape(@repo) { |m, progress| messages << m if progress }
      puts "\n **ERRORS: #{@scraper.errors.join("\n")}\n" unless @scraper.succeeded?
      @scraper.succeeded?.should be_true
      messages.size.should == 1
      File.directory?(@scraper.current_repo_dir.should be_true)
      extract_file_layout(@scraper.current_repo_dir, [ '.svn' ]).should == @repo_content
    end
    
    it 'should scrape incrementally' do
	  pending "File URLs comparison on Windows is tricky" if RUBY_PLATFORM=~/mswin/
      @scraper.scrape(@repo)
      puts "\n **ERRORS: #{@scraper.errors.join("\n")}\n" unless @scraper.succeeded?
      @scraper.incremental_update?.should be_true
      messages = []
      @scraper.scrape(@repo) { |m, progress| messages << m if progress }
      puts "\n **ERRORS: #{@scraper.errors.join("\n")}\n" unless @scraper.succeeded?
      @scraper.succeeded?.should be_true
      messages.size.should == 1
      File.directory?(@scraper.current_repo_dir.should be_true)
      extract_file_layout(@scraper.current_repo_dir, [ '.svn' ]).should == @repo_content
    end

  end

end
