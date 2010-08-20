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
require 'svn/client'

module RightScale
  # Simplified interface to the process of creating SVN client
  # contexts.
  #
  # SVN client contexts are needed for almost every nontrivial SVN
  # operation, and the authentication procedure is truly baroque.
  # Thus, when you need a client context, do something like this:
  #   client = SvnClient.new(repository)
  #   client.with_context do |ctx|
  #     ...
  #   end
  class SvnClient
    # Initialize the client with the given repository.
    #
    # === Parameters
    # repo(RightScale::Repository):: SVN repository to work from
    def initialize(repo)
      @repository = repo
    end

    # Create a SVN client context set up for the repository given, and
    # call the attached block with the context ensuring that it will
    # be closed upon exit.
    #
    # === Parameters
    # log(String):: Optional log message to use
    def with_context(log="")
      context = ::Svn::Client::Context.new
      context.set_log_msg_func do |items|
        [true, log]
      end
      context.add_simple_prompt_provider(0) do |cred, realm, username, may_save|
        cred.username = @repository.first_credential unless @repository.first_credential.nil?
        cred.password = @repository.second_credential unless @repository.second_credential.nil?
        cred.may_save = false
      end
      context.add_username_prompt_provider(0) do |cred, realm, username, may_save|
        cred.username = @repository.first_credential unless @repository.first_credential.nil?
        cred.password = @repository.second_credential unless @repository.second_credential.nil?
        cred.may_save = false
      end
      return context unless block_given?
      begin
        yield context
      ensure
        context.destroy
      end
    end
  end
end
