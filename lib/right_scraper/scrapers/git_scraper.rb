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

require 'git'

module RightScale

  class GitScraper < ScraperBase

    # Check whether it is possible to perform an incremental update of the repo
    #
    # === Return
    # true:: Scrape directory contains files belonging to the scraped repo and protocol supports
    #        incremental updates
    # false:: Otherwise
    def incremental_update?
      # FIX: current version of msysgit crashes attempting "git pull" on 64-bit
      # servers. we will avoid incremental for now in hopes of getting a fix for
      # msysgit or else a native Windows implementation such as Git#
      return false if (is_windows? || !File.directory?(@current_repo_dir))
      g = Git.open(@current_repo_dir)
      g.config('remote.origin.url') == @repo.url
    end

    # Scrape git repository, see RightScale::ScraperBase#scrape
    #
    # === Return
    # true:: Always return true
    def scrape_imp
      msg = @incremental ? 'Pulling ' : 'Cloning '
      msg += "git repository '#{@repo.display_name}'"
      @callback.call(msg, is_step=true) if @callback
      @ssh_cmd = ssh_command
      is_tag  = is_branch = on_branch = nil
      has_tag = !@repo.tag.nil? && !@repo.tag.empty?

      if @incremental
        checkout = false
        g = Git.open(@current_repo_dir)
        if has_tag
          analysis = analyze_repo_tag(g)
          if succeeded?
            is_tag = analysis[:tag]
            is_branch = analysis[:branch]
            on_branch = analysis[:on_branch]
            checkout = is_tag && !is_branch
            if is_tag && is_branch
              @errors << 'Repository tag ambiguous: could be git tag or git branch'
            elsif !is_tag && !is_branch
              current_sha = g.object('HEAD').sha
              if current_sha == @repo.tag
                @callback.call("Nothing to update: already using #{@repo.tag}", is_step=false) if @callback
                return true
              else
                # Probably a SHA, retrieve all commits
                git_fetch(g, :depth => 2**31 - 1)
                checkout = true
              end
            end
            if succeeded?
              if checkout
                git_checkout(g, @repo.tag)
              else
                git_checkout(g, @repo.tag) if is_branch && !on_branch
                git_fetch(g, :depth => 1, :merge => true,
                          :remote_tag => @repo.tag)
              end
            end
          end
        else
          git_fetch(g, :depth => 1, :merge => true)
        end
      end

      if !@incremental && succeeded?
        g = Git.clone(@repo.url, @current_repo_dir, :depth => 1)

        if has_tag && succeeded?
          if is_tag.nil?
            analysis  = analyze_repo_tag(g)
            is_tag    = analysis[:tag]
            is_branch = analysis[:branch]
            on_branch = analysis[:on_branch]
          end
          if succeeded?
            if is_tag && is_branch
              @errors << 'Repository tag ambiguous: could be git tag or git branch'
            elsif is_branch && !on_branch
              g.branch('origin/#{@repo.tag}').checkout
            elsif !is_tag # Not a branch nor a tag, SHA ref? fetch everything so we have all SHAs
              git_fetch(g, :depth => 2**31 -1)
            end
            if succeeded? && !on_branch
              git_checkout(g, @repo.tag)
            end
          end
        end
      end
      true
    end

    # Default SSH options used with git
    DEFAULT_SSH_OPTIONS = { :PasswordAuthentication  => 'no',
      :HostbasedAuthentication => 'no',
      :StrictHostKeyChecking   => 'no',
      :IdentitiesOnly          => 'yes' }

    # SSH options command line built from default options and given custom options
    #
    # === Parameters
    # opts(Hash):: Custom options
    #
    # === Return
    # options(String):: SSH command line options
    def ssh_options(opts={})
      opts = DEFAULT_SSH_OPTIONS.merge(opts || {})
      options = opts.inject('') { |o, (k, v)| o << "#{k.to_s}=#{v}\n" }
    end

    # Store private SSH key into temporary folder and create temporary script
    # that wraps SSH and uses this key.
    #
    # === Return
    # ssh(String):: Code to initialize GIT_SSH environment variable with path to SSH wrapper script
    def ssh_command
      return win32_ssh_command if is_windows?
      ssh_dir = File.join(@scrape_dir_path, '.ssh')
      FileUtils.mkdir_p(ssh_dir)
      key_content = @repo.first_credential
      if key_content.nil?
        # Explicitely disable public key authentication so we don't endup using the system's key
        options = { :PubkeyAuthentication => 'no' }
      else
        ssh_key_path = File.join(ssh_dir, 'id_rsa')
        File.open(ssh_key_path, 'w') { |f| f.puts(key_content) }
        File.chmod(0600, ssh_key_path)
        options = { :IdentityFile => ssh_key_path }
      end
      ssh_config = File.join(ssh_dir, 'ssh_config')
      File.open(ssh_config, 'w') { |f| f.puts(ssh_options(options)) }
      ssh = File.join(ssh_dir, 'ssh')
      File.open(ssh, 'w') { |f| f.puts("ssh -F #{ssh_config} $*") }
      File.chmod(0755, ssh)

      return ssh
    end

    # Prepare SSH for git on Windows
    # The GIT_SSH trick doesn't seem to work on Windows, instead actually
    # save the private key in the user ssh folder.
    # Note: This will override any pre-existing SSH key that was on the system
    #
    # === Return
    # '':: Always return an empty string
    #
    # === Raise
    # Exception:: If the USERPROFILE environment variable is not set
    def win32_ssh_command
      key_content = @repo.first_credential
      unless key_content.nil?
        # resolve key file path.
        raise 'Environment variable USERPROFILE is missing' unless ENV['USERPROFILE']
        user_profile_dir_path = ENV['USERPROFILE']
        ssh_keys_dir = File.join(user_profile_dir_path, '.ssh')
        FileUtils.mkdir_p(ssh_keys_dir) unless File.directory?(ssh_keys_dir)
        ssh_key_file_path = File.join(ssh_keys_dir, 'id_rsa')

        # (re)create key file. must overwrite any existing credentials in case
        # we are switching repositories and have different credentials for each.
        File.open(ssh_key_file_path, 'w') { |f| f.puts(key_content) }

        # we need to create the "known_hosts" file or else the process will
        # halt in windows waiting for a yes/no response to the unknown
        # git host. this is normally handled by specifying
        # "-o StrictHostKeyChecking=no" in the GIT_SSH executable, but it is
        # still a mystery why this doesn't work properly in windows.
        # so make a ssh call which creates the proper "known_hosts" file.
        run('ssh', '-o', 'StrictHostKeyChecking=no', repo.url.split(':').first)
      end
      return ''
    end

    # Fetch remote commits using given depth
    # Check size of repo and time it takes to retrieve commits
    # Update errors collection upon failure (check for succeeded? after call)
    # Note: Assume that current working directory is a git directory
    #
    # === Parameters
    # opts[:depth(Integer):: Git fetch depth argument, full fetch if not set
    # opts[:merge]:: Do a pull if set
    # opts[:remote_tag]:: Remote ref to use, use default if not specified
    #
    # === Return
    # true:: Always return true
    def git_fetch(git, opts={})
      depth   = opts[:depth] || 2**31 - 1 # Specify max to override depth of already cloned repo
      remote  = opts[:remote_tag]
      remote  = 'master' if remote.nil? || remote.rstrip.empty?
      origin = git.remote('origin')
      origin.fetch
      if opts[:merge]
        origin.merge
      end
    end

    # Does a git checkout to given tag
    # Update errors collection upon failure (check for succeeded? after call)
    # Note: Assume that current working directory is a git directory
    #
    # === Parameters
    # tag(String):: Tag to checkout
    #
    # === Return
    # true:: Always return true
    def git_checkout(git, tag)
      git.checkout(tag)
    end

    # Analyze repository tag to detect whether it's a branch, a tag or neither (i.e. SHA ref)
    # Also detech wether the branch is already checked out
    # Update errors collection upon failure (check for succeeded? after call)
    # Note: Assume that current working directory is a git directory
    #
    # === Return
    # res(Hash)::
    #   - res[:tag]:: true if git repo has a tag with a name corresponding to the repository tag
    #   - res[:branch]:: true if git repo has a branch with a name corresponding to the repository tag
    #   - res [:on_branch]:: true if branch is already checked out
    def analyze_repo_tag(git)
      is_tag = is_branch = on_branch = nil
      begin
        is_tag = git.tags.map {|t| t.name}.include?(@repo.tag)
        is_branch = git.is_branch?("origin/" + @repo.tag)
        head = git.object('HEAD')
        on_branch = is_branch &&
          git.branch("origin/" + @repo.tag).sha == git.object('HEAD').sha
      rescue Exception => e
        @errors << "Analysis of repository tag failed with: #{e.message}"
      end
      res = { :tag => is_tag, :branch => is_branch, :on_branch => on_branch }
    end

    private

    # Check for windows.
    #
    # === Return
    #
    def is_windows?
      return !!(RUBY_PLATFORM =~ /mswin/)
    end

  end
end
