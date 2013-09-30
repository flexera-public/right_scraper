#--
# Copyright: Copyright (c) 2013 RightScale, Inc.
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

require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

require 'fileutils'
require 'tmpdir'

class WardenSpecHelper

  DESCRIBED_CLASS = ::RightScraper::Processes::Warden
  MOCK_WARDEN_DIR = ::File.join(::Dir.tmpdir, 'WardenSpecHelper-611106fe')

  MOCK_WARDEN_SCRIPT = <<EOS
#!#{`which ruby`.strip}

MOCK_WARDEN_HANDLE = '172dmrjrk7q'

MOCK_JOB_ID = 42

MOCK_WARDEN_DIR = #{MOCK_WARDEN_DIR.inspect}
MOCK_HANDLE_DIR = ::File.join(MOCK_WARDEN_DIR, MOCK_WARDEN_HANDLE)
MOCK_JOB_DIR    = ::File.join(MOCK_HANDLE_DIR, MOCK_JOB_ID.to_s)

unless ARGV[0] == '--'
  STDERR.puts "ARGV = \#\{ARGV.inspect\}\"
  exit 100
end
warden_args = { :action => ARGV[1] }
(1..(ARGV.size / 2 - 1)).each do |index|
  warden_args[ARGV[index * 2]] = ARGV[index * 2 + 1]
end
STDERR.puts "warden_args = \#\{warden_args.inspect\}\"
unless warden_args[:action] == 'create'
  exit 101 unless warden_args['--handle'] == MOCK_WARDEN_HANDLE
end
case warden_args[:action]
when 'create'
  exit 10 if ::File.directory?(MOCK_HANDLE_DIR)
  ::FileUtils.mkdir_p(MOCK_HANDLE_DIR)
  STDOUT.puts \"handle : \#\{MOCK_WARDEN_HANDLE\}\"
when 'destroy'
  ::FileUtils.rm_rf(MOCK_HANDLE_DIR)
when 'copy_in', 'copy_out'
  src_path = warden_args['--src_path']
  dst_path = warden_args['--dst_path']
  exit 20 unless src_path && dst_path
  exit 21 unless ::File.file?(src_path)
  exit 22 unless ::File.directory?(::File.dirname(dst_path))

  # want paths to be valid for scripts run in mock 'jail'; simple file copy.
  # skip copying if same path.
  if src_path != dst_path
    exit 23 if ::File.file?(dst_path)
    ::FileUtils.cp(src_path, dst_path)
  end
when 'spawn'
  script = warden_args['--script']
  exit 30 unless script
  ::FileUtils.mkdir_p(MOCK_JOB_DIR)
  ::Dir.chdir(MOCK_JOB_DIR) do
    cmd = script
    cmd += ' 2>mock_stderr.txt' unless cmd.index('2>')
    output = \`\#\{cmd\}\`
    ::File.open('mock_exit_status.txt', 'w') { |f| f.write $?.exitstatus.to_s }
    ::File.open('mock_stdout.txt', 'w') { |f| f.write output }
  end
  STDOUT.puts \"job_id : \#\{MOCK_JOB_ID\}\"
when 'link'
  ::Dir.chdir(MOCK_JOB_DIR) do
    mock_link_result = {
      'exit_status' => ::File.read('mock_exit_status.txt').strip.to_i,
      'stdout' => ::File.read('mock_stdout.txt'),
      'stderr' => ::File.read('mock_stderr.txt')
    }
    STDOUT.puts \"exit_status : \#\{mock_link_result['exit_status']\}\"
    STDOUT.puts \"stdout : \#\{mock_link_result['stdout']\}\"
    STDOUT.puts \"stderr : \#\{mock_link_result['stderr']\}\"
  end
  ::FileUtils.rm_rf(MOCK_JOB_DIR)
else
  exit 99
end
exit 0
EOS

  def self.setup
    # allow for-reals-warden integration testing on a box that supports it,
    # which is likely only to be a test server since the setup is painful.
    # otherwise mock warden with a dummy script.
    if ::File.directory?(DESCRIBED_CLASS::DEFAULT_WARDEN_HOME)
      @mock_warden_home = nil
      @mock_rvm_home = nil  # if warden is installed then rvm must be also
    else
      mock_warden_home = ::File.join(MOCK_WARDEN_DIR, DESCRIBED_CLASS::DEFAULT_WARDEN_HOME)
      ::FileUtils.mkdir_p(mock_warden_home)
      mock_bin_warden_dir = ::File.join(mock_warden_home, DESCRIBED_CLASS::WARDEN_SERVICE_SUBDIR_NAME)
      mock_gemfile = ::File.join(mock_bin_warden_dir, 'Gemfile')
      mock_warden_script = ::File.join(mock_bin_warden_dir, DESCRIBED_CLASS::RELATIVE_WARDEN_SCRIPT_PATH)

      # cleanup after any failed tests.
      ::FileUtils.rm_rf(MOCK_WARDEN_DIR) if ::File.directory?(MOCK_WARDEN_DIR)

      # create mock scripts.
      ::FileUtils.mkdir_p(::File.dirname(mock_warden_script))
      ::File.open(mock_warden_script, 'w') { |f| f.puts MOCK_WARDEN_SCRIPT }
      ::File.chmod(0760, mock_warden_script)
      ::File.open(mock_gemfile, 'w') { |f| f.puts '# no gems' }

      # always mock rvm because we don't want to require a specific version of
      # ruby to be installed in the dev's rvm for the unit test to work.
      mock_rvm_home = ::File.join(MOCK_WARDEN_DIR, DESCRIBED_CLASS::DEFAULT_RVM_HOME)

      mock_scripts_rvm_path = ::File.join(mock_rvm_home, DESCRIBED_CLASS::RELATIVE_SCRIPTS_RVM_PATH)
      ::FileUtils.mkdir_p(::File.dirname(mock_scripts_rvm_path))
      ::File.open(mock_scripts_rvm_path, 'w') do |f|
        f.puts '#!/bin/bash'
        f.puts "echo mocks rvm setup"
      end
      ::File.chmod(0760, mock_scripts_rvm_path)

      mock_rvm_bin_dir = ::File.join(mock_rvm_home, 'bin')
      mock_bin_rvm_script = ::File.join(mock_rvm_bin_dir, 'rvm')
      ::FileUtils.mkdir_p(mock_rvm_bin_dir)
      ::File.open(mock_bin_rvm_script, 'w') do |f|
        f.puts '#!/bin/bash'
        f.puts "echo mocks rvm use"
      end
      ::File.chmod(0760, mock_bin_rvm_script)

      # add rvm bin dir to PATH via Bundler::ORIGINAL_ENV since warden wrapper
      # will run warden scripts with clean_env.
      value = ::Bundler::ORIGINAL_ENV['PATH']
      unless value.index(mock_rvm_bin_dir)
        value = "#{mock_rvm_bin_dir}#{File::PATH_SEPARATOR}#{value}"
        ::Bundler::ORIGINAL_ENV['PATH'] = value
      end

      # constants
      @mock_warden_home = mock_warden_home
      @mock_rvm_home = mock_rvm_home
    end
    true
  end

  def self.teardown
    if @mock_warden_home
      #::FileUtils.rm_rf(MOCK_WARDEN_DIR) rescue nil
      mock_rvm_bin_dir = ::File.join(@mock_rvm_home, 'bin')
      @mock_warden_home = nil
      @mock_rvm_home = nil

      # remove mock rvm from PATH
      value = ::Bundler::ORIGINAL_ENV['PATH']
      if offset = value.index(mock_rvm_bin_dir)
        value = value[(offset + mock_rvm_bin_dir.length + 1)..-1]
        ::Bundler::ORIGINAL_ENV['PATH'] = value
      end
    end
  end

  def self.warden_home
    @mock_warden_home ? @mock_warden_home : DESCRIBED_CLASS::DEFAULT_WARDEN_HOME
  end

  def self.rvm_home
    @mock_rvm_home ? @mock_rvm_home : DESCRIBED_CLASS::DEFAULT_RVM_HOME
  end
end

module RightScraper
  module Processes
    class Warden
      WARDEN_COMMAND_TIMEOUT = 5  # shorter timeout for unit tests
    end
  end
end

describe RightScraper::Processes::Warden do

  include RightScraper::SpecHelpers

  subject do
    described_class.new(
      :warden_home => ::WardenSpecHelper.warden_home,
      :rvm_home    => ::WardenSpecHelper.rvm_home)
  end

  before(:all) do
    ::WardenSpecHelper.setup
  end

  after(:all) do
    ::WardenSpecHelper.teardown
  end

  after(:each) do
    subject.cleanup
  end

  context '#run_command_in_jail' do

    it 'should run a simple command' do
      result = subject.run_command_in_jail('echo hello world')
      result.strip.should == 'hello world'
    end

    it 'should run a command with jailed files' do
      ::Dir.mktmpdir do |tmpdir|
        in_files_dir_name = 'in_files'
        jailed_files_dir_name = 'jailed_files'
        out_files_dir_name = 'out_files'
        result_file_name = 'result.txt'

        in_files_dir = ::File.join(tmpdir, in_files_dir_name)
        jailed_files_dir = ::File.join(tmpdir, jailed_files_dir_name)
        out_files_dir = ::File.join(tmpdir, out_files_dir_name)

        files = ('a'..'f').to_a
        create_file_layout(::File.join(tmpdir, in_files_dir_name), files)

        jailed_result_path = ::File.join(jailed_files_dir, result_file_name)
        out_result_path = ::File.join(out_files_dir, result_file_name)

        cmd = [
          "ls #{jailed_files_dir.inspect}",
          "echo success>#{jailed_result_path.inspect}"
        ]
        copy_in = files.inject({}) do |result, name|
          src_path = ::File.join(in_files_dir, name)
          dst_path = ::File.join(jailed_files_dir, name)
          fail "in-file does not exist: #{src_path.inspect}" unless ::File.file?(src_path)
          result[src_path] = dst_path
          result
        end
        copy_out = { jailed_result_path => out_result_path }
        result = subject.run_command_in_jail(cmd, copy_in, copy_out)
        ::File.read(out_result_path).strip.should == 'success'
        result.strip.split("\n").sort.should == files
      end
    end

    it 'should timeout when a command exceeds time limit' do
      cmd = "sleep #{::RightScraper::Processes::Warden::WARDEN_COMMAND_TIMEOUT + 1}"
      expect { subject.run_command_in_jail(cmd) }.
        to raise_error(
          ::RightScraper::Processes::Warden::WardenError,
          'Timed out waiting for warden to respond')
    end

  end

end
