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

require 'rubygems'
require 'flexmock'
require 'spec'
require 'find'
require 'json'

$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib')))

Spec::Runner.configuration.mock_with :flexmock

# Helper module
module RightScale

  module SpecHelpers

    # Set the 'verbose' environment variable for debugging a failing spec
    VERBOSE='verbose'

    # Execute given shell command and return output and exit code
    # Allows centralizing logging/output
    #
    # === Parameters
    # cmd(String):: Command to be run
    #
    # === Return
    # res, process status(Array):: Pair whose first element is the output of the command
    #                              and second element is the process exit status
    def exec(cmd)
      puts "+ [#{Dir.pwd}] #{cmd}" if ENV[VERBOSE]
      res = `#{cmd} 2>&1`
      puts res unless res.empty? if ENV[VERBOSE]
      return res, $?
    end

    def create_cookbook(path, contents)
      create_file_layout(path, contents)
      File.open(File.join(path, 'metadata.json'), 'w') { |f|
        f.puts contents.to_json
      }
    end

    # Create file layout from given array
    # Strings in array correspond to files while Hashes correspond to folders
    # File content is equal to filename
    #
    # === Parameters
    # Path(String):: Path where layout should be created
    # layout(Array):: Describe the file layout to be created
    #
    # === Return
    # true:: Always return true
    def create_file_layout(path, layout)
      FileUtils.mkdir_p(path)
      layout.each do |elem|
        if elem.is_a?(Hash)
          elem.each do |k, v|
            full_path = File.join(path, k)
            FileUtils.mkdir_p(full_path)
            create_file_layout(full_path, v)
          end
        else
          File.open(File.join(path, elem.to_s), 'w') { |f| f.puts elem.to_s }
        end
      end
      true
    end

    # Extract array representing file layout for given directory
    #
    # === Parameters
    # path(String):: Path to directory whose layout is to be retrieved
    # layout(Array):: Array being updated with layout, same as return value, empty array by default
    # ignore(Array):: Optional: Name of files or directories that should be ignored
    #
    # === Return
    # layout(Array):: Corresponding layout as used by 'create_file_layout'
    def extract_file_layout(path, ignore=[])
      return [] unless File.directory?(path)
      dirs = []
      files = []
      ignore += [ '.', '..' ]
      Dir.foreach(path) do |f|
        next if ignore.include?(f)
        full_path = File.join(path, f)
        if File.directory?(full_path)
          dirs << { f => extract_file_layout(full_path, ignore) }
        else
          files << f
        end
      end
      dirs + files.sort
    end

    Spec::Matchers.define :begin_with do |path|
      match do |directory|
        directory[0...path.length] == path
      end
    end
  end

end
