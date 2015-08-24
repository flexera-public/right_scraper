source 'http://s3.amazonaws.com/rightscale_rightlink_gems_dev'
source 'https://rubygems.org'

gemspec

gem 'right_git'
gem 'right_popen', '~> 2.0'

gem 'rake',          '0.8.7'
gem 'right_support', '2.7'

gem 'right_aws_api',
  :git => 'git@github.com:rightscale/right_aws_api.git',
  :tag => 'v0.3.1'

gem 'right_cloud_api_base',
  :git => 'git@github.com:rightscale/right_cloud_api_base.git',
  :tag => 'v0.2.2'

group :development do
  # Omit these from gemspec since many RubyGems versions are silly and install development
  # dependencies even when dong 'gem install'
  gem 'rspec',    '~> 2.0'
  gem 'flexmock', '~> 0.9'
  gem 'rtags',    '~> 0.97'

  # not friendly on daemon server due to lack of installed libs.
  gem 'ruby-debug',   :platform => :ruby_18
  gem 'ruby-debug19', :platform => :ruby_19
  gem 'rdoc',         '~> 2.4'
end
