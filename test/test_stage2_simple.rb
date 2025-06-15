#!/usr/bin/env ruby
# frozen_string_literal: true

# Stage 2 simple inline test
require 'bundler/setup'
require 'review'
require 'review/ast_config'

# Set environment for Stage 2
ENV['REVIEW_AST_STAGE'] = '2'

config = ReVIEW::Configure.values
ReVIEW::I18n.setup('ja')
book = ReVIEW::Book::Base.new(config: config)

# Simple test content
test_content = <<~REVIEW
= Simple Inline Test

This is @<b>{bold}, @<i>{italic}, and @<code>{code}.

Another paragraph with @<tt>{teletype} text.
REVIEW

# Create AST configuration
ast_config = ReVIEW::ASTConfig.new(config)
compiler_options = ast_config.compiler_options

# Test with HTML builder
html_builder = ReVIEW::HTMLBuilder.new
compiler = ReVIEW::Compiler.new(html_builder, **compiler_options)

# Create mock chapter
chap = ReVIEW::Book::Chapter.new(book, nil, 'test_simple.re', 'test_simple.re')
chap.instance_variable_set(:@content, test_content)

puts '=== Stage 2: Simple Inline Elements Test ==='
puts "AST Elements: #{compiler_options[:ast_elements]}"
puts

result = compiler.compile(chap)

# Extract and display paragraph content
puts '--- HTML Output ---'
result.scan(%r{<p>(.+?)</p>}m).each_with_index do |match, i|
  puts "Paragraph #{i + 1}: #{match[0]}"
end

# Compare with traditional mode
puts "\n--- Traditional Mode Comparison ---"
traditional_compiler = ReVIEW::Compiler.new(html_builder, ast_mode: false)
traditional_result = traditional_compiler.compile(chap)

if result == traditional_result
  puts '✅ Stage 2 output is IDENTICAL to traditional mode!'
else
  puts '❌ Output differs'
  puts "Stage 2 length: #{result.length}"
  puts "Traditional length: #{traditional_result.length}"
end
