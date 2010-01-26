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
      Dir.chdir(@current_repo_dir) do
        info = `svn info`
        $?.success? && info =~ (/^URL: (.*)$/) && $1 == @repo.url
      end
    end

    # Scrape SVN repository, see RightScale::Scraper#scrape
    #
    # === Return
    # true:: Always return true
    def scrape_imp
      msg = @incremental ? "Updating " : "Checking out "
      msg += "SVN repository '#{@repo.display_name}'"
      @callback.call(msg, is_step=true) if @callback
      if @incremental
        svn_cmd = "svn update --non-interactive --quiet" +
        (@repo.first_credential ? " --username #{@repo.first_credential}" : '') +
        (@repo.second_credential ? " --password #{@repo.second_credential}" : '') +
        ' 2>&1'
        Dir.chdir(@current_repo_dir) do
          res = `#{svn_cmd}`
          if $? != 0
            @callback.call("Failed to update repo: #{res}, falling back to checkout", is_step=false) if @callback
            FileUtils.rm_rf(@current_repo_dir)
            @incremental = false
          end
        end
      end
      if !@incremental
        svn_cmd = "svn checkout #{@repo.url} #{@current_repo_dir} --non-interactive --quiet" +
        (!@repo.tag.nil? && !@repo.tag.empty? ? " --revision #{@repo.tag}" : '') +
        (@repo.first_credential ? " --username #{@repo.first_credential}" : '') +
        (@repo.second_credential ? " --password #{@repo.second_credential}" : '') +
        ' 2>&1'
        res = `#{svn_cmd}`
        @errors << res if $? != 0
      end
      true
    end

  end
end
