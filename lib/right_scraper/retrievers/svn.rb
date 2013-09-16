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

module RightScraper::Retrievers

  # Retriever for svn repositories
  class Svn < ::RightScraper::Retrievers::CheckoutBase

    SVN_CLIENT = ::RightScraper::Processes::SvnClient

    @@available = false

    # Determines if svn is available.
    def available?
      unless @@available
        begin
          SVN_CLIENT.calculate_version
          @@available = true
        rescue SVN_CLIENT::SvnClientError => e
          @logger.note_error(e, :available, 'svn retriever is unavailable')
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
      ::File.exists?(::File.join(@repo_dir, '.svn'))
    end

    # Ignore .svn directories.
    def ignorable_paths
      ['.svn']
    end

    # Check out the remote repository.  The operations are as follows:
    # * checkout repository at #tag to @repo_dir
    def do_checkout
      @logger.operation(:checkout_revision) do
        revision = resolve_revision
        svn_args = ['checkout', @repository.url, @repo_dir]
        svn_args += ['--revision', revision] if revision
        svn_args << '--force'
        svn_client.execute(svn_args)
        do_update_tag
      end
    end

    # Incrementally update the checkout.  The operations are as follows:
    # * update to #tag
    # In theory if #tag is a revision number that already exists no
    # update is necessary.  It's not clear if the SVN client libraries
    # are bright enough to notice this.
    def do_update
      @logger.operation(:update) do
        svn_client.execute('update', revision_argument)
        do_update_tag
      end
    end

    def do_update_tag
      @repository = @repository.clone
      # note that 'svn info' does not appear to always give correct revision.
      svn_args = ['log', '--revision', 'HEAD']
      svn_client.output_for(svn_args).lines.each do |line|
        if matched = SVN_LOG_REGEX.match(line)
          @repository.tag = matched[1]
          break
        end
      end
    end

    private

    # http://svnbook.red-bean.com/en/1.7/svn.tour.revs.specifiers.html#svn.tour.revs.keywords
    # Example: HEAD | <revision number> | {<datetime>}
    SVN_REVISION_REGEX = /^(HEAD|\d+|\{[0-9:-T+-]+\})$/

    # Example:
    # r12 | ira | 2006-11-27 12:31:51 -0600 (Mon, 27 Nov 2006) | 6 lines
    SVN_LOG_REGEX = /^r(\d+)/  # ignoring additional info after revision

    def resolve_revision
      revision = @repository.tag.to_s.strip
      if revision.empty?
        revision = nil
      elsif (revision =~ SVN_REVISION_REGEX).nil?
        raise RetrieverError, "Revision reference contained illegal characters: #{revision.inspect}"
      end
      revision
    end

    def svn_client
      @svn_client ||= SVN_CLIENT.new(
        @repository,
        @logger,
        ::RightScraper::Processes::Shell.new(
          :initial_directory => self.repo_dir,
          :max_bytes         => self.max_bytes,
          :max_seconds       => self.max_seconds,
          :watch_directory   => self.repo_dir))
    end

  end
end
