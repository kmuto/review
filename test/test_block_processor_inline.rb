# frozen_string_literal: true

require_relative 'test_helper'
require 'review/snapshot_location'
require 'review/ast/code_block_node'
require 'review/ast/paragraph_node'
require 'review/ast/text_node'
require 'review/ast/inline_node'
require 'review/ast/caption_node'
require 'review/ast/table_node'
require 'review/ast/image_node'

class TestBlockProcessorInline < Test::Unit::TestCase
  def setup
    @location = ReVIEW::SnapshotLocation.new('test.re', 10)
  end

  def test_code_block_node_original_text_attribute
    # Test that CodeBlockNode has original_text attribute
    code_block = ReVIEW::AST::CodeBlockNode.new(
      location: @location,
      original_text: 'test content'
    )

    assert_respond_to(code_block, :original_text)
    assert_equal 'test content', code_block.original_text
  end

  def test_code_block_node_raw_content_method
    # Test raw_content method behavior
    code_block1 = ReVIEW::AST::CodeBlockNode.new(
      original_text: 'original content',
      lines: ['line1', 'line2']
    )
    assert_equal 'original content', code_block1.raw_content

    code_block2 = ReVIEW::AST::CodeBlockNode.new(
      lines: ['line1', 'line2']
    )
    assert_equal "line1\nline2", code_block2.raw_content
  end

  def test_get_lines_for_builder_method
    # Test get_lines_for_builder method
    lines = ['puts @<b>{hello}']
    processed_lines = [create_test_paragraph]

    code_block = ReVIEW::AST::CodeBlockNode.new(
      location: @location,
      lines: lines,
      processed_lines: processed_lines
    )

    # Test for builder that doesn't need inline processing
    result_no_inline = code_block.get_lines_for_builder(builder_needs_inline: false)
    assert_equal lines, result_no_inline

    # Test for builder that needs inline processing
    result_inline = code_block.get_lines_for_builder(builder_needs_inline: true)
    assert_equal processed_lines, result_inline
  end

  def test_processed_lines_attribute
    # Test processed_lines attribute
    processed_lines = [create_test_paragraph]

    code_block = ReVIEW::AST::CodeBlockNode.new(
      location: @location,
      processed_lines: processed_lines
    )

    assert_respond_to(code_block, :processed_lines)
    assert_equal processed_lines, code_block.processed_lines
  end

  # Caption tests
  def test_code_block_with_simple_caption
    # Test CodeBlockNode with simple text caption
    code_block = ReVIEW::AST::CodeBlockNode.new(
      location: @location,
      caption: 'Simple Caption',
      lines: ['code line']
    )

    assert_not_nil(code_block.caption)
    assert_instance_of(ReVIEW::AST::CaptionNode, code_block.caption)
    assert_equal 'Simple Caption', code_block.caption_markup_text
  end

  def test_code_block_with_inline_caption
    # Test CodeBlockNode with inline markup in caption
    caption_markup_text = 'Code with @<b>{bold} text'
    code_block = ReVIEW::AST::CodeBlockNode.new(
      location: @location,
      caption: caption_markup_text,
      lines: ['code line']
    )

    assert_not_nil(code_block.caption)
    assert_instance_of(ReVIEW::AST::CaptionNode, code_block.caption)
    assert_equal caption_markup_text, code_block.caption_markup_text
  end

  def test_table_node_with_caption
    # Test TableNode with caption
    table = ReVIEW::AST::TableNode.new(
      location: @location,
      caption: 'Table Caption',
      headers: [['Header 1', 'Header 2']],
      rows: [['Data 1', 'Data 2']]
    )

    assert_not_nil(table.caption)
    assert_instance_of(ReVIEW::AST::CaptionNode, table.caption)
    assert_equal 'Table Caption', table.caption_markup_text
  end

  def test_image_node_with_caption
    # Test ImageNode with caption
    image = ReVIEW::AST::ImageNode.new(
      location: @location,
      id: 'fig1',
      caption: 'Figure @<i>{1}: Sample'
    )

    assert_not_nil(image.caption)
    assert_instance_of(ReVIEW::AST::CaptionNode, image.caption)
    assert_equal 'Figure @<i>{1}: Sample', image.caption_markup_text
  end

  def test_caption_node_creation_directly
    # Test CaptionNode creation with various inputs
    # Simple string
    caption1 = ReVIEW::AST::CaptionNode.parse('Simple text', location: @location)
    assert_instance_of(ReVIEW::AST::CaptionNode, caption1)
    assert_equal 'Simple text', caption1.to_text
    assert_equal 1, caption1.children.size
    assert_instance_of(ReVIEW::AST::TextNode, caption1.children.first)

    # Nil caption
    caption2 = ReVIEW::AST::CaptionNode.parse(nil, location: @location)
    assert_nil(caption2)

    # Empty string
    caption3 = ReVIEW::AST::CaptionNode.parse('', location: @location)
    assert_nil(caption3)

    # Already a CaptionNode
    existing_caption = ReVIEW::AST::CaptionNode.new(location: @location)
    existing_caption.add_child(ReVIEW::AST::TextNode.new(content: 'Existing'))
    caption4 = ReVIEW::AST::CaptionNode.parse(existing_caption, location: @location)
    assert_equal existing_caption, caption4
  end

  def test_caption_with_array_of_nodes
    # Test CaptionNode creation with array of nodes
    text_node = ReVIEW::AST::TextNode.new(content: 'Text with ')
    inline_node = ReVIEW::AST::InlineNode.new(inline_type: 'b')
    inline_node.add_child(ReVIEW::AST::TextNode.new(content: 'bold'))
    text_node2 = ReVIEW::AST::TextNode.new(content: ' content')

    nodes_array = [text_node, inline_node, text_node2]
    caption = ReVIEW::AST::CaptionNode.parse(nodes_array, location: @location)

    assert_instance_of(ReVIEW::AST::CaptionNode, caption)
    assert_equal 3, caption.children.size
    assert_equal 'Text with @<b>{bold} content', caption.to_text
  end

  def test_empty_caption_handling
    # Test nodes with empty/nil captions
    code_block = ReVIEW::AST::CodeBlockNode.new(
      location: @location,
      caption: nil,
      lines: ['code']
    )
    assert_nil(code_block.caption)
    assert_equal '', code_block.caption_markup_text

    table = ReVIEW::AST::TableNode.new(
      location: @location,
      caption: '',
      headers: [['H1']],
      rows: [['D1']]
    )
    assert_nil(table.caption)
    assert_equal '', table.caption_markup_text
  end

  def test_caption_markup_text_compatibility
    # Test caption_markup_text method returns plain text
    caption_with_markup = 'Caption with @<b>{bold} and @<i>{italic}'

    code_block = ReVIEW::AST::CodeBlockNode.new(
      location: @location,
      caption: caption_with_markup,
      lines: ['code']
    )

    # caption_markup_text should return the raw text with markup
    assert_equal caption_with_markup, code_block.caption_markup_text

    # to_text on the caption should also return the same
    assert_equal caption_with_markup, code_block.caption.to_text
  end

  private

  def create_test_paragraph
    # Create paragraph: puts @<b>{hello}
    text_node = ReVIEW::AST::TextNode.new(location: @location, content: 'hello')
    inline_node = ReVIEW::AST::InlineNode.new(location: @location, inline_type: 'b')
    inline_node.add_child(text_node)

    paragraph = ReVIEW::AST::ParagraphNode.new(location: @location)
    paragraph.add_child(ReVIEW::AST::TextNode.new(location: @location, content: 'puts '))
    paragraph.add_child(inline_node)

    paragraph
  end
end
