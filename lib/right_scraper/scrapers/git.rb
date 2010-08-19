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
require File.expand_path(File.join(File.dirname(__FILE__), 'base'))
require 'git'
require 'libarchive_ruby'
require 'tmpdir'

module RightScale
  class GitScraper < CheckoutBasedScraper
    def exists?
      File.exists?(File.join(checkout_path, '.git'))
    end

    def do_update
      begin
        git = Git.open(checkout_path)
        git.checkout(@repository.tag) if @repository.tag
        possibles = git.branches.local.select {|branch| branch.name == @repository.tag}
        # if possibles is empty, then tag is a SHA or a tag and in any
        # case fetching makes no sense.
        unless possibles.empty?
          branch = possibles.first
          remotename = git.config("branch.#{branch.name}.remote")
          remote = git.remote(remotename)
          remote.fetch
          remote.merge
        end
      rescue Git::GitExecuteError
        puts "AAARGH " + $!
        FileUtils.remove_entry_secure checkout_path
        do_checkout
      end
    end

    def do_checkout
      FileUtils.mkdir_p(checkout_path)
      git = Git.clone(@repository.url, checkout_path)
      git.checkout(@repository.tag) if @repository.tag
    end

    def ignorable_paths
      ['.git']
    end
  end
end
