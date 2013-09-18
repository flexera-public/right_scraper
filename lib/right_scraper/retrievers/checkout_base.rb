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

module RightScraper::Retrievers

  # Base class for retrievers that want to do version control operations
  # (CVS, SVN, etc.). Subclasses can get away with implementing only
  # Retrievers::Base#available? and #do_checkout but to support incremental
  # operation need to implement #exists? and #do_update, in addition to
  # Retrievers::Base#ignorable_paths.
  class CheckoutBase < ::RightScraper::Retrievers::Base

    # Attempts to update and then resorts to clean checkout for repository.
    def retrieve
      raise RetrieverError.new("retriever is unavailable") unless available?
      updated = false
      explanation = ''
      if exists?
        @logger.operation(:updating) do
          # a retriever may be able to determine that the repo directory is
          # already pointing to the same commit as the revision. in that case
          # we can return quickly.
          if remote_differs?
            # there is no point in updating and failing the size check when the
            # directory on disk already exceeds size limit; fall back to a clean
            # checkout in hopes that the latest revision corrects the issue.
            if size_limit_exceeded?
              explanation = 'switching to checkout due to existing directory exceeding size limimt'
            else
              # attempt update.
              begin
                do_update
                updated = true
              rescue ::RightScraper::Processes::Shell::LimitError
                # update exceeded a limitation; requires user intervention
                raise
              rescue Exception => e
                # retry with clean checkout after discarding repo dir.
                explanation = 'switching to checkout after unsuccessful update'
              end
            end
          else
            # no retrieval needed.
            @logger.note_warning('Skipped updating local directory due to the HEAD commit SHA on local matching the remote repository reference.')
            return false
          end
        end
      end

      # Clean checkout only if not updated.
      unless updated
        @logger.operation(:checkout, explanation) do
          # remove any full or partial directory before attempting a clean
          # checkout in case repo_dir is in a bad state.
          if exists?
            ::FileUtils.remove_entry_secure(@repo_dir)
          end
          ::FileUtils.mkdir_p(@repo_dir)
          begin
            do_checkout
          rescue Exception
            # clean checkout failed; repo directory is in an undetermined
            # state and must be deleted to prevent a future update attempt.
            if exists?
              ::FileUtils.remove_entry_secure(@repo_dir) rescue nil
            end
            raise
          end
        end
      end
      true
    end

    # Return true if a checkout exists.
    #
    # === Returns
    # Boolean:: true if the checkout already exists (and thus
    #           incremental updating can occur).
    def exists?
      false
    end

    # Determines if the remote SHA/tag/branch referenced by the repostory
    # differs from what appears on disk, if possible. Not all retrievers will
    # have this capability. If not, the retriever should default to returning
    # true to indicate that the remote is changed.
    #
    # @return [TrueClass|FalseClass] true if changed
    def remote_differs?
      true
    end

    # Determines if total size of files in repo_dir has exceeded size limit.
    #
    # === Return
    # @return [TrueClass|FalseClass] true if size limit exceeded
    def size_limit_exceeded?
      if @max_bytes
        # note that Dir.glob ignores hidden directories (e.g. ".git") so the
        # size total correctly excludes those hidden contents that are not to
        # be uploaded after scrape. this may cause the on-disk directory size
        # to far exceed the upload size.
        globbie = ::File.join(@repo_dir, '**/*')
        size = 0
        ::Dir.glob(globbie) do |f|
          size += ::File.stat(f).size rescue 0 if ::File.file?(f)
          break if size > @max_bytes
        end
        size > @max_bytes
      else
        false
      end
    end

    # Perform an incremental update of the checkout.  Subclasses that
    # want to handle incremental updating need to override this.
    def do_update
      raise NotImplementedError
    end

    # Perform a de novo full checkout of the repository.  Subclasses
    # must override this to do anything useful.
    def do_checkout
      raise NotImplementedError
    end

  end
end
