begin
  require 'bundler'
  Bundler::GemHelper.install_tasks
rescue LoadError
  # ignore if bundler does not exist
end

require 'rubygems'
require 'rake/testtask'
require 'rake/clean'

task :default => [:test]

Rake::TestTask.new("test") do |t|
  t.libs << "test"
  t.test_files = Dir.glob("test/**/test_*.rb")
  t.verbose = true
end

begin
  require 'rcov/rcovtask'
  Rcov::RcovTask.new do |t|
    t.rcov_opts << '-x /gems/'
    t.rcov_opts << '-x /tmp/'
    t.libs << 'test'
    t.pattern = 'test/test_*.rb'
    t.verbose = true
  end
rescue LoadError
end

begin
  require 'rdoc/task'
  Rake::RDocTask.new do |rdoc|
    version = File.exist?('VERSION') ? File.read('VERSION') : ""
    rdoc.rdoc_dir = 'rdoc'
    rdoc.title = "review #{version}"
    rdoc.rdoc_files.include('README*')
    rdoc.rdoc_files.include('lib/**/*.rb')
  end
rescue LoadError
end
