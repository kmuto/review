# frozen_string_literal: true

require_relative '../test_helper'
require 'review/snapshot_location'
require 'review/ast/caption_node'
require 'review/ast/text_node'
require 'review/ast/inline_node'
require 'review/ast/compiler'

class TestCaptionParser < Test::Unit::TestCase
  def setup
    @location = ReVIEW::SnapshotLocation.new('test.re', 1)
  end

  def test_parser_initialization
    parser = CaptionParserHelper.new(location: @location)
    assert_instance_of(CaptionParserHelper, parser)
  end

  def test_parse_nil_returns_nil
    parser = CaptionParserHelper.new(location: @location)
    assert_nil(parser.parse(nil))
  end

  def test_parse_empty_string_returns_nil
    parser = CaptionParserHelper.new(location: @location)
    assert_nil(parser.parse(''))
  end

  def test_parse_existing_caption_node_returns_same
    parser = CaptionParserHelper.new(location: @location)
    caption_node = ReVIEW::AST::CaptionNode.new(location: @location)

    result = parser.parse(caption_node)
    assert_equal caption_node, result
  end

  def test_parse_simple_string_without_inline_processor
    parser = CaptionParserHelper.new(location: @location)
    result = parser.parse('Simple Caption')

    assert_instance_of(ReVIEW::AST::CaptionNode, result)
    assert_equal 1, result.children.size
    assert_instance_of(ReVIEW::AST::TextNode, result.children.first)
    assert_equal 'Simple Caption', result.children.first.content
    assert_equal 'Simple Caption', result.to_text
  end

  def test_parse_string_with_inline_markup_without_processor
    parser = CaptionParserHelper.new(location: @location)
    result = parser.parse('Caption with @<b>{bold}')

    assert_instance_of(ReVIEW::AST::CaptionNode, result)
    assert_equal 1, result.children.size
    assert_instance_of(ReVIEW::AST::TextNode, result.children.first)
    assert_equal 'Caption with @<b>{bold}', result.children.first.content
    assert_equal 'Caption with @<b>{bold}', result.to_text
    assert_equal false, result.contains_inline?
  end

  def test_parse_with_inline_processor
    # Create a real inline processor from AST::Compiler
    compiler = ReVIEW::AST::Compiler.new
    inline_processor = compiler.inline_processor

    parser = CaptionParserHelper.new(
      location: @location,
      inline_processor: inline_processor
    )
    result = parser.parse('Caption with @<b>{bold}')

    assert_instance_of(ReVIEW::AST::CaptionNode, result)
    assert_operator(result.children.size, :>=, 1)
    assert_equal true, result.contains_inline?
    # Real inline processor parses the markup, so to_text extracts text content
    assert_match(/Caption with.*bold/, result.to_text)
  end

  def test_factory_method_delegates_to_parser
    result = CaptionParserHelper.parse('Test Caption', location: @location)

    assert_instance_of(ReVIEW::AST::CaptionNode, result)
    assert_equal 'Test Caption', result.to_text
  end
end
