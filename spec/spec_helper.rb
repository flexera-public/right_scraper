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

require 'rubygems'
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib', 'right_scraper'))

require 'flexmock'
require 'rspec'
require 'find'
require 'json'

RSpec.configure do |c|
  c.mock_with(:flexmock)
end

ENV["DEVELOPMENT"] ||= "yes"

# Helper module
module RightScraper

  module SpecHelpers
    module DevelopmentModeEnvironment
      def DevelopmentModeEnvironment.included(mod)
        mod.module_eval do
          before(:each) do
            @oldtest = ENV['DEVELOPMENT']
            ENV['DEVELOPMENT'] = "yes"
          end
          after(:each) do
            if @oldtest.nil?
              ENV.delete('DEVELOPMENT')
            else
              ENV['DEVELOPMENT'] = @oldtest
            end
          end
        end
      end
    end
    module ProductionModeEnvironment
      def ProductionModeEnvironment.included(mod)
        mod.module_eval do
          before(:each) do
            @oldtest = ENV['DEVELOPMENT']
            ENV.delete('DEVELOPMENT')
          end
          after(:each) do
            if @oldtest.nil?
              ENV.delete('DEVELOPMENT')
            else
              ENV['DEVELOPMENT'] = @oldtest
            end
          end
        end
      end
    end

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
      File.open(File.join(path, 'metadata.json'), 'w') { |f| f.puts contents.to_json }
    end

    def create_workflow(path, name, definition, metadata)
      File.open(File.join(path, "#{name}#{RightScraper::Resources::Workflow::DEFINITION_EXT}"), 'w') { |f| f.puts definition }
      File.open(File.join(path, "#{name}#{RightScraper::Resources::Workflow::METADATA_EXT}"), 'w') { |f| f.puts metadata.to_json }
    end

    # Create file layout from given array
    # Strings in array correspond to files while Hashes correspond to folders
    # File content is equal to filename
    #
    # === Parameters
    # @param [String] path where layout should be created
    # @param [Array] layout to be created
    #
    # === Return
    # @return [Array] list of created file paths
    def create_file_layout(path, layout)
      FileUtils.mkdir_p(path)
      result = []
      layout.each do |elem|
        if elem.is_a?(Hash)
          elem.each do |k, v|
            full_path = File.join(path, k)
            FileUtils.mkdir_p(full_path)
            result += create_file_layout(full_path, v)
          end
        else
          fullpath = ::File.join(path, elem.to_s)
          File.open(fullpath, 'w') { |f| f.puts elem.to_s }
          result << fullpath
        end
      end
      result
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

    RSpec::Matchers.define :begin_with do |path|
      match do |directory|
        directory[0...path.length] == path
      end
    end
  end

  module SharedExamples
    shared_examples_for "a normal repository" do
      it 'should scrape' do
        @scraper.scrape(@repo)
        @scraper.succeeded?.should be_true
        @scraper.resources.should_not == []
        @scraper.resources.size.should == 1
        @scraper.resources[0].manifest.should == {
                "folder1/file3"=>"60b91f1875424d3b4322b0fdd0529d5d",
                "file1"=>"5149d403009a139c7e085405ef762e1a",
                "folder2/folder3/file4"=>"857c6673d7149465c8ced446769b523c",
                "metadata.json"=>"7c72b234162002a96f4ba60f0db38601",
                "folder1/file2"=>"3d709e89c8ce201e3c928eb917989aef"}
        @scraper.resources[0].metadata.should == [{"folder1"=>["file2", "file3"]},
                                                  {"folder2"=>[{"folder3"=>["file4"]}]},
                                                  "file1"]
      end
    end
  end

end
