#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'test_helper'
require 'review'
require 'review/ast/config'
require 'review/jsonbuilder'
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
    # Test that AST and Traditional modes produce structurally consistent JSON
    @test_files.each do |file_path|
      basename = File.basename(file_path, '.re')
      content = File.read(file_path)

      traditional_json = compile_to_json(content, 'traditional')
      ast_json = compile_to_json(content, 'ast')
      hybrid_json = compile_to_json(content, 'hybrid')

      # Parse JSON structures
      traditional_data = JSON.parse(traditional_json)
      ast_data = JSON.parse(ast_json)
      hybrid_data = JSON.parse(hybrid_json)

      # Verify basic structure consistency
      assert_equal 'DocumentNode', traditional_data['type'], "Traditional mode should create DocumentNode for #{basename}"
      assert_equal 'DocumentNode', ast_data['type'], "AST mode should create DocumentNode for #{basename}"
      assert_equal 'DocumentNode', hybrid_data['type'], "Hybrid mode should create DocumentNode for #{basename}"

      # Verify children arrays exist
      assert traditional_data.key?('children'), "Traditional mode should have children array for #{basename}"
      assert ast_data.key?('children'), "AST mode should have children array for #{basename}"
      assert hybrid_data.key?('children'), "Hybrid mode should have children array for #{basename}"

      # Verify non-empty content has children
      next unless content.strip.length > 50 # Arbitrary threshold for non-trivial content

      assert traditional_data['children'].any?, "Traditional mode should have children for non-trivial content in #{basename}"
      assert ast_data['children'].any?, "AST mode should have children for non-trivial content in #{basename}"
      assert hybrid_data['children'].any?, "Hybrid mode should have children for non-trivial content in #{basename}"
    end
  end

  def test_element_coverage
    # Test that all major Re:VIEW elements are properly represented in JSON
    coverage_test_file = File.join(@fixtures_dir, 'complex_structure.re')
    content = File.read(coverage_test_file)

    ast_json = compile_to_json(content, 'ast')
    ast_data = JSON.parse(ast_json)

    element_types = extract_all_element_types(ast_data)

    # Verify presence of key element types
    expected_types = %w[DocumentNode HeadlineNode ParagraphNode TableNode CodeBlockNode ImageNode InlineNode TextNode]

    expected_types.each do |expected_type|
      assert element_types.include?(expected_type), "Expected element type #{expected_type} not found in AST JSON. Found types: #{element_types.join(', ')}"
    end
  end

  def test_inline_element_preservation
    # Test that inline elements are properly preserved in AST mode vs simplified in traditional mode
    inline_test_file = File.join(@fixtures_dir, 'inline_elements.re')
    content = File.read(inline_test_file)

    traditional_json = compile_to_json(content, 'traditional')
    ast_json = compile_to_json(content, 'ast')

    traditional_data = JSON.parse(traditional_json)
    ast_data = JSON.parse(ast_json)

    # Count inline nodes
    traditional_inline_count = count_element_type(traditional_data, 'InlineNode')
    ast_inline_count = count_element_type(ast_data, 'InlineNode')

    # AST mode should have more detailed inline structure
    assert ast_inline_count >= traditional_inline_count,
           "AST mode should preserve more inline structure. Traditional: #{traditional_inline_count}, AST: #{ast_inline_count}"
  end

  def test_performance_comparison
    # Test that JSON generation performance is reasonable across modes
    large_test_file = File.join(@fixtures_dir, 'complex_structure.re')
    content = File.read(large_test_file)

    # Repeat content to make it larger
    large_content = content * 5

    times = {}

    %w[traditional ast hybrid].each do |mode|
      start_time = Time.now
      10.times { compile_to_json(large_content, mode) }
      end_time = Time.now

      times[mode] = ((end_time - start_time) * 1000 / 10).round(2) # Average time in ms
    end

    puts "\nJSON Generation Performance (average per compile):"
    times.each { |mode, time| puts "  #{mode}: #{time}ms" }

    # Verify no mode is dramatically slower (arbitrary 5x threshold)
    baseline = times['traditional']
    times.each do |mode, time|
      ratio = time / baseline
      assert ratio < 5.0, "#{mode} mode is too slow compared to traditional (#{ratio.round(2)}x slower)"
    end
  end

  private

  def test_file_ast_compatibility(basename, content)
    modes = {
      'traditional' => { mode: 'off' },
      'ast' => { mode: 'full' },
      'hybrid_stage3' => { mode: 'hybrid', stage: 3 },
      'hybrid_stage7' => { mode: 'hybrid', stage: 7 }
    }

    results = {}

    modes.each do |mode_name, config|
      json_output = compile_to_json(content, mode_name, config)
      output_file = File.join(@output_dir, "#{basename}_#{mode_name}.json")
      File.write(output_file, json_output)

      begin
        json_data = JSON.parse(json_output)
        results[mode_name] = {
          success: true,
          json_data: json_data,
          output_file: output_file,
          size: json_output.length,
          children_count: json_data['children']&.length || 0
        }
      rescue JSON::ParserError => e
        results[mode_name] = {
          success: false,
          error: e.message,
          output_file: output_file
        }
      end
    end

    @test_results[basename] = results

    # Verify all modes produced valid JSON
    results.each do |mode_name, result|
      assert result[:success], "#{mode_name} mode failed to produce valid JSON for #{basename}: #{result[:error]}"
    end

    # Verify structure consistency
    if results.values.all? { |r| r[:success] }
      children_counts = results.transform_values { |r| r[:children_count] }
      puts "  Children counts: #{children_counts}"

      # All modes should have some content for non-empty files
      if content.strip.length > 10
        children_counts.each do |mode, count|
          assert count > 0, "#{mode} mode produced empty content for #{basename}"
        end
      end
    end
  end

  def compile_to_json(content, mode, config = nil)
    # Determine configuration
    review_config = ReVIEW::Configure.values
    case mode
    when 'traditional'
      review_config['ast'] = { 'mode' => 'off' }
    when 'ast'
      review_config['ast'] = { 'mode' => 'full' }
    when 'hybrid'
      review_config['ast'] = { 'mode' => 'hybrid', 'stage' => 7 }
    else
      review_config['ast'] = config if config
    end

    # Create compiler and builder
    ast_config = ReVIEW::AST::Config.new(review_config)
    compiler_options = ast_config.compiler_options

    json_builder = ReVIEW::JSONBuilder.new
    compiler = ReVIEW::Compiler.new(json_builder, **compiler_options)

    # Set up book and chapter
    book = ReVIEW::Book::Base.new
    book.config = review_config

    chapter = ReVIEW::Book::Chapter.new(book, 1, 'test', nil, StringIO.new(content))
    location = ReVIEW::Location.new(nil, nil)
    json_builder.bind(compiler, chapter, location)

    # Compile and return JSON
    compiler.compile(chapter)
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
