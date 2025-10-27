#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../test_helper'
require 'review'
require 'review/ast/json_serializer'
require 'review/compiler'
require 'review/htmlbuilder'
require 'review/book'
require 'review/book/chapter'
require 'review/configure'
require 'json'
require 'stringio'
require 'fileutils'
require 'tmpdir'

class ASTJSONVerificationTest < Test::Unit::TestCase
  def setup
    @fixtures_dir = File.join(__dir__, '..', '..', 'samples', 'debug-book')
    @test_files = Dir.glob(File.join(@fixtures_dir, '*.re')).sort

    @tmpdir = Dir.mktmpdir('ast_json_verification')
    @output_dir = @tmpdir

    ReVIEW::I18n.setup('ja')

    # Initialize Book and Config for real Chapter usage
    @config = ReVIEW::Configure.values
    @config['language'] = 'ja'
    @book = ReVIEW::Book::Base.new(config: @config)

    @test_results = {}
  end

  def teardown
    FileUtils.rm_rf(@tmpdir) if @tmpdir && File.exist?(@tmpdir)
  end

  def test_all_verification_files
    @test_files.each do |file_path|
      basename = File.basename(file_path, '.re')
      content = File.read(file_path)
      test_file_ast_compatibility(basename, content)
    end
  end

  def test_structure_consistency
    # Test that AST compilation produces consistent JSON structure
    @test_files.each do |file_path|
      basename = File.basename(file_path, '.re')
      content = File.read(file_path)

      ast_json = compile_to_json(content, 'ast')
      ast_data = JSON.parse(ast_json)

      assert_equal 'DocumentNode', ast_data['type'], "AST mode should create DocumentNode for #{basename}"
      assert ast_data.key?('children'), "AST mode should have children array for #{basename}"

      next unless content.strip.length > 50 # Arbitrary threshold for non-trivial content

      assert ast_data['children'].any?, "AST mode should have children for non-trivial content in #{basename}"
      assert_nil(ast_data['error'], "AST compilation should not have errors for #{basename}: #{ast_data['error']}")
    end
  end

  def test_element_coverage
    # Test that all major Re:VIEW elements are properly represented in JSON
    coverage_test_file = File.join(@fixtures_dir, 'extreme_features.re')
    content = File.read(coverage_test_file)

    ast_json = compile_to_json(content, 'ast')
    ast_data = JSON.parse(ast_json)

    element_types = extract_all_element_types(ast_data)

    expected_types = %w[DocumentNode HeadlineNode ParagraphNode CodeBlockNode InlineNode TextNode]
    # Optional types that may appear depending on content: TableNode ImageNode MinicolumnNode BlockNode

    expected_types.each do |expected_type|
      assert element_types.include?(expected_type), "Expected element type #{expected_type} not found in AST JSON. Found types: #{element_types.join(', ')}"
    end
  end

  def test_inline_element_preservation
    # Test that inline elements are properly preserved in AST mode
    inline_test_file = File.join(@fixtures_dir, 'comprehensive.re')
    content = File.read(inline_test_file)

    ast_json = compile_to_json(content, 'ast')
    ast_data = JSON.parse(ast_json)

    ast_inline_count = count_element_type(ast_data, 'InlineNode')
    assert ast_inline_count > 0, "AST mode should preserve inline structure. Found: #{ast_inline_count} inline nodes"
    assert_nil(ast_data['error'], "AST compilation should not have errors: #{ast_data['error']}")
  end

  def test_caption_node_usage
    # Test that captions are represented as CaptionNode objects, not plain strings
    # This is critical for AST/Renderer architecture
    test_file = File.join(@fixtures_dir, 'comprehensive.re')
    content = File.read(test_file)

    ast_json = compile_to_json(content, 'ast')
    ast_data = JSON.parse(ast_json)

    captioned_nodes = find_nodes_with_captions(ast_data)
    assert captioned_nodes.any?, 'Should find at least one node with caption'

    captioned_nodes.each do |node|
      node_type = node['type']
      assert node.key?('caption_node'), "#{node_type} should have 'caption_node' field"

      caption_node = node['caption_node']
      assert_not_nil(caption_node, "#{node_type} caption_node should not be nil")
      assert_equal 'CaptionNode', caption_node['type'], "#{node_type} caption_node should be CaptionNode"

      assert caption_node.key?('children'), 'CaptionNode should have children array'
      assert caption_node['children'].is_a?(Array), 'CaptionNode children should be an array'
    end
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

    assert result[:success], "AST mode failed to produce valid JSON for #{basename}: #{result[:error]}"

    if result[:success]
      if content.strip.length > 10
        assert result[:children_count] > 0, "AST mode produced empty content for #{basename}"
      end

      assert !result[:has_error], "AST compilation had errors for #{basename}: #{result[:json_data]['error']}"
    end
  end

  def compile_to_json(content, mode, _config = nil)
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))

    chapter.generate_indexes
    @book.generate_indexes

    ast_compiler = ReVIEW::AST::Compiler.new
    ast_result = ast_compiler.compile_to_ast(chapter)

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

  def find_nodes_with_captions(data, nodes = [])
    if data.is_a?(Hash)
      nodes << data if data.key?('caption_node')
      data.each_value { |value| find_nodes_with_captions(value, nodes) }
    elsif data.is_a?(Array)
      data.each { |item| find_nodes_with_captions(item, nodes) }
    end
    nodes
  end
end
