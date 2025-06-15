#!/usr/bin/env ruby
# frozen_string_literal: true

# Stage 3 simple list test
require 'bundler/setup'
require 'review'
require 'review/ast/config'

# Set environment for Stage 3
ENV['REVIEW_AST_STAGE'] = '3'

config = ReVIEW::Configure.values
ReVIEW::I18n.setup('ja')
book = ReVIEW::Book::Base.new(config: config)

# Simple test content (no nesting)
test_content = <<~REVIEW
= Simple List Test

== Unordered List

Simple unordered list:

 * First item
 * Second item with @<b>{bold}
 * Third item

== Ordered List

Simple ordered list:

 1. Step one
 2. Step two with @<code>{code}
 3. Step three

== Definition List

Simple definition list:

 : Term A
    Definition of term A
 : Term B
    Definition with @<i>{italic}
REVIEW

# Create AST configuration
ast_config = ReVIEW::AST::Config.new(config)
compiler_options = ast_config.compiler_options

# Test with HTML builder
html_builder = ReVIEW::HTMLBuilder.new
compiler = ReVIEW::Compiler.new(html_builder, **compiler_options)

# Create mock chapter
chap = ReVIEW::Book::Chapter.new(book, nil, 'test_simple.re', 'test_simple.re')
chap.instance_variable_set(:@content, test_content)

puts '=== Stage 3: Simple List Test ==='
puts "AST Elements: #{compiler_options[:ast_elements]}"
puts

result = compiler.compile(chap)

# Extract list content
puts '--- Unordered List ---'
result.scan(%r{<ul>(.+?)</ul>}m).each do |match|
  puts match[0].strip
end

puts "\n--- Ordered List ---"
result.scan(%r{<ol>(.+?)</ol>}m).each do |match|
  puts match[0].strip
end

puts "\n--- Definition List ---"
result.scan(%r{<dl>(.+?)</dl>}m).each do |match|
  puts match[0].strip
end

# Compare with traditional mode
puts "\n--- Traditional Mode Comparison ---"
traditional_compiler = ReVIEW::Compiler.new(html_builder, ast_mode: false)
traditional_result = traditional_compiler.compile(chap)

if result == traditional_result
  puts '✅ Stage 3 output is IDENTICAL to traditional mode!'
else
  puts '❌ Output differs'

  # Save for detailed comparison
  File.write('simple_traditional.html', traditional_result)
  File.write('simple_stage3.html', result)
  puts 'Files saved for comparison'
end
