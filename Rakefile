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

desc 'Check with rubocop'
task :rubocop do
  begin
    require 'rubocop/rake_task'
    RuboCop::RakeTask.new
  rescue LoadError
    warn 'rubocop not found'
  end
end

task :test do
  ruby('test/run_test.rb')
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
