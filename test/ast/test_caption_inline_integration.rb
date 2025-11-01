# frozen_string_literal: true

require_relative '../test_helper'
require 'review/snapshot_location'
require 'review/ast/caption_node'
require 'review/ast/code_block_node'
require 'review/ast/text_node'
require 'review/ast/inline_node'

class TestCaptionInlineIntegration < Test::Unit::TestCase
  def setup
    @location = ReVIEW::SnapshotLocation.new('test.re', 1)
  end

  def test_simple_caption_behavior_in_code_block
    # Test that simple captions become CaptionNode in CodeBlockNode
    caption_node = ReVIEW::AST::CaptionNode.new(location: @location)
    caption_node.add_child(ReVIEW::AST::TextNode.new(location: @location, content: 'Simple Caption'))

    code_block = ReVIEW::AST::CodeBlockNode.new(
      location: @location,
      caption_node: caption_node
    )

    assert_equal 'Simple Caption', code_block.caption_text
    assert_instance_of(ReVIEW::AST::CaptionNode, code_block.caption_node)
    assert_equal 'Simple Caption', code_block.caption_text
  end

  def test_caption_node_behavior_in_code_block
    # Test that CaptionNode works correctly in CodeBlockNode
    caption_node = ReVIEW::AST::CaptionNode.new(location: @location)
    caption_node.add_child(ReVIEW::AST::TextNode.new(location: @location, content: 'Caption with '))

    inline_node = ReVIEW::AST::InlineNode.new(location: @location, inline_type: :b)
    inline_node.add_child(ReVIEW::AST::TextNode.new(location: @location, content: 'bold'))
    caption_node.add_child(inline_node)

    caption_node.add_child(ReVIEW::AST::TextNode.new(location: @location, content: ' text'))

    code_block = ReVIEW::AST::CodeBlockNode.new(
      location: @location,
      caption_node: caption_node
    )

    assert_equal 'Caption with @<b>{bold} text', code_block.caption_text
    assert_instance_of(ReVIEW::AST::CaptionNode, code_block.caption_node)
    assert_equal 'Caption with @<b>{bold} text', code_block.caption_text
  end

  def test_empty_caption_handling
    # Test empty captions
    code_block = ReVIEW::AST::CodeBlockNode.new(
      location: @location
    )

    assert_equal('', code_block.caption_text)
  end

  def test_nil_caption_handling
    # Test when caption is not provided
    code_block = ReVIEW::AST::CodeBlockNode.new(
      location: @location
    )

    assert_equal('', code_block.caption_text)
  end
end
