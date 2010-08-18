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
require File.expand_path(File.join(File.dirname(__FILE__), 'base'))
require 'svn/client'
require 'tmpdir'

module RightScale
  class SvnClient
    def initialize(repo)
      @repository = repo
    end

    def with_context(log="")
      ctx = Svn::Client::Context.new
      ctx.set_log_msg_func do |items|
        [true, log]
      end
      ctx.add_simple_prompt_provider(0) do |cred, realm, username, may_save|
        cred.username = @repository.first_credential unless @repository.first_credential.nil?
        cred.password = @repository.second_credential unless @repository.second_credential.nil?
        cred.may_save = false
      end
      ctx.add_username_prompt_provider(0) do |cred, realm, username, may_save|
        cred.username = @repository.first_credential unless @repository.first_credential.nil?
        cred.password = @repository.second_credential unless @repository.second_credential.nil?
        cred.may_save = false
      end
      return ctx unless block_given?
      begin
        yield ctx
      ensure
        ctx.destroy
      end
    end
  end

  class NewSvnScraper < CheckoutBasedScraper
    def do_checkout
      client = SvnClient.new(@repository)
      client.with_context {|ctx|
        ctx.checkout(@repository.url, checkout_path, @repository.tag || nil)
      }
    end

    def ignorable_paths
      ['.svn']
    end
  end
end
