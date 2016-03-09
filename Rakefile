#-- -*-ruby-*-
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

require 'rubygems'
require 'rubygems/package_task'
require 'bundler/setup'

require 'fileutils'
require 'rake'
require 'rspec/core/rake_task'
require 'rdoc/task'
require 'rake/clean'

task :default => 'spec'

# == Gem packaging == #

desc "Build right_scraper gem"
Gem::PackageTask.new(Gem::Specification.load("right_scraper.gemspec")) do |package|
  package.need_zip = true
  package.need_tar = true
end

CLEAN.include('pkg')

# == Unit Tests == #

task :specs => :spec

# == Unit Tests == #

desc 'Run unit tests'
RSpec::Core::RakeTask.new do |t|
  t.pattern = 'spec/**/*_spec.rb'
    t.rspec_opts = ["--color", "--format", "nested"]
end

namespace :spec do
  desc "Run unit tests with RCov"
  RSpec::Core::RakeTask.new(:rcov) do |t|
    t.pattern = '*/spec/**/*_spec.rb'
    t.rcov = true
    t.rcov_opts = %q[--exclude "spec"]
  end

  desc "Print Specdoc for unit tests"
  RSpec::Core::RakeTask.new(:doc) do |t|
    t.pattern = '*/spec/**/*_spec.rb'
    t.rspec_opts = ["--format", "documentation"]
  end
end

# == Documentation == #

desc "Generate API documentation to doc/rdocs/index.html"
RDoc::Task.new do |rd|
  rd.rdoc_dir = 'doc/rdocs'
  rd.main = 'README.rdoc'
  rd.rdoc_files.include 'README.rdoc', 'lib/**/*.rb'

  rd.options << '--all'
  rd.options << '--diagram'
end

# == Emacs integration == #
desc "Rebuild TAGS file"
task :tags do
  sh "rtags -R */{lib,spec}"
end
