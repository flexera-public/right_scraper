#--
# Copyright: Copyright (c) 2010-2016 RightScale, Inc.
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
require 'bundler/setup'

# legacy rspec depends on Test::Unit, which fails rspec runs that have any non-
# Test::Unit arguments. disable this nonsense.
require 'test/unit'
module ::Test::Unit::Options
  def process_args(args = [])
    {}
  end
end

require File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib', 'right_scraper'))

require 'logger'
require 'fileutils'
require 'flexmock'
require 'rspec'
require 'find'
require 'json'

RSpec.configure do |c|
  c.mock_with(:flexmock)
end

ENV["VALIDATE_URI"] ||= 'false'

# Helper module
module RightScraper

  module SpecHelpers
    # HACK: this three-part UUID hostname is unresolvable behind our firewall.
    # with only two parts our DNS server still tries to resolve it by appending
    # parts and fails only after a 2m timeout.
    BAD_HOSTNAME = 'bad.55aff53c7eeb0692a95c91c24e167695.com'

    module DevelopmentModeEnvironment
      def DevelopmentModeEnvironment.included(mod)
        mod.module_eval do
          before(:each) do
            @oldtest = ENV['VALIDATE_URI']
            ENV['VALIDATE_URI'] = 'false'
          end
          after(:each) do
            if @oldtest.nil?
              ENV.delete('VALIDATE_URI')
            else
              ENV['VALIDATE_URI'] = @oldtest
            end
          end
        end
      end
    end
    module ProductionModeEnvironment
      def ProductionModeEnvironment.included(mod)
        mod.module_eval do
          before(:each) do
            @oldtest = ENV['VALIDATE_URI']
            ENV.delete('VALIDATE_URI')
          end
          after(:each) do
            if @oldtest.nil?
              ENV.delete('VALIDATE_URI')
            else
              ENV['VALIDATE_URI'] = @oldtest
            end
          end
        end
      end
    end

    # represents a file name and content for creation by .create_file_layout
    class FileContent
      attr_reader :name, :content

      def initialize(name, content)
        @name = name
        @content = content
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

    class SpecHelperLoggerFormatter < ::Logger::Formatter
      def call(severity, time, progname, msg)
        "#{severity}: #{msg2str(msg)}\n"
      end
    end

    def make_scraper_logger
      # use a verbose logger for debugging when manually running rspec but
      # suppress output (in the normal scraper fashion) when running rake spec.
      if ENV[VERBOSE]
        logger = ::RightScraper::Loggers::Default.new(STDOUT)
        logger.formatter = SpecHelperLoggerFormatter.new
        logger.level = ::Logger::INFO
      else
        logger = ::RightScraper::Loggers::Default.new
      end
      logger
    end

    def make_retriever(repo, basedir)
      repo.retriever(
        :max_bytes   => 1024**2,
        :max_seconds => 20,
        :basedir     => basedir,
        :logger      => make_scraper_logger)
    end

    def make_scraper(retriever, kind = :cookbook)
      ::RightScraper::Scrapers::Base.scraper(
        :kind            => kind,
        :ignorable_paths => retriever.ignorable_paths,
        :repo_dir        => retriever.repo_dir,
        :freed_dir       => ::FileUtils.mkdir_p(::File.expand_path('../freed', retriever.repo_dir)).first,
        :repository      => retriever.repository,
        :logger          => retriever.logger)
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
        elsif elem.is_a?(FileContent)
          fullpath = ::File.join(path, elem.name)
          File.open(fullpath, 'w') { |f| f.write elem.content }
          result << fullpath
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
