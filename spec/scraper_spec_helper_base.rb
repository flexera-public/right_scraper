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
require 'tmpdir'

module RightScale

  # Base class for all scrapers spec helpers
  # Define helper methods used to manage repositories using each
  # source control software
  class ScraperSpecHelperBase

    include SpecHelpers

    def initialize
      @tmpdir = Dir.mktmpdir
      FileUtils.mkdir(repo_path)
      @repo_content = [ { 'folder1' => [ 'file2', 'file3' ] },
                        { 'folder2' => [ { 'folder3' => [ 'file4' ] } ] },
                        'file1' ]
    end

    def close
      FileUtils.remove_entry_secure @tmpdir
    end

    # Path to test repository
    #
    # === Return
    # repo_path(String):: Path to test repository
    def repo_path
      File.join(@tmpdir, "repository")
    end

    # Default test repo content
    #
    # === Return
    # content(String):: Default test repo content
    attr_reader :repo_content

    # Test branch content
    #
    # === Return
    # content(String):: Branch content
    def branch_content
      content = [ { 'branch_folder' => [ 'bfile1', 'bfile2' ] }, 'bfile3' ]
    end

    # Additional content used to test incremental updates
    #
    # === Return
    # content(String):: Additional content
    def additional_content
      content = [ { 'additional_folder' => [ 'afile1', 'afile2' ] }, 'afile3' ]
    end

    # Commit any non-commited changes of given directory
    #
    # === Parameters
    # repo_path(String):: Path to directory where commit should be created
    # commit_message(String):: Optional, commit message
    #
    # === Raise
    # Exception:: If commit command fails
    def commit_content(repo_path, commit_message='Initial commit')
      raise 'Not implemented'
    end

    # Create a branch in given repository
    # Optionally adds a new commit with given file layout
    # Switch to branch so that next call to 'create_file_layout' will act
    # on given branch
    #
    # === Parameters
    # branch(String):: Name of branch that should be created
    # new_content(Hash):: Layout of files to be added to branch as a single commit
    #
    # === Return
    # true:: Always return true
    #
    # === Raise
    # Exception:: If branch command fails
    def setup_branch(branch, new_content=nil)
      raise 'Not implemented'
    end

    # Commit id for commit in test repo
    # i.e. git sha or svn rev
    #
    # === Parameters
    # index_from_last(Integer):: Commit whose id should be returned:
    #                              - 0 means last commit
    #                              - 1 means 1 before last
    #                              - etc.
    #
    # === Return
    # commit_id(String):: Corresponding commit id
    def commit_id(index_from_last=0)
      raise 'Not implemented'
    end
  end
end
