require 'rubygems'
require 'rake'
require 'rake/testtask'
require 'rake/clean'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "review"
    gem.summary = %Q{ReVIEW: a easy-to-use digital publishing system}
    gem.description = %Q{ReVIEW is a digital publishing system for books and ebooks. It supports InDesign, EPUB and LaTeX.}
    gem.email = "kmuto@debian.org"
    gem.homepage = "http://github.com/kmuto/review"
    gem.authors = ["kmuto", "takahashim"]
    # gem.add_development_dependency "thoughtbot-shoulda", ">= 0"
    # gem is a Gem::Specification... see http://www.rubygems.org/read/chapter/20 for additional settings
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end


task :test => :check_dependencies

task :default => [:test]

Rake::TestTask.new("test") do |t|
	t.libs   << "test"
	t.pattern = "test/test_*.rb"
	t.verbose = true
end

begin
  require 'rcov/rcovtask'
  Rcov::RcovTask.new do |t|
    t.rcov_opts << '-x /gems/'
    t.libs << 'test'
    t.pattern = 'test/test_*.rb'
    t.verbose = true
  end
rescue LoadError
end

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "review #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
