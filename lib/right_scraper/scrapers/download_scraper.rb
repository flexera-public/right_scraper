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

  class DownloadScraper < ScraperBase

    # Download and expand remote repository, see RightScale::ScraperBase#scrape
    #
    # === Return
    # true:: Always return true
    def scrape_imp
      msg = "Downloading repository '#{@repo.display_name}'"
      @callback.call(msg, is_step=true) if @callback
      filename = @repo.url.split('/').last
      user_opt = @repo.first_credential && @repo.second_credential ? "--user #{@repo.first_credential}:#{@repo.second_credential}" : ''
      cmd = "curl --fail --silent --show-error --insecure --location #{user_opt} --output '#{@current_repo_dir}/#{filename}' '#{@repo.url}' 2>&1"
      FileUtils.mkdir_p(@current_repo_dir)
      res = `#{cmd}`
      @errors << res if $? != 0
      if succeeded?
        unzip_opt = case @repo.url[/\.(.*)$/]
          when 'bzip', 'bzip2', 'bz2' then 'j'
          when 'tgz', 'gzip', 'gz' then 'z'
          else ''
        end
        Dir.chdir(@current_repo_dir) do
          cmd = "tar x#{unzip_opt}f #{filename} 2>&1"
          res = `#{cmd}`
          @errors << res if $? != 0
          File.delete(filename)
        end
      end
      true
    end

  end
end
