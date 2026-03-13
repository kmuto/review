# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in review.gemspec
gemspec

# Development dependencies
group :development do
  # markly gem (for Markdown support) requires Ruby >= 3.1
  # On Ruby 3.0, tests will be skipped but Re:VIEW will work with .re files
  gem 'markly', '~> 0.13' if Gem.ruby_version >= Gem::Version.new('3.1.0')
end
