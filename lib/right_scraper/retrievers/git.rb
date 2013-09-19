#--
# Copyright: Copyright (c) 2010-2013 RightScale, Inc.
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

# ancestor
require 'right_scraper/retrievers'

require 'fileutils'
require 'tmpdir'
require 'right_git'
require 'right_support'

module RightScraper::Retrievers

  # Retriever for resources stored in a git repository.
  class Git < ::RightScraper::Retrievers::CheckoutBase

    @@available = false

    # Determines if downloader is available.
    def available?
      unless @@available
        begin
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

    # Ignore .git directories.
    def ignorable_paths
      ['.git']
    end

    # In addition to normal retriever initialization, if the
    # underlying repository has a credential we need to initialize a
    # fresh SSHAgent and add the credential to it.
    def retrieve
      raise RetrieverError.new("git retriever is unavailable") unless available?
      private_key = @repository.first_credential
      private_key = nil if private_key && private_key.empty?
      if is_windows?
        if private_key
          with_private_key_windows(private_key) { super }
        else
          super
        end
      else
        # always start the ssh agent in Linux so we can disable strict host name
        # checking, regardless of credentials.
        ::RightScraper::Processes::SSHAgent.with do |agent|
          agent.add_key(private_key) if private_key
          super
        end
      end
      true
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

    # Determines if the remote SHA/tag/branch referenced by the repostory
    # differs from what appears on disk.
    #
    # @return [TrueClass|FalseClass] true if changed
    def remote_differs?
      remote_sha = nil
      current_sha = nil
      git_repo = git_repo_for(@repo_dir)
      without_size_limit(git_repo) do
        do_fetch(git_repo)
        revision = resolve_revision
        remote_name = validate_revision(git_repo, revision)
        remote_sha = git_repo.sha_for(remote_name ? remote_name : revision)
        current_sha = git_repo.sha_for(nil)
      end
      current_sha != remote_sha
    end

    # Implements CheckoutBase#do_checkout
    def do_checkout
      git_repo = @logger.operation(:cloning, "to #{@repo_dir}") do
        without_host_key_checking do
          ::RightGit::Git::Repository.clone_to(
            @repository.url,
            @repo_dir,
            :logger => git_repo_logger,
            :shell  => git_repo_shell)
        end
      end
      do_fetch(git_repo)
      do_checkout_revision(git_repo)
      internal_update_tag(git_repo)
      true
    end

    # Implements CheckoutBase#do_update
    def do_update
      # note that a recent fetch was performed by remote_differs? and even if
      # remotes have changed again in the brief interim it would invalidate
      # the decisions already made if we refetched now.
      git_repo = git_repo_for(@repo_dir)
      @logger.operation(:cleanup, "ensure no untracked files in #{@repo_dir}") do
        git_repo.hard_reset_to(nil)
        do_clean_all(git_repo)
      end
      do_checkout_revision(git_repo)
      do_clean_all(git_repo)  # clean again once we are on requested revision
      internal_update_tag(git_repo)
      true
    end

    # Implements CheckoutBase#do_update_tag
    def do_update_tag
      git_repo = git_repo_for(@repo_dir)
      without_size_limit(git_repo) do
        internal_update_tag(git_repo)
      end
      true
    end

    private

    DEFAULT_BRANCH_NAME = 'master'

    GIT_REVISION_REGEX = /^[A-Za-z0-9._-]+$/

    def git_repo_for(dir)
      ::RightGit::Git::Repository.new(
        dir,
        :logger => git_repo_logger,
        :shell  => git_repo_shell)
    end

    def git_repo_logger
      # note that info-level logging is normally suppressed by scraper so git
      # repo won't log anything but warnings and errors unless logger is made
      # verbose.
      @logger
    end

    def git_repo_shell
      @git_repo_shell ||= ::RightScraper::Processes::Shell.new(
        :logger            => git_repo_logger,
        :initial_directory => repo_dir,
        :max_bytes         => max_bytes,
        :max_seconds       => max_seconds,
        :watch_directory   => repo_dir)
    end

    def internal_update_tag(git_repo)
      @repository = @repository.clone
      @repository.tag = git_repo.sha_for(nil)
      true
    end

    def do_checkout_revision(git_repo)
      @logger.operation(:checkout_revision) do
        revision = resolve_revision
        remote_name = validate_revision(git_repo, revision)
        git_repo.checkout_to(revision, :force => true)
        git_repo.hard_reset_to(remote_name) if remote_name

        # initialize/update submodules based on current SHA.
        #
        # TEAL FIX: there is no support for checking-out same branch/tag in
        # the submodule(s) but this could be an advanced feature.
        git_repo.update_submodules(:recursive => true)
      end
      true
    end

    def do_fetch(git_repo)
      @logger.operation(:fetch) do
        # delete local tags, which may or may not still exist on remote.
        git_repo.tags.each do |tag|
          git_args = ['tag', '-d', tag.name]
          git_repo.spit_output(git_args)
        end
        git_repo.fetch_all(:prune => true)
      end
    end

    # Cleans anything that is currently untracked in the repo directory and
    # any submodules. the idea is to prevent untracked items interfering with
    # the normal behavior that would result if checkout were always to a clean
    # directory. just switching between branches and updating submodules can
    # leave untracked artifacts that affect behavior.
    def do_clean_all(git_repo)
      old_initial_directory = git_repo.repo_dir
      clean_all_options = {
        :directories => true,
        :gitignored  => true,
        :submodules  => true
      }
      relative_paths = [
        '.',
        git_repo.submodule_paths(:recursive => true)
      ].flatten
      relative_paths.each do |relative_path|
        subdir_path = ::File.expand_path(::File.join(@repo_dir, relative_path))
        if ::File.directory?(subdir_path)
          # reuse shell with any watch parameters already set but vary the
          # initial directory for each submodule.
          git_repo.shell.initial_directory = subdir_path
          git_repo.clean_all(clean_all_options)
        end
      end
      true
    rescue ::RightGit::RightGitError => e
      @logger.note_warning(e.message)
      false
    ensure
      git_repo.shell.initial_directory = old_initial_directory
    end

    def resolve_revision
      revision = @repository.tag.to_s.strip
      revision = DEFAULT_BRANCH_NAME if revision.empty?
      unless revision =~ GIT_REVISION_REGEX
        raise RetrieverError, "Revision reference contained illegal characters: #{revision.inspect}"
      end
      revision
    end

    # Validates the given revision string to ensure it is safe and sane before
    # attempting to use it.
    #
    # @param [::RightGit::Git::Repository] git_repo for validation
    # @param [String] revision for validation
    #
    # @return [String] remote_name (for branch reset) or nil
    #
    # @raise [RetrieverError] on validation failure
    def validate_revision(git_repo, revision)
      branches = git_repo.branches(:all => true)
      local_branches = branches.local
      remote_branches = branches.remote
      by_name = lambda { |item| item.name == revision }

      # determine if revision is a tag.
      remote_name = nil
      if git_repo.tags.any?(&by_name)
        if remote_branches.any?(&by_name)
          # note that git has some resolution scheme for ambiguous SHA, tag,
          # branch names but we do not support ambiguity.
          raise RetrieverError, "Ambiguous name is both a remote branch and a tag: #{revision.inspect}"
        elsif local_branches.any?(&by_name)
          # odd corner case of a name that once was a remote branch (now
          # deleted) that has become a tag instead. the user is not exactly
          # at fault here (aside from being indecisive) so let's attempt to
          # clean up after him. try switching to another local branch
          # (i.e. master) and then deleting the obsolete local branch.
          error_message = "Ambiguous name is both a local branch and a tag: #{revision.inspect}"
          if revision == DEFAULT_BRANCH_NAME
            # Darwin Awards winner; scraping with a tag named 'master' :@
            raise RetrieverError, error_message
          else
            begin
              # checkout master and delete obsolete local branch.
              git_repo.checkout_to(DEFAULT_BRANCH_NAME, :force => true)
              git_repo.spit_output("branch -D #{revision}")
            rescue ::RightGit::RightGitError
              # ignore failed attempt to recover; raise original error.
              raise RetrieverError, error_message
            end
          end
        end
      else
        # not a tag; SHA or branch.
        #
        # note that we could try to trivially determine if revision was a
        # SHA by matching the SHA1 pattern except that:
        #  1) git accepts partial SHAs so long as they uniquely distinguish
        #     a commit for checkout.
        #  2) a branch or tag could name could match the SHA pattern (i.e.
        #     40 hexadecimal characters) with no warnings from git. git will
        #     even allow a user to use a SHA as a tag name when that SHA
        #     exists (and may represent a different commit).
        # confusing tags with SHAs should be universally discouraged but we
        # need to be flexible here.
        #
        # a local branch may no longer exist remotely or may be behind or
        # have diverged from remote branch. handle all cases.
        remotes = remote_branches.select(&by_name)
        if remotes.size > 1
          # multiple remote branches exist (from different origins); branch
          # name is ambiguous.
          raise RetrieverError, "Ambiguous remote branch name: #{revision.inspect}"
        elsif remotes.size == 1
          # a remote branch exists.
          remote_name = remotes.first.fullname
        elsif local_branches.any?(&by_name)
          # local branch only; failure due to missing remote branch.
          #
          # note that obsolete local branches are not supported by retrieval
          # only because it would give the user a false positive.
          raise RetrieverError, "Missing remote branch: #{revision.inspect}."
        end # else a full or partial SHA or unknown revision
      end
      remote_name
    end

    # Temporarily disables checking the size of the repo_dir against the
    # configured size limit. This permits performing git queries against a repo
    # on disk that would normally exceed the size limit if it hadn't already
    # been fully checked out in the past. If a repo has been scraped in the past
    # and does not have any new commits, then it is acceptable even if it
    # would exceed the current size limit.
    def without_size_limit(git_repo)
      old_max_bytes = git_repo.shell.max_bytes
      begin
        git_repo.shell.max_bytes = nil
        yield
      ensure
        git_repo.shell.max_bytes = old_max_bytes
      end
    end

    # Temporarily disable SSH host-key checking for SSH clients invoked by Git, for the duration of the
    # block that is passed to this method.
    #
    # @yield after disabling strict host key checking, yields to caller
    def without_host_key_checking(&callback)
      if is_windows?
        without_host_key_checking_windows(&callback)
      else
        without_host_key_checking_linux(&callback)
      end
    end

    # Temporarily disable SSH host-key checking for SSH clients invoked by Git, for the duration of the
    # block that is passed to this method.
    #
    # @yield after disabling strict host key checking, yields to caller
    def without_host_key_checking_linux
      tmpdir = ::Dir.mktmpdir
      ssh_cmd = ::File.join(tmpdir, 'ssh')

      ::File.open(ssh_cmd, 'w') do |cmd|
        cmd.puts "#!/bin/bash"
        cmd.puts "exec ssh -o StrictHostKeyChecking=no ${@}"
      end
      ::FileUtils.chmod(0700, ssh_cmd)

      old_env = ::ENV['GIT_SSH']
      ::ENV['GIT_SSH'] = ssh_cmd
      yield
    ensure
      ::FileUtils.rm_rf(tmpdir)
      ::ENV['GIT_SSH'] = old_env
    end

    # The "ssh.exe" that comes with msysgit doesn't appear to configure things
    # properly under Windows (or it does for SYSTEM account but not user
    # accounts) when disabling strict hostname checking. We can instead
    # temporarily create/replace the "%USERPROFILE%\.ssh\config" file to disable
    # checking for all hostnames.
    #
    # @yield after disabling strict host key checking, yields to caller
    def without_host_key_checking_windows(&callback)
      config_path = ::File.expand_path(::File.join(home_dir_windows, '.ssh', 'config'))
      config_text = <<EOF
Host *
  StrictHostKeyChecking no
EOF
      with_replaced_file(config_path, config_text, &callback)
    end

    def with_private_key_windows(private_key, &callback)
      private_key_path = ::File.expand_path(::File.join(home_dir_windows, '.ssh', 'id_rsa'))
      with_replaced_file(private_key_path, private_key, &callback)
    end

    # Utility for replacing a file temporarily within a scope and ensuring it is
    # restored afterward.
    #
    # @param [String] filepath to replace
    # @param [String] contents to substitute
    #
    # @yield after replacing file
    def with_replaced_file(filepath, contents)
      ::Dir.mktmpdir do |temp_dir|
        begin
          temp_path = ::File.join(temp_dir, ::File.basename(filepath))
          ::FileUtils.mkdir_p(::File.dirname(filepath))
          if ::File.file?(filepath)
            ::FileUtils.mv(filepath, temp_path, :force => true)
          end
          ::File.open(filepath, 'w') { |f| f.write(contents) }
          yield
        ensure
          begin
            if ::File.file?(temp_path)
              ::FileUtils.mv(temp_path, filepath, :force => true)
            elsif ::File.file?(filepath)
              ::File.unlink(filepath)
            end
          rescue ::Exception => e
            @logger.note_warning("Failed to restore #{filepath.inspect}: #{e.message}")
          end
        end
      end
    end

    # @return default location for git-related configuration files.
    def home_dir_windows
      home_dir = ::ENV['USERPROFILE']
      unless home_dir && ::File.directory?(home_dir)
        raise RetrieverError, "Invalid USERPROFILE directory: #{home_dir.inspect}"
      end
      home_dir
    end

    # @return [TrueClass|FalseClass] true if running on Windows
    def is_windows?
      !!(RUBY_PLATFORM =~ /mswin|win32|dos|mingw|cygwin/)
    end
  end
end
