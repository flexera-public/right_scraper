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

require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

require 'stringio'

describe RightScraper::Loggers::Default do

  let(:stream) { ::StringIO.new }

  subject { described_class.new(stream) }

  it 'should log ERROR severity to the stream by default' do
    logger = subject
    logger.debug('Debug')
    logger.info('Info')
    logger.warn('Warn')
    logger.error('Error')
    logger.fatal('Fatal')
    stream.rewind
    output = stream.read
    output.should_not include("Debug\n")
    output.should_not include("Info\n")
    output.should_not include("Warn\n")
    output.should include("Error\n")
    output.should include("Fatal\n")
    logger.errors.should == [[nil, :log, 'Error'], [nil, :log, 'Fatal']]
    logger.warnings.should == []
  end

  it 'should allow most inclusive severity' do
    logger = subject
    logger.level = ::Logger::DEBUG
    logger.debug('Debug')
    logger.info('Info')
    logger.warn('Warn')
    logger.error('Error')
    logger.fatal('Fatal')
    stream.rewind
    output = stream.read
    output.should include("Debug\n")
    output.should include("Info\n")
    output.should include("Warn\n")
    output.should include("Error\n")
    output.should include("Fatal\n")
    logger.errors.should == [[nil, :log, 'Error'], [nil, :log, 'Fatal']]
    logger.warnings.should == ['Warn']
  end

  it 'should note errors properly' do
    logger = subject
    e = ::Exception.new("foo")
    logger.note_error(e, :bar)
    stream.rewind
    output = stream.read
    output.should include("Saw foo during bar\n")
    logger.errors.should == [[e, :bar, '']]
    logger.warnings.should == []
  end

  it 'should note errors with an explanation properly' do
    logger = subject
    e = ::Exception.new("foo")
    logger.note_error(e, :bar, 'baz')
    stream.rewind
    output = stream.read
    output.should include("Saw foo during bar: baz\n")
    logger.errors.should == [[e, :bar, 'baz']]
    logger.warnings.should == []
  end

  it 'should note warnings' do
    logger = subject
    logger.note_warning('Warning 1')
    logger.level = ::Logger::WARN
    logger.note_warning('Warning 2')
    stream.rewind
    output = stream.read
    output.should_not include("Warning 1\n")  # not logged by default
    output.should include("Warning 2\n")      # but logged when enabled
    logger.errors.should == []
    logger.warnings.should == ['Warning 1', 'Warning 2']
  end

  it 'should interrupt and resume base logger recording errors and warnings' do
    logger = subject
    logger.level = ::Logger::WARN
    logger.warn('logger warning 1')
    logger.note_warning('noted warning 1')
    logger.warn('logger warning 2')
    logger.error('logger error 1')
    logger.note_error(nil, :bar, 'noted error 1')
    logger.error('logger error 2')
    stream.rewind
    output = stream.read
    output.should include("logger warning 1\n")
    output.should include("noted warning 1\n")
    output.should include("logger warning 2\n")
    output.should include("logger error 1\n")
    output.should include("noted error 1\n")
    output.should include("logger error 2\n")
    logger.errors.should == [
      [nil, :log, 'logger error 1'],
      [nil, :bar, 'noted error 1'],
      [nil, :log, 'logger error 2'],
    ]
    logger.warnings.should == [
      'logger warning 1',
      'noted warning 1',
      'logger warning 2',
    ]
  end

  it 'should pass values through the block' do
    logger = subject
    result = logger.operation(:passthrough) { 4 }
    result.should == 4
  end
end
