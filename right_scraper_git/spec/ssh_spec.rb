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
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib', 'right_scraper_git', 'processes', 'ssh'))

describe RightScale::Processes::SSHAgent do
  it 'should set SSH_AUTH_SOCK' do
    RightScale::Processes::SSHAgent.with do |agent|
      ENV.should have_key('SSH_AUTH_SOCK')
      ENV['SSH_AUTH_SOCK'].should_not be_empty
      File.exists?(ENV['SSH_AUTH_SOCK']).should == true
    end
  end

  it 'should set SSH_AGENT_PID' do
    RightScale::Processes::SSHAgent.with do |agent|
      ENV.should have_key('SSH_AGENT_PID')
      ENV['SSH_AGENT_PID'].should_not be_empty
      # This is a Unixism; sending signal 0 to a process tests whether
      # it exists, but has no effect on the process.  I have no idea
      # how to express this on Windows.
      Process.kill(0, ENV['SSH_AGENT_PID'].to_i).should be_true
    end
  end

  it 'should be able to load the demo key' do
    RightScale::Processes::SSHAgent.with do |agent|
      demofile = File.expand_path(File.join(File.dirname(__FILE__), 'demokey'))
      File.chmod(0600, demofile)
      demofile = File.join(File.dirname(__FILE__), 'demokey')
      agent.add_keyfile(demofile)
      `ssh-add -l`.should == "2048 3d:6a:4f:8b:ec:35:da:e9:7e:cc:e8:2d:03:2f:6f:23 #{demofile} (RSA)\n"
      `ssh-add -L`.should == <<FULLOUTPUT
ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAxJsM8sZ6++Nky/ogLEYhKtKivB37sPB9M6Un0z6PkIRgUsGdntMJqP1U6820jH+n1/lOH/MnlUsvzoo8DnOdbe9kGOHBmtWmNcjqacZUn9DbpbjvlI7RUUmZ5OBKn8Pjt2qbSXnnci9Q5j5Rgh6DR8A70S04FIUP8AGpCIO23BhA928CiM18zN5mBvzET7L2DYiNhJJFsFWMbN13CdukTjNVNLETEusNVUU09G1NxX4esKky7tHh1c9APFvu98KjYOHkv1o7dB7T4dO3KaKCNWINCHeeoE+QmAkhAZwI72ijRkPxH+QMisMsHucPFvgOVVObxHWu9hRlNWIOodANHQ== #{demofile}
FULLOUTPUT
    end
  end

  it 'should be able to load the demo key from memory' do
    RightScale::Processes::SSHAgent.with do |agent|
      demofile = File.join(File.dirname(__FILE__), 'demokey')
      demodata = File.open(demofile).read
      agent.add_key(demodata)
      `ssh-add -l`.should =~ /^2048 3d:6a:4f:8b:ec:35:da:e9:7e:cc:e8:2d:03:2f:6f:23 .*? \(RSA\)\n$/
      `ssh-add -L`.should =~ %r{^ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAxJsM8sZ6\+\+Nky/ogLEYhKtKivB37sPB9M6Un0z6PkIRgUsGdntMJqP1U6820jH\+n1/lOH/MnlUsvzoo8DnOdbe9kGOHBmtWmNcjqacZUn9DbpbjvlI7RUUmZ5OBKn8Pjt2qbSXnnci9Q5j5Rgh6DR8A70S04FIUP8AGpCIO23BhA928CiM18zN5mBvzET7L2DYiNhJJFsFWMbN13CdukTjNVNLETEusNVUU09G1NxX4esKky7tHh1c9APFvu98KjYOHkv1o7dB7T4dO3KaKCNWINCHeeoE\+QmAkhAZwI72ijRkPxH\+QMisMsHucPFvgOVVObxHWu9hRlNWIOodANHQ== .*\n$}
    end
  end
end
