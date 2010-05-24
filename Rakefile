require 'rubygems'
require 'rake'
require 'rake/testtask'
require 'rake/clean'

task :default => [:test]

Rake::TestTask.new("test") do |t|
	t.libs   << "test"
	t.pattern = "test/test_*.rb"
	t.verbose = true
end
