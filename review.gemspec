# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "review/version"

Gem::Specification.new do |gem|
  gem.name        = "review"
  gem.version     = ReVIEW::VERSION
  gem.platform    = Gem::Platform::RUBY
  gem.license     = "LGPL"
  gem.authors     = ["kmuto", "takahashim"]
  gem.email       = "kmuto@debian.org"
  gem.homepage    = "http://github.com/kmuto/review"
  gem.summary     = "Re:VIEW: a easy-to-use digital publishing system"
  gem.description = "Re:VIEW is a digital publishing system for books and ebooks. It supports InDesign, EPUB and LaTeX."
  gem.required_rubygems_version = Gem::Requirement.new(">= 0") if gem.respond_to? :required_rubygems_version=
  gem.date = "2014-10-29"

  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.extra_rdoc_files = [
    "ChangeLog",
    "README.rdoc"
  ]
  gem.require_paths = ["lib"]

  gem.add_development_dependency("rake")
end

