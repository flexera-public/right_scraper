# -*-ruby-*-
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

Gem::Specification.new do |spec|
  spec.name      = 'right_scraper_base'
  spec.version   = '2.0.0'
  spec.authors   = ['Raphael Simon', 'Graham Hughes']
  spec.email     = 'raphael@rightscale.com'
  spec.homepage  = 'https://github.com/rightscale/right_scraper'
  spec.platform  = Gem::Platform::RUBY
  spec.summary   = 'Minimal base for downloading and updating remote repositories'
  spec.has_rdoc = true
  spec.rdoc_options = ["--main", "right_scraper_base/README.rdoc", "--title", "RightScraper"]
  spec.extra_rdoc_files = ["right_scraper_base/README.rdoc"]
  spec.required_ruby_version = '>= 1.8.7'
  spec.rubyforge_project = %q{right_scraper}
  spec.require_path = 'right_scraper_base/lib'

  spec.add_dependency('json', '>= 1.4.5')
  spec.requirements << 'curl command line client'

  spec.add_development_dependency('rspec')
  spec.add_development_dependency('flexmock')

  spec.description = <<-EOF
  RightScraper provides a simple interface to download and keep local copies of remote
  repositories up-to-date using the following protocols:
    * git: RightScraper will clone then pull repos from git
    * SVN: RightScraper will checkout then update SVN repositories
    * tarballs: RightScraper will download, optionally uncompress and expand a given tar file
  right_scraper_base provides minimal functionality; for more sophisticated uses, install
  the appropriate secondary gem, or right_scraper to get them all.
EOF

  candidates = Dir.glob("right_scraper_base/{lib,spec}/**/*") +
    ["right_scraper_base/LICENSE", "right_scraper_base/README.rdoc",
     "right_scraper_base/Rakefile", "right_scraper_base.gemspec"]
  spec.files = candidates.sort
end
