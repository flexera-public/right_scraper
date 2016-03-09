source 'https://rubygems.org'

gemspec

gem 'right_git'
gem 'right_popen'
gem 'right_support', '~> 2.8'

group :development do
  # Omit these from gemspec since many RubyGems versions are silly and install
  # development dependencies even when doing 'gem install'
  gem 'rake'
  gem 'rspec',    '~> 2.0'
  gem 'flexmock', '~> 0.9'
  gem 'right_develop'
end

group :debugger do
  gem 'pry'
  gem 'pry-byebug'
end
