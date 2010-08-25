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

require File.expand_path(File.join(File.dirname(__FILE__), 'spec_helper'))
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib', 'right_scraper', 'watcher'))

describe RightScale::Watcher do

  before(:each) do
    @dest_dir = File.join(File.dirname(__FILE__), '__destdir')
    FileUtils.mkdir_p(@dest_dir)
  end

  after(:each) do
    FileUtils.rm_rf(@dest_dir)
  end

  it 'should launch and watch well-behaved processes' do
    watcher = RightScale::Watcher.new(max_bytes=1, max_seconds=5)
    ruby = "trap('INT', 'IGNORE'); puts 42; exit 42"
    status = watcher.launch_and_watch('ruby', ['-e', ruby], @dest_dir)
    status.status.should == :success
    status.exit_code.should == 42
    status.output.should == "42\n"
  end

  it 'should report timeouts' do
    watcher = RightScale::Watcher.new(max_bytes=1, max_seconds=2)
    ruby = "trap('INT', 'IGNORE'); STDOUT.sync = true; puts 42; sleep 5"
    status = watcher.launch_and_watch('ruby',  ['-e', ruby], @dest_dir)
    status.status.should == :timeout
    status.exit_code.should == -1
    status.output.should == "42\n"
  end

  it 'should report size exceeded' do
    watcher = RightScale::Watcher.new(max_bytes=1, max_seconds=5)
    ruby = "trap('INT', 'IGNORE'); STDOUT.sync = true; puts 42; File.open(File.join('#{@dest_dir}', 'test'), 'w') { |f| f.puts 'MORE THAN 2 CHARS' }; sleep 5 rescue nil"
    status = watcher.launch_and_watch('ruby', ['-e', ruby], @dest_dir)
    status.status.should == :size_exceeded
    status.exit_code.should == -1
    status.output.should == "42\n"
  end

  it 'should allow infinite size and timeout' do
    watcher = RightScale::Watcher.new(max_bytes=-1, max_seconds=-1)
    ruby = "trap('INT', 'IGNORE'); STDOUT.sync = true; puts 42; File.open(File.join('#{@dest_dir}', 'test'), 'w') { |f| f.puts 'MORE THAN 2 CHARS' }; sleep 2 rescue nil"
    status = watcher.launch_and_watch('ruby', ['-e', ruby], @dest_dir)
    status.status.should == :success
    status.exit_code.should == 0
    status.output.should == "42\n"
  end

  it 'should permit array arguments' do
    watcher = RightScale::Watcher.new(max_bytes=-1, max_seconds=-1)
    status = watcher.launch_and_watch(["echo", "$HOME", ";", "echo", "broken"], @dest_dir)
    status.status.should == :success
    status.exit_code.should == 0
    status.output.should == "$HOME ; echo broken\n"
  end

end
