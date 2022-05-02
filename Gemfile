# NOTE: These are development-only dependencies
source 'https://rubygems.org'

gemspec

group :development, :test do
  gem 'cli-ui', git: 'https://github.com/Shopify/cli-ui', ref: '0eefd57248f42ec163639884e77a071d82bfbda8'
  gem 'rubocop'
  gem 'rubocop-rake'
  gem 'rubocop-shopify'
  gem 'rubocop-sorbet'
  gem 'byebug'
  gem 'method_source'
  gem 'simplecov'
end

group :typecheck do
  gem 'sorbet-static-and-runtime'
  gem 'tapioca', require: false
end

group :test do
  gem 'mocha', '~> 1.14.0', require: false
  gem 'minitest', '>= 5.0.0', require: false
  gem 'minitest-reporters', require: false
end
