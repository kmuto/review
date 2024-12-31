# frozen_string_literal: true

base_dir = File.expand_path('..', __dir__)
lib_dir  = File.join(base_dir, 'lib')
test_dir = File.join(base_dir, 'test')

$LOAD_PATH.unshift(lib_dir)

require 'simplecov'
SimpleCov.start
require 'test/unit'

argv = ARGV || ['--max-diff-target-string-size=10000']
exit Test::Unit::AutoRunner.run(true, test_dir, argv)
