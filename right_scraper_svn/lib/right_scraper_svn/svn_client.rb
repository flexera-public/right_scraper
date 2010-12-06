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
require 'process_watcher'

module RightScraper
  # Simplified interface to the process of creating SVN client
  # contexts.
  #
  # SVN client contexts are needed for almost every nontrivial SVN
  # operation, and the authentication procedure is truly baroque.
  # Thus, when you need a client context, do something like this:
  #   client = SvnClient.new(repository)
  #   client.with_context do |ctx|
  #     ...
  #   end
  module SvnClient
    def svn_arguments
      args = ["--no-auth-cache", "--non-interactive", "--trust-server-cert"]
      if repository.first_credential && repository.second_credential
        args << "--username"
        args << repository.first_credential
        args << "--password"
        args << repository.second_credential
      end
      args
    end

    def get_tag_argument
      if repository.tag
        tag_cmd = ["-r", get_tag.to_s]
      else
        tag_cmd = ["-r", "HEAD"]
      end
    end

    def run_svn_no_chdir(*args)
      ProcessWatcher.watch("svn", [args, svn_arguments].flatten,
                           basedir, @max_bytes || -1, @max_seconds || -1) do |phase, operation, exception|
        #$stderr.puts "#{phase} #{operation} #{exception}"
      end
    end

    def run_svn(*args)
      Dir.chdir(basedir) do
        run_svn_no_chdir(*args)
      end
    end

    # Fetch the tag from the repository, or nil if one doesn't
    # exist.  This is a separate method because the repo tag should
    # be a number but is a string in the database.
    def get_tag
      case repository.tag
      when Fixnum then repository.tag
      when /^\d+$/ then repository.tag.to_i
      else
        repository.tag
      end
    end
  end
end
