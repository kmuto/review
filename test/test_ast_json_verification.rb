#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'test_helper'
require 'review'
require 'review/ast/json_serializer'
require 'review/compiler'
require 'review/htmlbuilder'
require 'review/book'
require 'json'
require 'stringio'
require 'fileutils'

class ASTJSONVerificationTest < Test::Unit::TestCase
  def setup
    @fixtures_dir = File.join(__dir__, 'project')
    @test_files = Dir.glob(File.join(@fixtures_dir, '*.re')).reject do |f|
      File.basename(f).start_with?('test_stage') ||
        File.basename(f) == 'test-project.re' ||
        File.basename(f) == 'comprehensive_test.re'
    end.sort
    @output_dir = File.join(__dir__, '..', 'tmp', 'verification')
    FileUtils.mkdir_p(@output_dir)

    # Initialize I18n
    ReVIEW::I18n.setup('ja')

    @test_results = {}
  end

  def test_all_verification_files
    @test_files.each do |file_path|
      basename = File.basename(file_path, '.re')
      puts "\n=== Testing #{basename} ==="

      content = File.read(file_path)
      test_file_ast_compatibility(basename, content)
    end

    generate_verification_report
  end

  def test_structure_consistency
    # Test that AST compilation produces consistent JSON structure
    @test_files.each do |file_path|
      basename = File.basename(file_path, '.re')
      content = File.read(file_path)

      ast_json = compile_to_json(content, 'ast')

      # Parse JSON structure
      ast_data = JSON.parse(ast_json)

      # Verify basic structure
      assert_equal 'DocumentNode', ast_data['type'], "AST mode should create DocumentNode for #{basename}"

      # Verify children array exists
      assert ast_data.key?('children'), "AST mode should have children array for #{basename}"

      # Verify non-empty content has children
      next unless content.strip.length > 50 # Arbitrary threshold for non-trivial content

      assert ast_data['children'].any?, "AST mode should have children for non-trivial content in #{basename}"

      # Verify no error field is present (indicates successful compilation)
      assert_nil(ast_data['error'], "AST compilation should not have errors for #{basename}: #{ast_data['error']}")
    end
  end

  def test_element_coverage
    # Test that all major Re:VIEW elements are properly represented in JSON
    coverage_test_file = File.join(@fixtures_dir, 'complex_structure.re')
    content = File.read(coverage_test_file)

    ast_json = compile_to_json(content, 'ast')
    ast_data = JSON.parse(ast_json)

    element_types = extract_all_element_types(ast_data)

    # Verify presence of key element types (updated for new concrete node types)
    expected_types = %w[DocumentNode HeadlineNode ParagraphNode CodeBlockNode InlineNode TextNode]
    # Optional types that may appear depending on content: TableNode ImageNode MinicolumnNode BlockNode

    expected_types.each do |expected_type|
      assert element_types.include?(expected_type), "Expected element type #{expected_type} not found in AST JSON. Found types: #{element_types.join(', ')}"
    end
  end

  def test_inline_element_preservation
    # Test that inline elements are properly preserved in AST mode
    inline_test_file = File.join(@fixtures_dir, 'inline_elements.re')
    content = File.read(inline_test_file)

    ast_json = compile_to_json(content, 'ast')
    ast_data = JSON.parse(ast_json)

    # Count inline nodes
    ast_inline_count = count_element_type(ast_data, 'InlineNode')

    # AST mode should preserve inline structure
    assert ast_inline_count > 0, "AST mode should preserve inline structure. Found: #{ast_inline_count} inline nodes"

    # Verify no compilation errors
    assert_nil(ast_data['error'], "AST compilation should not have errors: #{ast_data['error']}")
  end

  def test_performance_comparison
    # Test that JSON generation performance is reasonable for AST mode
    large_test_file = File.join(@fixtures_dir, 'complex_structure.re')
    content = File.read(large_test_file)

    # Repeat content to make it larger
    large_content = content * 5

    # Test AST mode performance
    start_time = Time.now
    10.times { compile_to_json(large_content, 'ast') }
    end_time = Time.now

    avg_time = ((end_time - start_time) * 1000 / 10).round(2) # Average time in ms

    puts "\nAST JSON Generation Performance (average per compile): #{avg_time}ms"

    # Verify performance is reasonable (arbitrary 500ms threshold for large content)
    assert avg_time < 500.0, "AST mode is too slow: #{avg_time}ms (should be < 500ms)"
  end

  private

  def test_file_ast_compatibility(basename, content)
    json_output = compile_to_json(content, 'ast')
    output_file = File.join(@output_dir, "#{basename}_ast.json")
    File.write(output_file, json_output)

    begin
      json_data = JSON.parse(json_output)
      result = {
        success: true,
        json_data: json_data,
        output_file: output_file,
        size: json_output.length,
        children_count: json_data['children']&.length || 0,
        has_error: json_data.key?('error')
      }
    rescue JSON::ParserError => e
      result = {
        success: false,
        error: e.message,
        output_file: output_file
      }
    end

    @test_results[basename] = { 'ast' => result }

    # Verify AST mode produced valid JSON
    assert result[:success], "AST mode failed to produce valid JSON for #{basename}: #{result[:error]}"

    # Verify structure consistency
    if result[:success]
      puts "  AST children count: #{result[:children_count]}"

      # Non-empty files should have some content
      if content.strip.length > 10
        assert result[:children_count] > 0, "AST mode produced empty content for #{basename}"
      end

      # Should not have compilation errors
      assert !result[:has_error], "AST compilation had errors for #{basename}: #{result[:json_data]['error']}"
    end
  end

  def compile_to_json(content, mode, _config = nil)
    # Use direct AST compilation
    ast_compiler = ReVIEW::AST::Compiler.new
    ast_result = ast_compiler.compile(content)

    # Convert AST to JSON
    if ast_result
      options = ReVIEW::AST::JSONSerializer::Options.new(pretty: true)
      ReVIEW::AST::JSONSerializer.serialize(ast_result, options)
    else
      JSON.pretty_generate({ 'type' => 'DocumentNode', 'children' => [] })
    end
  rescue StandardError => e
    # Return error information in JSON format for debugging
    JSON.pretty_generate({
                           'type' => 'DocumentNode',
                           'children' => [],
                           'error' => e.message,
                           'mode' => mode
                         })
  end

  def extract_all_element_types(data, types = Set.new)
    if data.is_a?(Hash)
      types.add(data['type']) if data['type']
      data.each_value { |value| extract_all_element_types(value, types) }
    elsif data.is_a?(Array)
      data.each { |item| extract_all_element_types(item, types) }
    end
    types
  end

  def count_element_type(data, target_type, count = 0)
    if data.is_a?(Hash)
      count += 1 if data['type'] == target_type
      data.each_value { |value| count = count_element_type(value, target_type, count) }
    elsif data.is_a?(Array)
      data.each { |item| count = count_element_type(item, target_type, count) }
    end
    count
  end

  def generate_verification_report
    report_file = File.join(@output_dir, 'verification_report.txt')

    File.open(report_file, 'w') do |f|
      f.puts 'AST JSON Verification Report'
      f.puts "Generated: #{Time.now}"
      f.puts '=' * 60
      f.puts

      @test_results.each do |basename, results|
        f.puts "File: #{basename}"
        f.puts '-' * 40

        results.each do |mode, result|
          if result[:success]
            f.puts "  #{mode.ljust(15)}: ✅ #{result[:size]} chars, #{result[:children_count]} children"
          else
            f.puts "  #{mode.ljust(15)}: ❌ #{result[:error]}"
          end
        end

        f.puts
      end

      f.puts 'Summary:'
      f.puts "  Total files tested: #{@test_results.size}"
      f.puts "  All files passed: #{@test_results.values.all? { |r| r.values.all? { |mode_result| mode_result[:success] } }}"
    end

    puts "\nVerification report generated: #{report_file}"
  end
end
