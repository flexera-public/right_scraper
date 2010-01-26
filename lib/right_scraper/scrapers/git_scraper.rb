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
      msg = @incremental ? "Pulling " : "Cloning "
      msg += "git repository '#{@repo.display_name}'"
      @callback.call(msg, is_step=true) if @callback
      ssh_cmd = ssh_command
      res = ""
      is_tag = nil
      is_branch = nil

      if @incremental
        Dir.chdir(@current_repo_dir) do
          is_tag, is_branch, res = git_tag_kind(ssh_cmd)
          if !is_tag && !is_branch
            @callback.call("Nothing to update: repo tag refers to neither a branch nor a tag", is_step=false)
            return true
          end
          if is_tag && is_branch
            @errors << 'Repository tag ambiguous: could be git tag or git branch'
          else
            tag = @repo.tag.nil? || @repo.tag.empty? ? 'master' : @repo.tag
            res += `#{ssh_cmd} git pull --quiet --depth 1 origin #{tag} 2>&1`
            if $? != 0
              @callback.call("Failed to pull repo: #{res}, falling back to cloning", is_step=false) if @callback
              FileUtils.rm_rf(@current_repo_dir)
              @incremental = false
            end
          end
        end
      end
      if !@incremental
        res += `#{ssh_cmd} git clone --quiet --depth 1 #{@repo.url} #{@current_repo_dir} 2>&1`
        @errors << res if $? != 0
        if !@repo.tag.nil? && !@repo.tag.empty? && @repo.tag != 'master' && succeeded?
          Dir.chdir(@current_repo_dir) do
            if is_tag.nil?
              is_tag, is_branch, out = git_tag_kind(ssh_cmd)
              res += out
            end
            if is_tag && is_branch
              @errors << 'Repository tag ambiguous: could be git tag or git branch'
            elsif is_branch
              res += `git branch #{@repo.tag} origin/#{@repo.tag} 2>&1`
              @errors << res if $? != 0
            elsif !is_tag # Not a branch nor a tag, SHA ref? fetch everything so we have all SHAs
              res += `#{ssh_cmd} git fetch origin master --depth #{2**31 - 1} 2>&1`
              @errors << res if $? != 0
            end
            if succeeded?
              res += `git checkout #{@repo.tag} 2>&1`
              @errors << res if $? != 0
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

    # Store public SSH key into temporary folder and create temporary script
    # that wraps SSH and uses this key.
    #
    # === Return
    # ssh(String):: Code to initialize GIT_SSH environment variable with path to SSH wrapper script
    def ssh_command
      ssh_dir = File.join(@scrape_dir_path, '.ssh')
      FileUtils.mkdir_p(ssh_dir)
      key_content = @repo.first_credential
      if key_content.nil?
        # Explicitely disable public key authentication so we don't endup using the system's key
        options = { :PubkeyAuthentication => 'no' }
      else    
        ssh_key_path = File.join(ssh_dir, 'ssh.pub')
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

    # Resolves whehter repository tag is a git tag or a git branch
    # Return output of run commands too
    # Note:: Assume that current working directory is a git directory
    #
    # === Parameters
    # ssh_cmd<String>:: SSH command to be used with git if any
    #
    # === Return
    # res<Array>::
    #   - res[0] is true if git repo has a tag with a name corresponding to the repository tag
    #   - res[1] is true if git repo has a branch with a name corresponding to the repository tag
    #   - res[2] contains the git output
    def git_tag_kind(ssh_cmd)
      return [ false, true, "" ] if @repo.tag.nil? || @repo.tag.empty? || @repo.tag == 'master'
      output = `#{ssh_cmd} git fetch --tags --depth 1 2>&1`
      is_tag = `git tag`.split("\n").include?(@repo.tag)
      is_branch = `git branch -r`.split("\n").map { |t| t.strip }.include?("origin/#{@repo.tag}")
      res = [ is_tag, is_branch, output ]
    end

  end
end
