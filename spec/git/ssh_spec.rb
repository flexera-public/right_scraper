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

require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe RightScraper::Processes::SSHAgent do
  shared_examples_for 'a process that sets environment variables' do
    def setvar(name, value)
      if value.nil?
        ENV.delete name
      else
        ENV[name] = value
      end
    end

    it 'should set SSH_AUTH_SOCK' do
      oldsock = ENV['SSH_AUTH_SOCK']
      RightScraper::Processes::SSHAgent.with do |agent|
        ENV.should have_key('SSH_AUTH_SOCK')
        ENV['SSH_AUTH_SOCK'].should_not be_empty
        File.exists?(ENV['SSH_AUTH_SOCK']).should == true
      end
      ENV['SSH_AUTH_SOCK'].should == oldsock
    end

    it 'should set SSH_AGENT_PID' do
      oldpid = ENV['SSH_AUTH_PID']
      RightScraper::Processes::SSHAgent.with do |agent|
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
      RightScraper::Processes::SSHAgent.with do |agent|
        ENV.should have_key('SSH_ASKPASS')
        ENV['SSH_ASKPASS'].should_not be_empty

        script = File.expand_path(File.join(File.dirname(__FILE__), '..', '..',
                                            'scripts', 'stub_ssh_askpass'))
        ENV['SSH_ASKPASS'].should == script
      end
      ENV['SSH_ASKPASS'].should == oldpass
    end

    it 'should set HOME' do
      oldhome = ENV['HOME']
      RightScraper::Processes::SSHAgent.with do |agent|
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

    it_should_behave_like 'a process that sets environment variables'
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

    it_should_behave_like 'a process that sets environment variables'
  end

  it 'should be able to load the demo key' do
    RightScraper::Processes::SSHAgent.with do |agent|
      demofile = File.expand_path(File.join(File.dirname(__FILE__), 'demokey'))
      File.chmod(0600, demofile)
      demofile = File.join(File.dirname(__FILE__), 'demokey')
      agent.add_keyfile(demofile)
      `ssh-add -l`.should == "2048 c7:66:87:fc:17:b5:2f:32:f2:c1:ed:40:a6:8d:17:44 #{demofile} (RSA)\n"
      `ssh-add -L`.should == <<FULLOUTPUT
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC18gNzaOwgJkHhUgPPNtCNp0H08ywzH1AquwSca19ZOedGnRWa673t4sXW0BeBn1wd8v0EulHRNwIyn0xJLsEStMOpo4A0qN+B2sM9gjBcY8nMOyUqy5s32pXncGfEwiRuiAxqz45VJqvL3CD8X5WxG300u/DNUbLZN0IT1aPn52Bo6gcGleZklxF1cccrbMelWfXE7KYKjD3/TfLdJeOlP9PJM8ijFHCsyWcKt5AH8bFkQ/xETPfqPzUIwvLDU7HpVDLZZ6JBi2rxhAAG+NhE3GMmY5i+vMB+g7CCfY200SFxzyjIcag05MGGko8Rv9bHnE3AYj9cxCULyDJyZm/T #{demofile}
FULLOUTPUT
    end
  end

  it 'should fail on the passworded key' do
    pid = nil
    lambda {
      RightScraper::Processes::SSHAgent.with do |agent|
        pid = ENV['SSH_AGENT_PID'].to_i
        pid.should_not == 0
        demofile = File.expand_path(File.join(File.dirname(__FILE__), 'password_key'))
        File.chmod(0600, demofile)
        agent.add_keyfile(demofile)  # will fail due to missing password
      end
    }.should raise_exception(::RightScraper::Processes::SSHAgent::SSHAgentError, /Attempted to use credentials that require passwords; bailing/)

    # the .with statement must ensure that the ssh-agent process terminates.
    lambda {
      Process.kill(0, pid)
    }.should raise_exception(Errno::ESRCH)
  end

  it 'should be able to load the demo key from memory' do
    RightScraper::Processes::SSHAgent.with do |agent|
      demofile = File.join(File.dirname(__FILE__), 'demokey')
      demodata = File.open(demofile).read
      agent.add_key(demodata)
      `ssh-add -l`.should =~ /^2048 c7:66:87:fc:17:b5:2f:32:f2:c1:ed:40:a6:8d:17:44 .*? \(RSA\)\n$/
      expected_pubkey = 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC18gNzaOwgJkHhUgPPNtCNp0H08ywzH1AquwSca19ZOedGnRWa673t4sXW0BeBn1wd8v0EulHRNwIyn0xJLsEStMOpo4A0qN+B2sM9gjBcY8nMOyUqy5s32pXncGfEwiRuiAxqz45VJqvL3CD8X5WxG300u/DNUbLZN0IT1aPn52Bo6gcGleZklxF1cccrbMelWfXE7KYKjD3/TfLdJeOlP9PJM8ijFHCsyWcKt5AH8bFkQ/xETPfqPzUIwvLDU7HpVDLZZ6JBi2rxhAAG+NhE3GMmY5i+vMB+g7CCfY200SFxzyjIcag05MGGko8Rv9bHnE3AYj9cxCULyDJyZm/T'
      `ssh-add -L`.should =~ %r{^#{Regexp.escape(expected_pubkey)} .*\n$}
    end
  end
end
