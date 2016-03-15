#
# Copyright (c) 2013 RightScale Inc
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

require 'logger'
require 'stringio'
require 'tmpdir'

describe RightScraper::Processes::Shell do

  let(:logger)        { flexmock('logger') }
  let(:is_windows)    { !!(RUBY_PLATFORM =~ /mswin|win32|dos|mingw|cygwin/) }
  let(:command_shell) { is_windows ? 'cmd.exe /C' : 'sh -c' }
  let(:message)       { 'hello world' }

  let(:shell_execute_options) { { :logger => logger } }

  subject { described_class.new(shell_options) }

  shared_examples_for 'a scraper shell' do
    context '#execute' do
      it 'should execute' do
        cmd = "#{command_shell} \"echo #{message}\""
        logger.
          should_receive(:info).
          with("+ #{cmd}").
          and_return(true).
          once
        subject.execute(cmd, shell_execute_options).should == 0
      end

      it 'should execute in a specified directory' do
        ::Dir.mktmpdir do |temp_dir|
          expected_dir = ::File.expand_path(temp_dir)
          if is_windows
            cmd = "#{command_shell} \"echo %CD%\""
            expected_dir.gsub!('/', "\\")
          else
            cmd = 'pwd'
          end
          expected_output = expected_dir + (is_windows ? " \n" : "\n")
          logger.
            should_receive(:info).
            with("+ #{cmd}").
            and_return(true).
            once
          actual = subject.execute(
            cmd, shell_execute_options.merge(:directory => temp_dir))
          actual.should == 0
        end
      end

      it 'should raise on failure by default' do
        cmd = "#{command_shell} \"exit 99\""
        logger.
          should_receive(:info).
          with("+ #{cmd}").
          and_return(true).
          once
        expect { subject.execute(cmd, shell_execute_options) }.
          to raise_error(
           ::RightScraper::Error,
            "Execution failed: Exit code = 99")
      end

      it 'should not raise on failure by request' do
        cmd = "#{command_shell} \"exit 99\""
        logger.
          should_receive(:info).
          with("+ #{cmd}").
          and_return(true).
          once
        actual = subject.execute(
          cmd, shell_execute_options.merge(:raise_on_failure => false))
        actual.should == 99
      end
    end # execute

    context '#output_for' do
      it 'should execute and return output' do
        cmd = "#{command_shell} \"echo #{message}\""
        logger.
          should_receive(:info).
          with("+ #{cmd}").
          and_return(true).
          once
        actual_message = subject.output_for(cmd, shell_execute_options)
        actual_message.should == message
      end
    end
  end

  context 'with default options' do
    let(:shell_options) do
      {
        :initial_directory => nil,
        :max_bytes         => nil,
        :max_seconds       => nil,
        :watch_directory   => nil,
      }
    end

    it_should_behave_like 'a scraper shell'
  end

  context 'with specific options' do
    before(:each) do
      @tmpdir = ::Dir.mktmpdir
    end

    after(:each) do
      (::FileUtils.rm_rf(@tmpdir) rescue nil) if ::File.directory?(@tmpdir)
    end

    context 'when limits are not exceeded' do
      let(:shell_options) do
        {
          :initial_directory => @tmpdir,
          :max_bytes         => 200 * 1024 * 1024,
          :max_seconds       => 600,
          :watch_directory   => @tmpdir,
        }
      end

      it_should_behave_like 'a scraper shell'
    end

    context 'with a shell script' do
      let(:watch_directory) { ::File.join(@tmpdir, 'watched') }
      let(:output_file)     { ::File.join(watch_directory, 'output.txt') }
      let(:shell_message) do
        'This is too many bytes and will exceed the strict size limit.'
      end
      let(:shell_script) do
        if is_windows
<<EOF
@echo off
mkdir #{watch_directory.inspect}
for /L %%I in (1,1,10) do (
  echo %%I
  echo #{shell_message}>#{output_file.inspect}
  ping -n 2 -w 1000 localhost>nul
)
EOF
        else
<<EOF
#!/bin/bash
mkdir -p #{watch_directory.inspect}
for i in {1..10}
do
  echo $i
  echo #{shell_message}>#{output_file.inspect}
  sleep 1
done
EOF
        end
      end

      let(:shell_script_path) do
        ::File.join(@tmpdir, "test_script#{is_windows ? '.bat' : '.sh'}")
      end
      let(:shell_cmd) do
        "#{command_shell} #{shell_script_path.inspect}"
      end

      before(:each) do
        ::File.open(shell_script_path, 'w') { |f| f.puts shell_script }
        ::File.chmod(0700, shell_script_path)
      end

      context 'when size limit is smaller than output' do
        let(:shell_options) do
          {
            :initial_directory => @tmpdir,
            :max_bytes         => shell_message.length / 2,
            :max_seconds       => 600,
            :watch_directory   => watch_directory,
          }
        end

        it 'should raise for size limit exceeded' do
          cmd = shell_cmd
          logger.
            should_receive(:info).
            with("+ #{cmd}").
            and_return(true).
            once
          expect { subject.execute(cmd, shell_execute_options) }.
            to raise_error(::RightScraper::Processes::Shell::SizeLimitError)
        end
      end

      context 'when time limit is shorter than duration' do
        let(:shell_options) do
          {
            :initial_directory => @tmpdir,
            :max_bytes         => 1024,
            :max_seconds       => 6,
            :watch_directory   => watch_directory,
          }
        end

        it 'should raise for time limit exceeded' do
          cmd = "#{command_shell} #{shell_script_path.inspect}"
          logger.
            should_receive(:info).
            with("+ #{cmd}").
            and_return(true).
            once
          expect { subject.execute(cmd, shell_execute_options) }.
            to raise_error(::RightScraper::Processes::Shell::TimeLimitError)
        end
      end
    end
  end

end # RightScraper::Processes::Shell
