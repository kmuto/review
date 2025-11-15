# frozen_string_literal: true

$LOAD_PATH.push(File.expand_path('lib', __dir__))
require 'review/version'

Gem::Specification.new do |gem|
  gem.name        = 'review'
  gem.version     = ReVIEW::VERSION
  gem.platform    = Gem::Platform::RUBY
  gem.license     = 'LGPL'
  gem.authors     = %w[kmuto takahashim]
  gem.email       = 'kmuto@kmuto.jp'
  gem.homepage    = 'http://github.com/kmuto/review'
  gem.summary     = 'Re:VIEW: a easy-to-use digital publishing system'
  gem.description = 'Re:VIEW is a digital publishing system for books and ebooks. It supports InDesign, EPUB and LaTeX.'
  gem.required_rubygems_version = Gem::Requirement.new('>= 0') if gem.respond_to?(:required_rubygems_version=)
  gem.metadata = { 'rubygems_mfa_required' => 'true' }

  gem.files         = `git ls-files`.split("\n").reject { |f| f.match(/^test/) }.reject { |f| f.match(%r{^vendor/imagemagick}) }
  gem.executables   = `git ls-files -- bin/*`.split("\n").map { |f| File.basename(f) }
  gem.extra_rdoc_files = []
  gem.require_paths = ['lib']

  gem.add_dependency('base64')
  gem.add_dependency('csv')
  gem.add_dependency('image_size')
  gem.add_dependency('logger')
  gem.add_dependency('nkf')
  gem.add_dependency('rexml')
  gem.add_dependency('rouge')
  gem.add_dependency('rubyzip')
  gem.add_dependency('tty-logger')
end
