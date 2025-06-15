#!/usr/bin/env ruby
# frozen_string_literal: true

# Stage 1 output comparison tool
require 'bundler/setup'
require 'review'
require 'review/ast/config'

def compile_with_mode(mode_description, ast_mode, ast_elements = [])
  puts "=== #{mode_description} ==="

  config = ReVIEW::Configure.values
  ReVIEW::I18n.setup('ja')
  book = ReVIEW::Book::Base.new(config: config)

  content = File.read('test/fixtures/test_stage1.re')

  # Create builder and compiler
  builder = ReVIEW::HTMLBuilder.new
  compiler = ReVIEW::Compiler.new(builder, ast_mode: ast_mode, ast_elements: ast_elements)

  # Create mock chapter object
  chap = ReVIEW::Book::Chapter.new(book, nil, 'test/fixtures/test_stage1.re', 'test/fixtures/test_stage1.re')
  chap.instance_variable_set(:@content, content)

  start_time = Time.now
  result = compiler.compile(chap)
  compilation_time = Time.now - start_time

  puts "Compilation time: #{(compilation_time * 1000).round(2)}ms"
  puts "Output size: #{result.length} characters"
  puts 'First 200 characters:'
  puts result[0..200]
  puts '...' if result.length > 200
  puts

  result
end

# Test traditional mode
traditional_result = compile_with_mode('Traditional Mode', false)

# Test Stage 1 (headline AST mode)
stage1_result = compile_with_mode('Stage 1 (Headline AST)', true, [:headline])

# Compare results
puts '=== Comparison ==='
if traditional_result == stage1_result
  puts '✅ Output is IDENTICAL - Stage 1 maintains perfect compatibility!'
else
  puts '❌ Output differs - investigating differences...'

  # Save both outputs for comparison
  File.write('traditional_output.html', traditional_result)
  File.write('stage1_output.html', stage1_result)

  puts 'Traditional output saved to: traditional_output.html'
  puts 'Stage 1 output saved to: stage1_output.html'

  # Show first difference
  traditional_lines = traditional_result.lines
  stage1_lines = stage1_result.lines

  traditional_lines.each_with_index do |line, i|
    next unless stage1_lines[i] != line

    puts "\nFirst difference at line #{i + 1}:"
    puts "Traditional: #{line.strip}"
    puts "Stage 1:     #{stage1_lines[i]&.strip || '(missing)'}"
    break
  end
end
