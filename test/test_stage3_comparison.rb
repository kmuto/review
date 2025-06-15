#!/usr/bin/env ruby
# frozen_string_literal: true

# Stage 3 output comparison tool
require 'bundler/setup'
require 'review'
require 'review/ast/config'

def compile_with_mode(mode_description, ast_mode, ast_elements = [])
  puts "=== #{mode_description} ==="

  config = ReVIEW::Configure.values
  ReVIEW::I18n.setup('ja')
  book = ReVIEW::Book::Base.new(config: config)

  content = File.read('test/fixtures/test_stage3.re')

  # Create builder and compiler
  builder = ReVIEW::HTMLBuilder.new
  compiler = ReVIEW::Compiler.new(builder, ast_mode: ast_mode, ast_elements: ast_elements)

  # Create mock chapter object
  chap = ReVIEW::Book::Chapter.new(book, nil, 'test/fixtures/test_stage3.re', 'test/fixtures/test_stage3.re')
  chap.instance_variable_set(:@content, content)

  start_time = Time.now
  result = compiler.compile(chap)
  compilation_time = Time.now - start_time

  puts "Compilation time: #{(compilation_time * 1000).round(2)}ms"
  puts "Output size: #{result.length} characters"
  puts

  result
end

# Test traditional mode
traditional_result = compile_with_mode('Traditional Mode', false)

# Test Stage 2 (headline + paragraph)
stage2_result = compile_with_mode('Stage 2 (Headline + Paragraph AST)', true, %i[headline paragraph])

# Test Stage 3 (headline + paragraph + lists)
stage3_result = compile_with_mode('Stage 3 (Headline + Paragraph + Lists AST)', true, %i[headline paragraph ulist olist dlist])

# Compare results
puts '=== Comparison ==='

puts "\n--- Stage 2 vs Traditional ---"
if traditional_result == stage2_result
  puts '✅ Stage 2 output is IDENTICAL to traditional mode'
else
  puts '❌ Stage 2 output differs from traditional mode'
end

puts "\n--- Stage 3 vs Traditional ---"
if traditional_result == stage3_result
  puts '✅ Stage 3 output is IDENTICAL to traditional mode!'
else
  puts '❌ Stage 3 output differs from traditional mode'
  File.write('traditional_s3.html', traditional_result)
  File.write('stage3_s3.html', stage3_result)

  # Find first difference
  traditional_lines = traditional_result.lines
  stage3_lines = stage3_result.lines

  min_lines = [traditional_lines.length, stage3_lines.length].min
  (0...min_lines).each do |i|
    next unless traditional_lines[i] != stage3_lines[i]

    puts "\nFirst difference at line #{i + 1}:"
    puts "Traditional: #{traditional_lines[i].strip}"
    puts "Stage 3:     #{stage3_lines[i].strip}"
    break
  end

  if traditional_lines.length != stage3_lines.length
    puts "\nLine count differs:"
    puts "Traditional: #{traditional_lines.length} lines"
    puts "Stage 3:     #{stage3_lines.length} lines"
  end
end

puts "\n--- Stage 3 vs Stage 2 ---"
if stage2_result == stage3_result
  puts '✅ Stage 3 output is IDENTICAL to Stage 2'
else
  puts '⚠️  Stage 3 output differs from Stage 2 (expected - lists now use AST)'
end
