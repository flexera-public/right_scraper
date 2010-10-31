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
  shared_examples_for 'Environment variables' do
    def setvar(name, value)
      if value.nil?
        ENV.delete name
      else
        ENV[name] = value
      end
    end

    it 'should set SSH_AUTH_SOCK' do
      oldsock = ENV['SSH_AUTH_SOCK']
      RightScale::Processes::SSHAgent.with do |agent|
        ENV.should have_key('SSH_AUTH_SOCK')
        ENV['SSH_AUTH_SOCK'].should_not be_empty
        File.exists?(ENV['SSH_AUTH_SOCK']).should == true
      end
      ENV['SSH_AUTH_SOCK'].should == oldsock
    end

    it 'should set SSH_AGENT_PID' do
      oldpid = ENV['SSH_AUTH_PID']
      RightScale::Processes::SSHAgent.with do |agent|
        ENV.should have_key('SSH_AGENT_PID')
        ENV['SSH_AGENT_PID'].should_not be_empty
        # This is a Unixism; sending signal 0 to a process tests whether
        # it exists, but has no effect on the process.  I have no idea
        # how to express this on Windows.
        Process.kill(0, ENV['SSH_AGENT_PID'].to_i).should be_true
      end
      ENV['SSH_AUTH_PID'].should == oldpid
    end

    it 'should set SSH_ASKPASS' do
      oldpass = ENV['SSH_ASKPASS']
      RightScale::Processes::SSHAgent.with do |agent|
        ENV.should have_key('SSH_ASKPASS')
        ENV['SSH_ASKPASS'].should_not be_empty

        script = File.expand_path(File.join(File.dirname(__FILE__), '..',
                                            'scripts', 'stub_ssh_askpass'))
        ENV['SSH_ASKPASS'].should == script
      end
      ENV['SSH_ASKPASS'].should == oldpass
    end

    it 'should set HOME' do
      oldhome = ENV['HOME']
      RightScale::Processes::SSHAgent.with do |agent|
        ENV.should have_key('HOME')
        ENV['HOME'].should_not be_empty
        ENV['HOME'].should == "/dev/null"
      end
      ENV['HOME'].should == oldhome
    end
  end

  context 'with no relevant environment variables' do
    before(:each) do
      @display = ENV['DISPLAY']
      @askpass = ENV['SSH_ASKPASS']
      @sshauth = ENV['SSH_AUTH_SOCK']
      @agentpid = ENV['SSH_AGENT_PID']
      @home = ENV['HOME']
      ENV.delete 'DISPLAY'
      ENV.delete 'SSH_ASKPASS'
      ENV.delete 'SSH_AUTH_SOCK'
      ENV.delete 'SSH_AGENT_PID'
      ENV.delete 'HOME'
    end

    after(:each) do
      setvar 'DISPLAY', @display
      setvar 'SSH_ASKPASS', @askpass
      setvar 'SSH_AUTH_SOCK', @sshauth
      setvar 'SSH_AGENT_PID', @agentpid
      setvar 'HOME', @home
    end

    it_should_behave_like 'Environment variables'
  end

  context 'with relevant environment variables set' do
    before(:each) do
      @display = ENV['DISPLAY']
      @askpass = ENV['SSH_ASKPASS']
      @sshauth = ENV['SSH_AUTH_SOCK']
      @agentpid = ENV['SSH_AGENT_PID']
      @home = ENV['HOME']
      ENV['DISPLAY'] = "foo"
      ENV['SSH_ASKPASS'] = "bar"
      ENV['SSH_AUTH_SOCK'] = "baz"
      ENV['SSH_AGENT_PID'] = "quux"
      ENV['HOME'] = "fred"
    end

    after(:each) do
      setvar 'DISPLAY', @display
      setvar 'SSH_ASKPASS', @askpass
      setvar 'SSH_AUTH_SOCK', @sshauth
      setvar 'SSH_AGENT_PID', @agentpid
      setvar 'HOME', @home
    end

    it_should_behave_like 'Environment variables'
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

  it 'should fail on the passworded key' do
    pid = nil
    lambda {
      RightScale::Processes::SSHAgent.with do |agent|
        pid = ENV['SSH_AGENT_PID'].to_i
        demofile = File.expand_path(File.join(File.dirname(__FILE__), 'password_key'))
        File.chmod(0600, demofile)
        agent.add_keyfile(demofile)
      end
    }.should raise_exception(ProcessWatcher::NonzeroExitCode, /Attempted to use credentials that require passwords; bailing/)
    lambda {
      Process.kill(0, pid)
    }.should raise_exception(Errno::ESRCH)
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
