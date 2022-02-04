require 'sorbet-runtime'

addpath = lambda do |p|
  path = File.expand_path("../../#{p}", __FILE__)
  $LOAD_PATH.unshift(path) unless $LOAD_PATH.include?(path)
end
addpath.call('lib')

require 'cli/kit'

require 'fileutils'
require 'tmpdir'
require 'tempfile'

require 'rubygems'
require 'bundler/setup'

if ENV['CLI_UI_DEV']
  addpath.call('../cli-ui/lib')
end

require 'byebug'

require 'simplecov'
SimpleCov.start do
  # SimpleCov uses a "creative" DSL here with block rebinding.
  # Sorbet doesn't like it.
  T.unsafe(self).add_filter('/lib/cli/kit/sorbet_runtime_stub.rb')
  T.unsafe(self).add_filter('/test/')
  T.unsafe(self).add_filter('/gen/')
  T.unsafe(self).add_filter('/examples/')
  T.unsafe(self).track_files('lib/**/*.rb')
end

CLI::UI::StdoutRouter.enable
CLI::UI.enable_color = true

require 'minitest/autorun'
require 'minitest/unit'
require 'mocha/minitest'

def with_env(env)
  original_env_hash = ENV.to_h
  ENV.replace(original_env_hash.merge(env))
  yield
ensure
  ENV.replace(original_env_hash)
end
