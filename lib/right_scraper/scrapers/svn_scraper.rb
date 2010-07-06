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

  class SvnScraper < ScraperBase

    # Check whether it is possible to perform an incremental update of the repo
    #
    # === Return
    # true:: Scrape directory contains files belonging to the scraped repo and protocol supports
    #        incremental updates
    # false:: Otherwise
    def incremental_update?
      return false unless File.directory?(@current_repo_dir)
      inc = false
      cookbooks_path = repo.cookbooks_path || []
      cookbooks_path = [ cookbooks_path ] unless cookbooks_path.is_a?(Array)
      if cookbooks_path.empty?
        Dir.chdir(@current_repo_dir) do
          info = `svn info`
          inc = $?.success? && info =~ (/^URL: (.*)$/) && $1 == @repo.url
        end
      else
        cookbooks_path.each do |path|
          Dir.chdir(File.join(@current_repo_dir, path)) do
            info = `svn info`
            inc = $?.success? && info =~ (/^URL: (.*)$/) && $1 == File.join(@repo.url, path)
            break unless inc
          end
        end
      end
      inc
    end

    # Scrape SVN repository, see RightScale::Scraper#scrape
    #
    # === Return
    # true:: Always return true
    def scrape_imp
      msg = @incremental ? "Updating " : "Checking out "
      msg += "SVN repository '#{@repo.display_name}'"
      @callback.call(msg, is_step=true) if @callback
      cookbooks_path = repo.cookbooks_path || []
      cookbooks_path = [ cookbooks_path ] unless cookbooks_path.is_a?(Array)
      if @incremental
        svn_cmd = "svn update --no-auth-cache --non-interactive --quiet" +
        (!@repo.tag.nil? && !@repo.tag.empty? ? " --revision #{@repo.tag}" : '') +
        (@repo.first_credential ? " --username #{@repo.first_credential}" : '') +
        (@repo.second_credential ? " --password #{@repo.second_credential}" : '') +
        ' 2>&1'
        if cookbooks_path.empty?
          Dir.chdir(@current_repo_dir) do
            res = @watcher.launch_and_watch(svn_cmd, @current_repo_dir)
            handle_watcher_result(res, 'SVN update')
          end
        else
          cookbooks_path.each do |path|
            break unless succeeded?
            full_path = File.join(@current_repo_dir, path)
            Dir.chdir(full_path) do
              res = @watcher.launch_and_watch(svn_cmd, @current_repo_dir)
              handle_watcher_result(res, 'SVN update')
            end
          end
        end
      end
      if !@incremental && succeeded?
        if cookbooks_path.empty?
          res = @watcher.launch_and_watch(svn_checkout_cmd, @current_repo_dir)
          handle_watcher_result(res, 'SVN checkout')
        else
          cookbooks_path.each do |path|
            break unless succeeded?
            res = @watcher.launch_and_watch(svn_checkout_cmd(path), @current_repo_dir)
            handle_watcher_result(res, 'SVN checkout')
          end
        end
      end
      true
    end

    # SVN checkout command using current repo definition and given path into it
    #
    # === Parameters
    # path(String):: Relative path inside repo that should be checked out
    #
    # === Return
    # svn_cmd(String):: Corresponding SVN command line
    def svn_checkout_cmd(path='')
      svn_cmd = "svn checkout \"#{File.join(@repo.url, path)}\" \"#{File.join(@current_repo_dir, path)}\" --no-auth-cache --non-interactive --quiet" +
      (!@repo.tag.nil? && !@repo.tag.empty? ? " --revision #{@repo.tag}" : '') +
      (@repo.first_credential ? " --username #{@repo.first_credential}" : '') +
      (@repo.second_credential ? " --password #{@repo.second_credential}" : '') +
      ' 2>&1'
    end
  end
end
