# NOTE: These are development-only dependencies
source "https://rubygems.org"

gemspec

group :development, :test do
  gem 'rubocop'
  gem 'byebug'
  gem 'method_source'
  gem 'sorbet'
end

group :test do
  gem 'mocha', '~> 1.9.0', require: false
  gem 'minitest', '>= 5.0.0', require: false
  gem 'minitest-reporters', require: false
end
