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
  spec.name      = 'right_scraper_s3'
  spec.version   = '2.0.0'
  spec.authors   = ['Graham Hughes', 'Raphael Simon']
  spec.email     = 'raphael@rightscale.com'
  spec.homepage  = 'https://github.com/rightscale/right_scraper'
  spec.platform  = Gem::Platform::RUBY
  spec.summary   = 'Libcurl based repository downloading for right_scraper'
  spec.has_rdoc = true
  spec.rdoc_options = ["--main", "README.rdoc", "--title", "RightScraper"]
  spec.extra_rdoc_files = ["README.rdoc"]
  spec.required_ruby_version = '>= 1.8.7'
  spec.rubyforge_project = %q{right_scraper}
  spec.require_path = 'lib'

  spec.add_dependency('right_aws', '>= 2.0')
  spec.add_dependency('right_scraper_base', '>= 2.0.0')

  spec.add_development_dependency('rspec')
  spec.add_development_dependency('flexmock')
  spec.add_development_dependency('rtags')

  spec.description = <<-EOF
  RightScraper provides a simple interface to download and keep local copies of remote
  repositories up-to-date using the following protocols:
    * git: RightScraper will clone then pull repos from git
    * SVN: RightScraper will checkout then update SVN repositories
    * tarballs: RightScraper will download, optionally uncompress and expand a given tar file
  This component enables uploading the contents of a cookbook to S3 using the Repose format.
EOF

  candidates = Dir.glob("{lib,spec}/**/*") +
    ["LICENSE", "README.rdoc",
     "Rakefile", "right_scraper_s3.gemspec"]
  spec.files = candidates.sort
end
