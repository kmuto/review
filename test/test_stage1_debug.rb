#!/usr/bin/env ruby
# frozen_string_literal: true

# Stage 1 debugging tool
require 'bundler/setup'
require 'review'
require 'review/ast_config'

# Set environment for Stage 1
ENV['REVIEW_AST_STAGE'] = '1'
ENV['REVIEW_DEBUG_AST'] = 'true'
ENV['REVIEW_AST_PERFORMANCE'] = 'true'

config = ReVIEW::Configure.values
ReVIEW::I18n.setup('ja') # Initialize I18n
book = ReVIEW::Book::Base.new(config: config)

# Read test file
content = File.read('test/fixtures/test_stage1.re')

# Create AST configuration
ast_config = ReVIEW::ASTConfig.new(config)
puts '=== AST Configuration ==='
puts "Mode: #{ast_config.ast_mode}"
puts "Elements: #{ast_config.ast_elements}"
puts "Stage: #{ast_config.ast_stage}"
puts "Debug: #{ast_config.debug_enabled?}"
puts "Performance: #{ast_config.performance_enabled?}"
puts

# Create builder and compiler
builder = ReVIEW::HTMLBuilder.new
compiler_options = ast_config.compiler_options
puts '=== Compiler Options ==='
puts compiler_options
puts

compiler = ReVIEW::Compiler.new(builder, **compiler_options)

# Create mock chapter object
chap = ReVIEW::Book::Chapter.new(book, nil, 'test/fixtures/test_stage1.re', 'test/fixtures/test_stage1.re')
chap.instance_variable_set(:@content, content)

puts '=== Compilation ==='
begin
  compiler.compile(chap)
  puts 'Compilation successful!'

  # Show hybrid mode configuration
  config = compiler.hybrid_mode_config
  puts "\n=== Runtime Configuration ==="
  puts "Mode: #{config[:mode]}"
  puts "AST Elements: #{config[:ast_elements]}"
  puts "Debug enabled: #{config[:debug_enabled]}"
  puts "Performance enabled: #{config[:performance_enabled]}"

  if config[:statistics].any?
    puts "\n=== Element Usage Statistics ==="
    config[:statistics].each do |element, count|
      puts "  #{element}: #{count} times"
    end
  end

  if config[:performance].any?
    puts "\n=== Performance Statistics ==="
    config[:performance].each do |metric, value|
      if metric.to_s.include?('time')
        puts "  #{metric}: #{(value * 1000).round(2)}ms"
      else
        puts "  #{metric}: #{value}"
      end
    end
  end
rescue StandardError => e
  puts "Error: #{e.message}"
  puts e.backtrace.first(5)
end
