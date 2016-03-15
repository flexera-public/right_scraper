#!/usr/bin/env ruby
#--
# Copyright: Copyright (c) 2016 RightScale, Inc.
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

def warn(*args)
  # eliminate ruby/gem warnings from output
end

require 'rubygems'
require 'chef'
require 'chef/knife/cookbook_metadata'

if ::ARGV.size != 1
  $stderr.puts "Usage: #{::File.basename(__FILE__)} <cookbook_dir>"
  exit 1
end

cookbook_dir = ARGV.pop
knife_metadata = ::Chef::Knife::CookbookMetadata.new
knife_metadata.name_args = [::File.basename(cookbook_dir)]
knife_metadata.config[:cookbook_path] = ::File.dirname(cookbook_dir)
knife_metadata.run
