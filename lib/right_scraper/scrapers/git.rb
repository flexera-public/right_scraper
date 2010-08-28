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
require File.expand_path(File.join(File.dirname(__FILE__), 'checkout'))
require 'git'

module RightScale
  module Scrapers
    # Scraper for cookbooks stored in a git repository.
    class Git < CheckoutBasedScraper
      # Return true if a checkout exists.  Currently tests for .git in
      # the checkout.
      #
      # === Returns ===
      # Boolean:: true if the checkout already exists (and thus
      #           incremental updating can occur).
      def exists?
        File.exists?(File.join(basedir, '.git'))
      end

      # Incrementally update the checkout.  The operations are as follows:
      # * checkout #tag
      # * if #tag is the head of a branch:
      #   * find that branch's remote
      #   * fetch it
      #   * merge changes
      # Note that if #tag is a SHA revision or a tag that exists in the
      # current repository, no fetching is done.
      def do_update
        git = ::Git.open(basedir)
        @logger.operation(:checkout_revision) do
          git.checkout(@repository.tag)
        end if @repository.tag
        possibles = git.branches.local.select {|branch| branch.name == @repository.tag}
        # if possibles is empty, then tag is a SHA or a tag and in any
        # case fetching makes no sense.
        unless possibles.empty?
          branch = possibles.first
          remotename = git.config("branch.#{branch.name}.remote")
          remote = git.remote(remotename)
          @logger.operation(:fetch) do
            remote.fetch
          end
          @logger.operation(:merge) do
            remote.merge
          end
        end
      end

      # Clone the remote repository.  The operations are as follows:
      # * clone repository to #basedir
      # * checkout #tag
      def do_checkout
        super
        git = @logger.operation(:cloning, "to #{basedir}") do
          ::Git.clone(@repository.url, basedir)
        end
        @logger.operation(:checkout_revision) do
          git.checkout(@repository.tag)
        end if @repository.tag
      end

      # Ignore .git directories.
      def ignorable_paths
        ['.git']
      end
    end
  end
end
