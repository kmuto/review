# frozen_string_literal: true

require_relative 'test_helper'
require 'review/snapshot_location'
require 'review/ast/caption_node'
require 'review/ast/text_node'
require 'review/ast/inline_node'

class TestCaptionParser < Test::Unit::TestCase
  def setup
    @location = ReVIEW::SnapshotLocation.new('test.re', 1)
  end

  def test_parser_initialization
    parser = ReVIEW::AST::CaptionNode::Parser.new(location: @location)
    assert_instance_of(ReVIEW::AST::CaptionNode::Parser, parser)
  end

  def test_parse_nil_returns_nil
    parser = ReVIEW::AST::CaptionNode::Parser.new(location: @location)
    assert_nil(parser.parse(nil))
  end

  def test_parse_empty_string_returns_nil
    parser = ReVIEW::AST::CaptionNode::Parser.new(location: @location)
    assert_nil(parser.parse(''))
  end

  def test_parse_existing_caption_node_returns_same
    parser = ReVIEW::AST::CaptionNode::Parser.new(location: @location)
    caption_node = ReVIEW::AST::CaptionNode.new(location: @location)

    result = parser.parse(caption_node)
    assert_equal caption_node, result
  end

  def test_parse_simple_string_without_inline_processor
    parser = ReVIEW::AST::CaptionNode::Parser.new(location: @location)
    result = parser.parse('Simple Caption')

    assert_instance_of(ReVIEW::AST::CaptionNode, result)
    assert_equal 1, result.children.size
    assert_instance_of(ReVIEW::AST::TextNode, result.children.first)
    assert_equal 'Simple Caption', result.children.first.content
    assert_equal 'Simple Caption', result.to_text
  end

  def test_parse_string_with_inline_markup_without_processor
    parser = ReVIEW::AST::CaptionNode::Parser.new(location: @location)
    result = parser.parse('Caption with @<b>{bold}')

    assert_instance_of(ReVIEW::AST::CaptionNode, result)
    assert_equal 1, result.children.size
    assert_instance_of(ReVIEW::AST::TextNode, result.children.first)
    assert_equal 'Caption with @<b>{bold}', result.children.first.content
    assert_equal 'Caption with @<b>{bold}', result.to_text
    assert_equal false, result.contains_inline?
  end

  def test_parse_array_of_nodes
    parser = ReVIEW::AST::CaptionNode::Parser.new(location: @location)
    text_node = ReVIEW::AST::TextNode.new(location: @location, content: 'Test')
    result = parser.parse([text_node])

    assert_instance_of(ReVIEW::AST::CaptionNode, result)
    assert_equal 1, result.children.size
    assert_equal text_node, result.children.first
  end

  def test_parse_empty_array_returns_nil
    parser = ReVIEW::AST::CaptionNode::Parser.new(location: @location)
    assert_nil(parser.parse([]))
  end

  def test_parse_fallback_with_object
    parser = ReVIEW::AST::CaptionNode::Parser.new(location: @location)
    result = parser.parse(123)

    assert_instance_of(ReVIEW::AST::CaptionNode, result)
    assert_equal 1, result.children.size
    assert_equal '123', result.children.first.content
  end

  def test_parse_with_mock_inline_processor
    # Create a mock inline processor
    inline_processor = Object.new
    def inline_processor.parse_inline_elements(_text, caption_node)
      # Mock implementation: create a simple structure
      caption_node.add_child(ReVIEW::AST::TextNode.new(content: 'Caption with '))

      inline_node = ReVIEW::AST::InlineNode.new(inline_type: 'b')
      inline_node.add_child(ReVIEW::AST::TextNode.new(content: 'bold'))
      caption_node.add_child(inline_node)
    end

    parser = ReVIEW::AST::CaptionNode::Parser.new(
      location: @location,
      inline_processor: inline_processor
    )
    result = parser.parse('Caption with @<b>{bold}')

    assert_instance_of(ReVIEW::AST::CaptionNode, result)
    assert_equal 2, result.children.size
    assert_equal true, result.contains_inline?
    assert_equal 'Caption with @<b>{bold}', result.to_text
  end

  def test_factory_method_delegates_to_parser
    result = ReVIEW::AST::CaptionNode.parse('Test Caption', location: @location)

    assert_instance_of(ReVIEW::AST::CaptionNode, result)
    assert_equal 'Test Caption', result.to_text
  end
end
