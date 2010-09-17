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

require 'stringio'
require File.expand_path(File.join(File.dirname(__FILE__), 'spec_helper'))
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib', 'right_scraper_base'))
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib', 'right_scraper_base', 'loggers', 'noisy'))

describe RightScale::Logger do
  before(:each) do
    @stream = StringIO.new()
    @logger = RightScale::Logger.new(@stream)
    @logger.level = Logger::WARN
  end

  after(:each) do
    @logger.close
  end

  def match_log_entry(entry, type, message)
    shortform, longform = case type
                          when Logger::DEBUG then ["D", "DEBUG"]
                          when Logger::INFO then ["I", "INFO"]
                          when Logger::WARN then ["W", "WARN"]
                          when Logger::ERROR then ["E", "ERROR"]
                          when Logger::FATAL then ["F", "FATAL"]
                          when Logger::FATAL then ["U", "UNKNOWN"]
                          end
    datestamp = /[[:digit:]]{4}-[[:digit:]]{2}-[[:digit:]]{2}/
    timestamp = /[[:digit:]]{2}:[[:digit:]]{2}:[[:digit:]]{2}.[[:digit:]]+/
    datetimestamp = /#{datestamp}T#{timestamp}/
    entry.should =~ %r{^#{shortform}, \[#{datetimestamp} \#[[:digit:]]+\] #{longform} -- : #{message}\n$}
  end

  it 'should log to the stream' do
    @logger.debug("foo")
    @logger.info("first")
    @logger.error("baz")
    @logger.fatal("quux")
    @stream.rewind
    match_log_entry(@stream.readline, Logger::ERROR, "baz")
    match_log_entry(@stream.readline, Logger::FATAL, "quux")
    @stream.eof?.should be_true
  end

  it 'should note errors properly' do
    @logger.note_error(Exception.new("foo!"), :baz)
    match_log_entry(@stream.string, Logger::ERROR, "Saw foo! during baz")
  end

  it 'should note errors with an explanation properly' do
    @logger.note_error(Exception.new("foo!"), :baz, "an explanation")
    match_log_entry(@stream.string, Logger::ERROR, "Saw foo! during baz: an explanation")
  end

  it 'should pass values through the block' do
    result = @logger.operation(:passthrough) { 4 }
    result.should == 4
  end
end

describe RightScale::Loggers::NoisyLogger do
  before(:each) do
    @stream = StringIO.new()
    @logger = RightScale::Loggers::NoisyLogger.new(@stream)
  end

  after(:each) do
    @logger.close
  end

  def match_log_entry(entry, type, message)
    shortform, longform = case type
                          when Logger::DEBUG then ["D", "DEBUG"]
                          when Logger::INFO then ["I", "INFO"]
                          when Logger::WARN then ["W", "WARN"]
                          when Logger::ERROR then ["E", "ERROR"]
                          when Logger::FATAL then ["F", "FATAL"]
                          when Logger::FATAL then ["U", "UNKNOWN"]
                          end
    datestamp = /[[:digit:]]{4}-[[:digit:]]{2}-[[:digit:]]{2}/
    timestamp = /[[:digit:]]{2}:[[:digit:]]{2}:[[:digit:]]{2}.[[:digit:]]+/
    datetimestamp = /#{datestamp}T#{timestamp}/
    entry.should =~ %r{^#{shortform}, \[#{datetimestamp} \#[[:digit:]]+\] #{longform} -- : #{message}\n$}
  end

  context 'with the level set to WARN' do
    before(:each) do
      @logger.level = Logger::WARN
    end

    it 'should not log operations' do
      @logger.operation(:foo) do
        @logger.operation(:bar) do
        end
      end
      @stream.string.should == ""
    end

    it 'should note errors with context' do
      begin
        @logger.operation(:foo) do
          @logger.operation(:bar, "blah") do
            @logger.note_error("an exception", :note, "bar")
          end
        end
      rescue
      end
      @stream.rewind
      match_log_entry(@stream.readline, Logger::ERROR, "Saw an exception during note: bar in bar: blah in foo")
      @stream.eof?.should be_true
    end

    it 'should note errors when the level is set to WARN and an exception occurs' do
      begin
        @logger.operation(:foo) do
          @logger.operation(:bar, "blah") do
            raise "foo"
          end
        end
      rescue
      end
      @stream.rewind
      match_log_entry(@stream.readline, Logger::ERROR, "Saw foo during bar: blah in foo")
      @stream.eof?.should be_true
    end
  end

  context 'with the level set to DEBUG' do
    before(:each) do
      @logger.level = Logger::DEBUG
    end

    it 'should log begin/commit' do
      @logger.operation(:foo) do
        @logger.operation(:bar, "blah") do
        end
      end
      @stream.rewind
      match_log_entry(@stream.readline, Logger::DEBUG, "> begin foo")
      match_log_entry(@stream.readline, Logger::DEBUG, ">> begin bar: blah")
      match_log_entry(@stream.readline, Logger::DEBUG, ">> close bar: blah")
      match_log_entry(@stream.readline, Logger::DEBUG, "> close foo")
      @stream.eof?.should be_true
    end

    it 'should log begin/abort when an exception occurs' do
      @logger.level = Logger::DEBUG
      begin
        @logger.operation(:foo) do
          @logger.operation(:bar, "blah") do
            raise "foo"
          end
        end
      rescue
      end
      @stream.rewind
      match_log_entry(@stream.readline, Logger::DEBUG, "> begin foo")
      match_log_entry(@stream.readline, Logger::DEBUG, ">> begin bar: blah")
      match_log_entry(@stream.readline, Logger::ERROR, "Saw foo during bar: blah in foo")
      match_log_entry(@stream.readline, Logger::DEBUG, ">> abort bar: blah")
      match_log_entry(@stream.readline, Logger::DEBUG, "> abort foo")
      @stream.eof?.should be_true
    end
  end
end
