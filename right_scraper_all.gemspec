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

require 'rubygems'

spec = Gem::Specification.new do |spec|
  spec.name      = 'right_scraper_all'
  spec.version   = '2.0.0'
  spec.authors   = ['Graham Hughes', 'Raphael Simon']
  spec.email     = 'raphael@rightscale.com'
  spec.homepage  = 'https://github.com/rightscale/right_scraper'
  spec.platform  = Gem::Platform::RUBY
  spec.summary   = 'Download and update remote repositories -- full version'
  spec.has_rdoc = true
  spec.rdoc_options = ["--main", "README.rdoc", "--title", "RightScraper"]
  spec.extra_rdoc_files = ["README.rdoc"]
  spec.required_ruby_version = '>= 1.8.7'
  spec.rubyforge_project = %q{right_scraper}
  spec.require_path = 'fulllib'

  spec.add_dependency('json', '>= 1.4.5')
  spec.add_dependency('git', '>= 1.2.5')
  spec.add_dependency('libarchive', '>= 0.1.1')
  spec.add_dependency('curb', '>= 0.7.7.1')
  spec.add_dependency('right_aws', '>= 2.0')

  spec.requirements << 'libarchive, 2.8.4'
  spec.requirements << 'curl command line client'
  spec.requirements << 'Subversion Ruby client bindings'

  spec.add_development_dependency('rspec')
  spec.add_development_dependency('flexmock')

  spec.description = <<-EOF
  RightScraper provides a simple interface to download and keep local copies of remote
  repositories up-to-date using the following protocols:
    * git: RightScraper will clone then pull repos from git
    * SVN: RightScraper will checkout then update SVN repositories
    * tarballs: RightScraper will download, optionally uncompress and expand a given tar file
  This component bundles all available right_scraper components into one gem.
EOF

  candidates = Dir.glob("fulllib/**/*") +
               Dir.glob("{right_scraper_*/README.rdoc") +
               ["LICENSE", "README.rdoc", "Rakefile", "right_scraper_all.gemspec"]
  spec.files = candidates.sort
end

if $PROGRAM_NAME == __FILE__
   Gem.manage_gems if Gem::RubyGemsVersion.to_f < 1.0
   Gem::Builder.new(spec).build
end
