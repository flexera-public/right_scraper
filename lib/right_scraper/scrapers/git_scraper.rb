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

module RightScale

  class GitScraper < ScraperBase

    # Check whether it is possible to perform an incremental update of the repo
    #
    # === Return
    # true:: Scrape directory contains files belonging to the scraped repo and protocol supports
    #        incremental updates
    # false:: Otherwise
    def incremental_update?
      return false unless File.directory?(@current_repo_dir)
      Dir.chdir(@current_repo_dir) do
        remote_url = `git config --get remote.origin.url`.chomp
        $?.success? && remote_url == @repo.url
      end
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
        Dir.chdir(@current_repo_dir) do
          git_fetch(:depth => 1, :remote_tag => @repo.tag)
          if succeeded? && @incremental && has_tag
            analysis = analyze_repo_tag
            if succeeded?
              is_tag = analysis[:tag]
              is_branch = analysis[:branch]
              on_branch = analysis[:on_branch]
              checkout = is_tag && !is_branch
              if is_tag && is_branch
                @errors << 'Repository tag ambiguous: could be git tag or git branch'
              elsif !is_tag && !is_branch
                current_sha = `git rev-parse HEAD`.chomp
                if current_sha == @repo.tag
                  @callback.call("Nothing to update: already using #{@repo.tag}", is_step=false) if @callback
                  return true
                else 
                  # Probably a SHA, retrieve all commits
                  git_fetch(:depth => 2**31 - 1)
                  checkout = true
                end
              end
            end
          end
          if succeeded?
            if checkout || is_branch && !on_branch
              git_checkout(@repo.tag)
            else # Pull latest commits on same branch
              git_fetch(:depth => 1, :merge => true, :remote_tag => @repo.tag)
            end
          end
        end
      end
      if !@incremental && succeeded?
        git_cmd = "#{@ssh_cmd} git clone --quiet --depth 1 \"#{@repo.url}\" \"#{@current_repo_dir}\" 2>&1"
        res = @watcher.launch_and_watch(git_cmd, @current_repo_dir)
        handle_watcher_result(res, 'git clone')
        if has_tag && succeeded?
          Dir.chdir(@current_repo_dir) do
            if is_tag.nil?
              analysis  = analyze_repo_tag
              is_tag    = analysis[:tag]
              is_branch = analysis[:branch]
              on_branch = analysis[:on_branch]
            end
            if succeeded?
              if is_tag && is_branch
                @errors << 'Repository tag ambiguous: could be git tag or git branch'
              elsif is_branch 
                if !on_branch
                  output = `git branch #{@repo.tag} origin/#{@repo.tag} 2>&1`
                  @errors << output if $? != 0
                end
              elsif !is_tag # Not a branch nor a tag, SHA ref? fetch everything so we have all SHAs
                git_fetch(:depth => 2**31 -1)
              end
              if succeeded? && !on_branch
                git_checkout(@repo.tag)
              end
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
      return win32_ssh_command if RUBY_PLATFORM=~/mswin/
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
      "GIT_SSH=#{ssh}"
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
        system("ssh -o StrictHostKeyChecking=no #{repo.url.split(':').first} exit 2>&1")
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
    def git_fetch(opts={})
      depth   = opts[:depth] || 2**31 - 1 # Specify max to override depth of already cloned repo
      remote  = opts[:remote_tag] 
      remote  = 'master' if remote.nil? || remote.rstrip.empty?
      action  = (opts[:merge] ? 'pull' : 'fetch')
      git_cmd = "#{@ssh_cmd} git #{action} --tags --depth #{depth} origin #{remote} 2>&1"
      res = @watcher.launch_and_watch(git_cmd, @current_repo_dir)
      handle_watcher_result(res, "git #{action}")
    end

    # Does a git checkout to given tag
    # Update errors collection upon failure (check for succeeded? after call)
    # Note: Assume that current working directory is a git directory
    #
    # === Parameters
    # tag(String):: Tag to checkout
    #
    # === Return
    # output(String):: Output of git command
    def git_checkout(tag)
      output = `git checkout #{tag} 2>&1`
      @errors << output if $? != 0
      output
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
    def analyze_repo_tag
      is_tag = is_branch = on_branch = nil
      begin
        is_tag = `git tag`.split("\n").include?(@repo.tag)
        is_branch = `git branch -r`.split("\n").map { |t| t.strip }.include?("origin/#{@repo.tag}")
        on_branch = is_branch && !!`git branch`.split("\n").include?("* #{@repo.tag}")
      rescue Exception => e
        @errors << "Analysis of repository tag failed with: #{e.message}"
      end
      res = { :tag => is_tag, :branch => is_branch, :on_branch => on_branch }
    end

  end
end
