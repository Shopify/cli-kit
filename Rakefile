$LOAD_PATH.unshift(File.expand_path('../lib', __FILE__))
require 'rake/testtask'
require 'rubocop/rake_task'
require 'bundler/gem_tasks'
require 'sorbet-runtime' unless ENV['BUNDLE_WITHOUT'] == 'typecheck'

TEST_ROOT = File.expand_path('../test', __FILE__)

Rake::TestTask.new do |t|
  t.libs += ['test']
  t.test_files = FileList[File.join(TEST_ROOT, '**', '*_test.rb')]
  t.verbose = false
  t.warning = false
end

RuboCop::RakeTask.new(:style) do |t|
  t.options = ['--display-cop-names']
end

task :test_gen_bundler do
  sh 'DEPS=bundler bin/test_gen'
end

task :test_gen_vendor do
  sh 'DEPS=vendor bin/test_gen'
end

task(default: [:test, :style, :test_gen_bundler, :test_gen_vendor])
