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

# Not supported on Windows
unless RUBY_PLATFORM=~/mswin/

require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))
require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'lib', 'right_scraper'))

describe RightScale::DownloadScraper do

  include RightScale::SpecHelpers

  # Create download repository following given layout
  # Update @repo_path with path to repository
  # Delete any previously created repo
  def setup_download_repo
    @download_repo_path = File.expand_path(File.join(File.dirname(__FILE__), '__download_repo'))
    @repo_path = File.join(File.dirname(__FILE__), '__repo')
    @repo_content = [ { 'folder1' => [ 'file2', 'file3' ] }, { 'folder2' => [ { 'folder3' => [ 'file4' ] } ] }, 'file1' ]
    FileUtils.rm_rf(@download_repo_path)
    create_file_layout(@download_repo_path, @repo_content)
    @download_file = File.expand_path(File.join(File.dirname(__FILE__), '__download_file.tar'))
    Dir.chdir(@download_repo_path) do
      res, status = exec("tar cf \"#{@download_file}\" *")
      raise "Failed to create tarball: #{res}" unless status.success?
    end
  end

  # Cleanup after ourselves
  def delete_download_repo
    FileUtils.rm_rf(@download_repo_path) if @download_repo_path
    @download_repo_path = nil
    FileUtils.rm_rf(@repo_path) if @repo_path
    @repo_path = nil
    File.delete(@download_file) if File.exist?(@download_file)
  end

  context 'given a download repository' do

    before(:all) do
      setup_download_repo
    end

    before(:each) do
      @scraper = RightScale::DownloadScraper.new(@repo_path, max_bytes=1024**2, max_seconds=20)
      @repo = RightScale::Repository.from_hash(:display_name => 'test repo',
                                               :repo_type    => :download,
                                               :url          => "file:///#{@download_file}")
      FileUtils.rm_rf(RightScale::ScraperBase.repo_dir(@repo_path, @repo))
    end

    after(:all) do
      delete_download_repo
    end

    it 'should scrape' do
      messages = []
      @scraper.scrape(@repo) { |m, progress| messages << m if progress }
      puts "\n **ERRORS: #{@scraper.errors.join("\n")}\n" unless @scraper.succeeded?
      @scraper.succeeded?.should be_true
      messages.size.should == 1
      File.directory?(@scraper.current_repo_dir).should be_true
      extract_file_layout(@scraper.current_repo_dir).should == @repo_content
    end

  end

end

end # unless RUBY_PLATFORM=~/mswin/
