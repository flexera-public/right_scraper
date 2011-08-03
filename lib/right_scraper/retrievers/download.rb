#--
# Copyright: Copyright (c) 2010-2011 RightScale, Inc.
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
require 'tempfile'
require 'digest/sha1'

module RightScraper
  module Retrievers
    # A retriever for resources stored in archives on a web server
    # somewhere.  Uses command line curl and command line tar.
    class Download < Base

      # Directory used to download tarballs
      def workdir
        File.join(@basedir, @repository.repository_hash)
      end

      # Path to directory where files are retrieved
      def repo_dir
        File.join(workdir, "archive")
      end

      # Download tarball and unpack it
      def retrieve
        FileUtils.remove_entry_secure workdir if File.exists?(workdir)
        FileUtils.mkdir_p repo_dir
        file = File.join(workdir, "package")

        @logger.operation(:downloading) do
          credential_command = if @repository.first_credential && @repository.second_credential
            ["-u", "#{@repository.first_credential}:#{@repository.second_credential}"]
          else
            []
          end
          ProcessWatcher.watch("curl", ["--silent", "--show-error", "--location", "--fail",
                                        "--location-trusted", "-o", file,
                                        credential_command, @repository.url].flatten,
                               workdir, @max_bytes || -1, @max_seconds || -1) do |phase, command, exception|
            @logger.note_phase(phase, :running_command, command, exception)
          end
        end

        note_tag(file)

        @logger.operation(:unpacking) do
          path = @repository.to_url.path
          if path =~ /\.gz$/
            extraction = "xzf"
          elsif path =~ /\.bz2$/
            extraction = "xjf"
          else
            extraction = "xf"
          end
          Dir.chdir(repo_dir) do
            ProcessWatcher.watch("tar", [extraction, file], repo_dir,
                                 @max_bytes || -1, @max_seconds || -1) do |phase, command, exception|
              @logger.note_phase(phase, :running_command, command, exception)
            end
          end
        end
      end

      # Amend @repository with the tag information from the downloaded
      # file.
      #
      # === Parameters
      # file(String):: file that was downloaded
      def note_tag(file)
        digest = Digest::SHA1.new
        File.open(file) {|f| digest << f.read(4096) }
        repo = @repository.clone
        repo.tag = digest.hexdigest
        @repository = repo
      end
    end
  end
end
