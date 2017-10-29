$LOAD_PATH.push File.expand_path('../lib', __FILE__)
require 'review/version'

Gem::Specification.new do |gem|
  gem.name        = 'review'
  gem.version     = ReVIEW::VERSION
  gem.platform    = Gem::Platform::RUBY
  gem.license     = 'LGPL'
  gem.authors     = %w[kmuto takahashim]
  gem.email       = 'kmuto@debian.org'
  gem.homepage    = 'http://github.com/kmuto/review'
  gem.summary     = 'Re:VIEW: a easy-to-use digital publishing system'
  gem.description = 'Re:VIEW is a digital publishing system for books and ebooks. It supports InDesign, EPUB and LaTeX.'
  gem.required_rubygems_version = Gem::Requirement.new('>= 0') if gem.respond_to? :required_rubygems_version=
  gem.date = '2017-06-29'

  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.executables   = `git ls-files -- bin/*`.split("\n").map { |f| File.basename(f) }
  gem.extra_rdoc_files = [
  ]
  gem.require_paths = ['lib']

  gem.add_dependency('image_size')
  gem.add_dependency('rouge')
  gem.add_dependency('rubyzip')
  gem.add_development_dependency('pygments.rb')
  gem.add_development_dependency('rake')
  gem.add_development_dependency('rubocop')
  gem.add_development_dependency('test-unit')
end
