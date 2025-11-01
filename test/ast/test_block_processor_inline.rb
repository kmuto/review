# frozen_string_literal: true

require_relative '../test_helper'
require 'review/snapshot_location'
require 'review/ast/code_block_node'
require 'review/ast/paragraph_node'
require 'review/ast/text_node'
require 'review/ast/inline_node'
require 'review/ast/caption_node'
require 'review/ast/table_node'
require 'review/ast/image_node'
require 'review/ast/code_line_node'

class TestBlockProcessorInline < Test::Unit::TestCase
  def setup
    @location = ReVIEW::SnapshotLocation.new('test.re', 10)
  end

  def test_code_block_node_original_text_attribute
    code_block = ReVIEW::AST::CodeBlockNode.new(
      location: @location,
      original_text: 'test content'
    )

    assert_respond_to(code_block, :original_text)
    assert_equal 'test content', code_block.original_text
  end

  def test_code_block_node_original_text_method
    code_block1 = ReVIEW::AST::CodeBlockNode.new(
      location: @location,
      original_text: 'original content'
    )
    assert_equal 'original content', code_block1.original_text
    assert_equal ['original content'], code_block1.original_lines

    code_block2 = ReVIEW::AST::CodeBlockNode.new(
      location: @location,
      original_text: "line1\nline2"
    )
    assert_equal "line1\nline2", code_block2.original_text
    assert_equal ['line1', 'line2'], code_block2.original_lines
  end

  def test_original_and_processed_lines_methods
    # Test original_lines and processed_lines methods
    original_text = 'puts @<b>{hello}'

    code_block = ReVIEW::AST::CodeBlockNode.new(
      location: @location,
      original_text: original_text
    )

    # Create a code line with inline processing
    line_node = ReVIEW::AST::CodeLineNode.new(location: @location)
    text_node1 = ReVIEW::AST::TextNode.new(location: @location, content: 'puts ')
    inline_node = ReVIEW::AST::InlineNode.new(location: @location, inline_type: :b)
    inline_node.add_child(ReVIEW::AST::TextNode.new(location: @location, content: 'hello'))
    line_node.add_child(text_node1)
    line_node.add_child(inline_node)
    code_block.add_child(line_node)

    # Test original_lines (for builders that don't need inline processing)
    assert_equal ['puts @<b>{hello}'], code_block.original_lines

    # Test processed_lines (for builders that need inline processing)
    processed = code_block.processed_lines
    assert_equal 1, processed.size
    assert_equal 'puts @<b>{hello}', processed[0]
  end

  def test_processed_lines_method
    code_block = ReVIEW::AST::CodeBlockNode.new(
      location: @location,
      original_text: 'puts hello'
    )

    # Create a simple code line
    line_node = ReVIEW::AST::CodeLineNode.new(location: @location)
    text_node = ReVIEW::AST::TextNode.new(location: @location, content: 'puts hello')
    line_node.add_child(text_node)
    code_block.add_child(line_node)

    assert_respond_to(code_block, :processed_lines)
    processed = code_block.processed_lines
    assert_equal 1, processed.size
    assert_equal 'puts hello', processed[0]
  end

  # Caption tests
  def test_code_block_with_simple_caption
    # Test CodeBlockNode with simple text caption
    caption_node = ReVIEW::AST::CaptionNode.new(location: @location)
    caption_node.add_child(ReVIEW::AST::TextNode.new(location: @location, content: 'Simple Caption'))

    code_block = ReVIEW::AST::CodeBlockNode.new(
      location: @location,
      caption_node: caption_node,
      original_text: 'code line'
    )

    assert_not_nil(code_block.caption_text)
    assert_equal 'Simple Caption', code_block.caption_text
    assert_instance_of(ReVIEW::AST::CaptionNode, code_block.caption_node)
    assert_equal 'Simple Caption', code_block.caption_text
  end

  def test_code_block_with_inline_caption
    # Test CodeBlockNode with inline markup in caption
    caption_markup_text = 'Code with @<b>{bold} text'

    # Create CaptionNode with inline content
    caption_node = ReVIEW::AST::CaptionNode.new(location: @location)
    text1 = ReVIEW::AST::TextNode.new(location: @location, content: 'Code with ')
    inline = ReVIEW::AST::InlineNode.new(location: @location, inline_type: :b)
    inline.add_child(ReVIEW::AST::TextNode.new(location: @location, content: 'bold'))
    text2 = ReVIEW::AST::TextNode.new(location: @location, content: ' text')
    caption_node.add_child(text1)
    caption_node.add_child(inline)
    caption_node.add_child(text2)

    code_block = ReVIEW::AST::CodeBlockNode.new(
      location: @location,
      caption_node: caption_node,
      original_text: 'code line'
    )

    assert_not_nil(code_block.caption_text)
    assert_equal caption_markup_text, code_block.caption_text
    assert_instance_of(ReVIEW::AST::CaptionNode, code_block.caption_node)
    assert_equal caption_markup_text, code_block.caption_text
  end

  def test_table_node_with_caption
    caption_node = ReVIEW::AST::CaptionNode.new(location: @location)
    caption_node.add_child(ReVIEW::AST::TextNode.new(location: @location, content: 'Table Caption'))

    table = ReVIEW::AST::TableNode.new(
      location: @location,
      caption_node: caption_node
    )

    assert_not_nil(table.caption_text)
    assert_equal 'Table Caption', table.caption_text
    assert_instance_of(ReVIEW::AST::CaptionNode, table.caption_node)
    assert_equal 'Table Caption', table.caption_text
  end

  def test_image_node_with_caption
    caption = 'Figure @<i>{1}: Sample'
    image = ReVIEW::AST::ImageNode.new(
      location: @location,
      id: 'fig1',
      caption_node: CaptionParserHelper.parse(caption)
    )

    assert_not_nil(image.caption_text)
    assert_equal 'Figure @<i>{1}: Sample', image.caption_text
    assert_instance_of(ReVIEW::AST::CaptionNode, image.caption_node)
    assert_equal 'Figure @<i>{1}: Sample', image.caption_text
  end

  def test_caption_node_creation_directly
    # Simple string
    caption_node1 = CaptionParserHelper.parse('Simple text', location: @location)
    assert_instance_of(ReVIEW::AST::CaptionNode, caption_node1)
    assert_equal 'Simple text', caption_node1.to_text
    assert_equal 1, caption_node1.children.size
    assert_instance_of(ReVIEW::AST::TextNode, caption_node1.children.first)

    # Nil caption
    caption_node2 = CaptionParserHelper.parse(nil, location: @location)
    assert_nil(caption_node2)

    # Empty string
    caption_node3 = CaptionParserHelper.parse('', location: @location)
    assert_nil(caption_node3)

    # Already a CaptionNode
    existing_caption_node = ReVIEW::AST::CaptionNode.new(location: @location)
    existing_caption_node.add_child(ReVIEW::AST::TextNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), content: 'Existing'))
    caption_node4 = CaptionParserHelper.parse(existing_caption_node, location: @location)
    assert_equal existing_caption_node, caption_node4
  end

  def test_caption_with_multiple_nodes
    caption_node = ReVIEW::AST::CaptionNode.new(location: @location)
    text_node = ReVIEW::AST::TextNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), content: 'Text with ')
    inline_node = ReVIEW::AST::InlineNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), inline_type: :b)
    inline_node.add_child(ReVIEW::AST::TextNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), content: 'bold'))
    text_node2 = ReVIEW::AST::TextNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), content: ' content')
    caption_node.add_child(text_node)
    caption_node.add_child(inline_node)
    caption_node.add_child(text_node2)

    caption_node = CaptionParserHelper.parse(caption_node, location: @location)

    assert_instance_of(ReVIEW::AST::CaptionNode, caption_node)
    assert_equal 3, caption_node.children.size
    assert_equal 'Text with @<b>{bold} content', caption_node.to_text
  end

  def test_empty_caption_handling
    code_block = ReVIEW::AST::CodeBlockNode.new(
      location: @location,
      caption_node: nil,
      original_text: 'code'
    )
    assert_nil(code_block.caption_node)
    assert_equal('', code_block.caption_text)

    table = ReVIEW::AST::TableNode.new(
      location: @location,
      caption_node: nil
    )
    assert_nil(table.caption_node)
    assert_equal('', table.caption_text)
  end

  def test_caption_markup_text_compatibility
    caption_with_markup = 'Caption with @<b>{bold} and @<i>{italic}'

    # Create CaptionNode with inline content
    caption_node = ReVIEW::AST::CaptionNode.new(location: @location)
    text1 = ReVIEW::AST::TextNode.new(location: @location, content: 'Caption with ')
    bold = ReVIEW::AST::InlineNode.new(location: @location, inline_type: :b)
    bold.add_child(ReVIEW::AST::TextNode.new(location: @location, content: 'bold'))
    text2 = ReVIEW::AST::TextNode.new(location: @location, content: ' and ')
    italic = ReVIEW::AST::InlineNode.new(location: @location, inline_type: :i)
    italic.add_child(ReVIEW::AST::TextNode.new(location: @location, content: 'italic'))
    caption_node.add_child(text1)
    caption_node.add_child(bold)
    caption_node.add_child(text2)
    caption_node.add_child(italic)

    code_block = ReVIEW::AST::CodeBlockNode.new(
      location: @location,
      caption_node: caption_node,
      original_text: 'code'
    )

    # caption_markup_text should return the raw text with markup
    assert_equal caption_with_markup, code_block.caption_text

    # to_text on the caption should also return the same
    assert_equal caption_with_markup, code_block.caption_text
  end

  private

  def create_test_paragraph
    # Create paragraph: puts @<b>{hello}
    text_node = ReVIEW::AST::TextNode.new(location: @location, content: 'hello')
    inline_node = ReVIEW::AST::InlineNode.new(location: @location, inline_type: :b)
    inline_node.add_child(text_node)

    paragraph = ReVIEW::AST::ParagraphNode.new(location: @location)
    paragraph.add_child(ReVIEW::AST::TextNode.new(location: @location, content: 'puts '))
    paragraph.add_child(inline_node)

    paragraph
  end
end
