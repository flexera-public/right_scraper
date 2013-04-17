#--
# Copyright: Copyright (c) 2010-2011 RightScale, Inc.
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

require 'tmpdir'

# TEAL FIX: figure out a way to do this monkey-patch without always rquiring the
# blackwinter gem and/or create a rightscale-git fork with this fix.
require 'git'
require 'git/lib'

module Git
  class Lib
    # Monkey patch to blackwinter-git that strips ANSI escape sequences
    # from command output to avoid confusing the parser.
    def run_command_with_color_stripping(git_cmd, &block)
      out = run_command_without_color_stripping(git_cmd, &block)
      out.gsub!(/\e\[[^m]*m/, '')
      out
    end

    unless self.methods.include?('run_command_without_color_stripping')
      alias :run_command_without_color_stripping :run_command
      alias :run_command :run_command_with_color_stripping
    end
  end
end

module RightScraper
  module Retrievers
    # Retriever for resources stored in a git repository.
    class Git < CheckoutBasedRetriever
      @@available = false

      # Determines if downloader is available.
      def available?
        unless @@available
          begin
            # note that require 'git' does the same version check on load but
            # we don't want to assume any particular implementation.
            #
            # FIX: we might want to parse the result and require a minimum git
            # client version.
            cmd = "git --version"
            `#{cmd}`
            if $?.success?
              @@available = true
            else
              raise RetrieverError, "\"#{cmd}\" exited with #{$?.exitstatus}"
            end
          rescue
            @logger.note_error($!, :available, "git retriever is unavailable")
          end
        end
        @@available
      end

      # In addition to normal retriever initialization, if the
      # underlying repository has a credential we need to initialize a
      # fresh SSHAgent and add the credential to it.
      def retrieve
        raise RetrieverError.new("git retriever is unavailable") unless available?
        RightScraper::Processes::SSHAgent.with do |agent|
          unless @repository.first_credential.nil? || @repository.first_credential.empty?
            agent.add_key(@repository.first_credential)
          end
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
        File.exists?(File.join(@repo_dir, '.git'))
      end

      def do_fetch(git)
        @logger.operation(:fetch) do
          git.tags.each {|tag| git.lib.tag(['-d', tag.name])}
          git.fetch(['--all', '--prune', '--tags'])
        end
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
        git = ::Git.open(@repo_dir)
        do_fetch(git)
        @logger.operation(:cleanup, "ensure no untracked files in #{@repo_dir}") do
          git.reset_hard
          Dir.chdir(@repo_dir) do
            # ignore outcome; there is no way to record 'warnings'
            system("git clean -f")
          end
        end
        do_checkout_revision(git)
        do_update_tag(git)
      end

      def do_update_tag(git)
        @repository = @repository.clone
        @repository.tag = git.gtree("HEAD").sha
      end

      # Clone the remote repository.  The operations are as follows:
      # * clone repository to @repo_dir
      # * checkout #tag
      # * update @repository#tag
      def do_checkout
        super
        git = @logger.operation(:cloning, "to #{@repo_dir}") do
          without_host_key_checking do
            ::Git.clone(@repository.url, @repo_dir)
          end
        end
        do_fetch(git)
        do_checkout_revision(git)
        do_update_tag git
      end

      def do_checkout_revision(git)
        @logger.operation(:checkout_revision) do
          case
          when tag?(git, repo_tag) && branch?(git, repo_tag) then
            raise "Ambiguous reference: '#{repo_tag}' denotes both a branch and a tag"
          when branch = find_remote_branch(git, repo_tag) then
            branch.checkout
          when branch = find_local_branch(git, repo_tag) then
            branch.checkout
          else
            git.checkout(repo_tag)
          end
        end if repo_tag
      end

      # Ignore .git directories.
      def ignorable_paths
        ['.git']
      end

      def tag?(git, name)
        git.tags.find {|t| t.name == name}
      end

      def branch?(git, name)
        git.branches.find {|t| t.name == name}
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

      # Temporarily disable SSH host-key checking for SSH clients invoked by Git, for the duration of the
      # block that is passed to this method.
      #
      # @yield after disabling strict host key checking, yields to caller
      def without_host_key_checking
        tmpdir = Dir.mktmpdir
        ssh_cmd = File.join(tmpdir, 'ssh')

        File.open(ssh_cmd, 'w') do |cmd|
          cmd.puts "#!/bin/bash"
          cmd.puts "exec ssh -o StrictHostKeyChecking=no ${@}"
        end
        FileUtils.chmod(0700, ssh_cmd)

        old_env = ENV['GIT_SSH']
        ENV['GIT_SSH'] = ssh_cmd

        result = yield
      ensure
        FileUtils.rm_rf(tmpdir)
        ENV['GIT_SSH'] = old_env

        result
      end
    end
  end
end
