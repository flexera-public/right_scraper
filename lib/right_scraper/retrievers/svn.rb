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
require File.join(File.dirname(__FILE__), '..', 'svn_client')

module RightScraper
  module Retrievers
    # Retriever for svn repositories
    class Svn < CheckoutBasedRetriever

      include RightScraper::SvnClient

      @@available = false

      # Determines if svn is available.
      def available?
        unless @@available
          begin
            calculate_version
            @@available = true
          rescue SvnClientError => e
            @logger.note_error(e, :available, "svn retriever is unavailable")
          end
        end
        @@available
      end

      # Return true if a checkout exists.  Currently tests for .svn in
      # the checkout.
      #
      # === Returns
      # Boolean:: true if the checkout already exists (and thus
      #           incremental updating can occur).
      def exists?
        File.exists?(File.join(@repo_dir, '.svn'))
      end

      # Incrementally update the checkout.  The operations are as follows:
      # * update to #tag
      # In theory if #tag is a revision number that already exists no
      # update is necessary.  It's not clear if the SVN client libraries
      # are bright enough to notice this.
      def do_update
        @logger.operation(:update) do
          run_svn("update", get_tag_argument)
        end
        do_update_tag
      end

      # Update our idea of what the head of the repository is.  We
      # would like to use svn info, but that doesn't do the right
      # thing all the time; the right thing to do is to run log and
      # pick out the first tag.
      def do_update_tag
        @repository = @repository.clone
        lines = run_svn_with_buffered_output("log", "-r", 'HEAD')
        lines.each do |line|
          if line =~ /^r(\d+)/
            @repository.tag = $1
            break
          end
        end
      end

      # Check out the remote repository.  The operations are as follows:
      # * checkout repository at #tag to @repo_dir
      def do_checkout
        super
        @logger.operation(:checkout_revision) do
          run_svn_no_chdir("checkout", @repository.url, @repo_dir, get_tag_argument)
        end
        do_update_tag
      end

      # Ignore .svn directories.
      def ignorable_paths
        ['.svn']
      end
    end
  end
end
