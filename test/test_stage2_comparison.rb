#!/usr/bin/env ruby
# frozen_string_literal: true

# Stage 2 output comparison tool
require 'bundler/setup'
require 'review'
require 'review/ast/config'

def compile_with_mode(mode_description, ast_mode, ast_elements = [])
  puts "=== #{mode_description} ==="

  config = ReVIEW::Configure.values
  ReVIEW::I18n.setup('ja')
  book = ReVIEW::Book::Base.new(config: config)

  content = File.read('test/fixtures/test_stage2.re')

  # Create builder and compiler
  builder = ReVIEW::HTMLBuilder.new
  compiler = ReVIEW::Compiler.new(builder, ast_mode: ast_mode, ast_elements: ast_elements)

  # Create mock chapter object
  chap = ReVIEW::Book::Chapter.new(book, nil, 'test/fixtures/test_stage2.re', 'test/fixtures/test_stage2.re')
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

# Test Stage 1 (headline only)
stage1_result = compile_with_mode('Stage 1 (Headline AST)', true, [:headline])

# Test Stage 2 (headline + paragraph)
stage2_result = compile_with_mode('Stage 2 (Headline + Paragraph AST)', true, %i[headline paragraph])

# Compare results
puts '=== Comparison ==='
puts "\n--- Stage 1 vs Traditional ---"
if traditional_result == stage1_result
  puts '✅ Stage 1 output is IDENTICAL to traditional mode'
else
  puts '❌ Stage 1 output differs from traditional mode'
  File.write('traditional_s2.html', traditional_result)
  File.write('stage1_s2.html', stage1_result)
end

puts "\n--- Stage 2 vs Traditional ---"
if traditional_result == stage2_result
  puts '✅ Stage 2 output is IDENTICAL to traditional mode'
else
  puts '❌ Stage 2 output differs from traditional mode'
  File.write('traditional_s2.html', traditional_result)
  File.write('stage2_s2.html', stage2_result)

  # Show size difference
  size_diff = stage2_result.length - traditional_result.length
  puts "Size difference: #{size_diff} characters"

  # Find first difference
  traditional_lines = traditional_result.lines
  stage2_lines = stage2_result.lines

  traditional_lines.each_with_index do |line, i|
    next unless stage2_lines[i] != line

    puts "\nFirst difference at line #{i + 1}:"
    puts "Traditional: #{line.strip}"
    puts "Stage 2:     #{stage2_lines[i]&.strip || '(missing)'}"
    break
  end
end

puts "\n--- Stage 2 vs Stage 1 ---"
if stage1_result == stage2_result
  puts '✅ Stage 2 output is IDENTICAL to Stage 1'
else
  puts '⚠️  Stage 2 output differs from Stage 1 (expected - paragraphs now use AST)'
end
