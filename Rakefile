# frozen_string_literal: true

begin
  require 'bundler'
  Bundler::GemHelper.install_tasks
rescue LoadError
  # ignore if bundler does not exist
  warn 'Bundler not found'
end

require 'rubygems'
require 'rake/clean'

task default: %i[test rubocop]

# Compatibility check tasks
namespace :compat do
  desc 'Run compatibility checks for all formats'
  task :run do
    sh 'bin/check-compat --verbose'
  end

  desc 'Run compatibility checks for HTML only'
  task :html do
    sh 'bin/check-compat --format html --verbose'
  end

  desc 'Run compatibility checks for LaTeX only'
  task :latex do
    sh 'bin/check-compat --format latex --verbose'
  end

  desc 'Run compatibility checks with detailed diff output'
  task :diff do
    sh 'bin/check-compat --show-diff --verbose'
  end
end

desc 'Check with rubocop'
task :rubocop do
  begin
    require 'rubocop/rake_task'
    RuboCop::RakeTask.new
  rescue LoadError
    warn 'rubocop not found'
  end
end

desc 'Run tests'
task :test, :target do |_, argv|
  if argv[:target].nil?
    ruby('test/run_test.rb')
  else
    ruby('test/run_test.rb', "--pattern=#{argv[:target]}")
  end
end

begin
  require 'rdoc/task'
  Rake::RDocTask.new do |rdoc|
    version = File.exist?('VERSION') ? File.read('VERSION') : ''
    rdoc.rdoc_dir = 'rdoc'
    rdoc.title = "review #{version}"
    rdoc.rdoc_files.include('README*')
    rdoc.rdoc_files.include('lib/**/*.rb')
  end
rescue LoadError
  warn 'rdoc not found'
end
