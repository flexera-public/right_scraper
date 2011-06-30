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
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'processes', 'ssh'))
require 'git'

module RightScraper
  module Scrapers
    # Scraper for cookbooks stored in a git repository.
    class Git < CheckoutBasedScraper
      # In addition to normal scraper initialization, if the
      # underlying repository has a credential we need to initialize a
      # fresh SSHAgent and add the credential to it.
      def setup_dir
        RightScraper::Processes::SSHAgent.with do |agent|
          agent.add_key(@repository.first_credential) unless
            @repository.first_credential.nil?
          super
        end
      end

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
      #   * update @repository#tag
      # Note that if #tag is a SHA revision or a tag that exists in the
      # current repository, no fetching is done.
      def do_update
        git = ::Git.open(basedir)
        if remote = find_remote_branch(git, repo_tag)
          # This is gross, but the git library doesn't make it easy to
          # remove the remote branches by hand.  Perhaps we'll go with
          # libgit2 some day.
          git.branches.remote.each do |branch|
            # there's an ugly bug in the git gem parsing routines that causes it to see lines like
            #   origin/HEAD -> origin/master
            # and not process them properly.  Ignore these.
            git.lib.branch_new(["-D", "-r", branch.full]) unless branch.full =~ / -> /
          end
          @logger.operation(:fetch) do
            remote.remote.fetch
          end
          new_remote = find_remote_branch(git, repo_tag)
          local = find_local_branch(git, repo_tag) || git.branch(branch.name)
          @logger.operation(:reset) do
            local.update_ref(new_remote.gcommit)
          end
          git.reset_hard
        end
        do_checkout_revision(git)
        do_update_tag(git)
      end

      def do_update_tag(git)
        @repository = @repository.clone
        @repository.tag = git.gtree("HEAD").sha
      end

      # Clone the remote repository.  The operations are as follows:
      # * clone repository to #basedir
      # * checkout #tag
      # * update @repository#tag
      def do_checkout
        super
        git = @logger.operation(:cloning, "to #{basedir}") do
          ::Git.clone(@repository.url, basedir)
        end
        do_checkout_revision(git)
        do_update_tag git
      end

      def do_checkout_revision(git)
        @logger.operation(:checkout_revision) do
          branch = find_branch(git, repo_tag)
          case
          when branch && tag?(git, repo_tag) then
            raise "Ambiguous reference: '#{repo_tag}' denotes both a branch and a tag"
          when branch && branch.remote then
            # need to make a local tracking branch
            newbranch = git.branch(branch.name)
            newbranch.update_ref(branch.gcommit)
            newbranch.checkout
            branch = newbranch
            branch.checkout
          when branch then
            branch.checkout
          else
            git.checkout(repo_tag)
          end
        end if repo_tag
      end

      def tag?(git, name)
        git.tags.find {|t| t.name == name}
      end

      def repo_tag
        name = (@repository.tag || "master").chomp
        name = "master" if name.empty?
        name
      end

      def find_branch(git, tag)
        find_local_branch(git, tag) || find_remote_branch(git, tag)
      end

      def find_local_branch(git, name)
        git.branches.local.find {|b| b.name == name}
      end

      def find_remote_branch(git, name)
        git.branches.remote.find {|b| b.name == name}
      end

      # Ignore .git directories.
      def ignorable_paths
        ['.git']
      end
    end
  end
end
