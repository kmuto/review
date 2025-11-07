# frozen_string_literal: true

require_relative '../test_helper'
require 'review/snapshot_location'
require 'review/ast/caption_node'
require 'review/ast/text_node'
require 'review/ast/inline_node'

class TestCaptionNode < Test::Unit::TestCase
  def setup
    @location = ReVIEW::SnapshotLocation.new('test.re', 1)
  end

  def test_caption_node_initialization
    caption = ReVIEW::AST::CaptionNode.new(location: @location)
    assert_instance_of(ReVIEW::AST::CaptionNode, caption)
    assert_equal @location, caption.location
    assert_empty(caption.children)
  end

  def test_empty_caption
    caption = ReVIEW::AST::CaptionNode.new(location: @location)
    assert caption.empty?
    assert_equal false, caption.contains_inline?
  end

  def test_simple_text_caption
    caption = ReVIEW::AST::CaptionNode.new(location: @location)
    text_node = ReVIEW::AST::TextNode.new(location: @location, content: 'Simple caption')
    caption.add_child(text_node)

    assert_equal false, caption.empty?
    assert_equal false, caption.contains_inline?

    # Verify structure
    assert_equal 1, caption.children.size
    assert_instance_of(ReVIEW::AST::TextNode, caption.children[0])
    assert_equal 'Simple caption', caption.children[0].content
  end

  def test_caption_with_inline_elements
    caption = ReVIEW::AST::CaptionNode.new(location: @location)

    # Add text: "Caption with "
    caption.add_child(ReVIEW::AST::TextNode.new(location: @location, content: 'Caption with '))

    # Add inline: @<b>{bold text}
    inline_node = ReVIEW::AST::InlineNode.new(location: @location, inline_type: :b)
    inline_node.add_child(ReVIEW::AST::TextNode.new(location: @location, content: 'bold text'))
    caption.add_child(inline_node)

    # Add more text: " content"
    caption.add_child(ReVIEW::AST::TextNode.new(location: @location, content: ' content'))

    assert_equal false, caption.empty?
    assert_equal true, caption.contains_inline?

    # Verify structure: "Caption with @<b>{bold text} content"
    assert_equal 3, caption.children.size
    assert_instance_of(ReVIEW::AST::TextNode, caption.children[0])
    assert_equal 'Caption with ', caption.children[0].content
    assert_instance_of(ReVIEW::AST::InlineNode, caption.children[1])
    assert_equal :b, caption.children[1].inline_type
    assert_equal 1, caption.children[1].children.size
    assert_equal 'bold text', caption.children[1].children[0].content
    assert_instance_of(ReVIEW::AST::TextNode, caption.children[2])
    assert_equal ' content', caption.children[2].content
  end

  def test_caption_with_nested_inline
    caption = ReVIEW::AST::CaptionNode.new(location: @location)

    # Create: Text @<i>{italic @<b>{bold}} more
    text1 = ReVIEW::AST::TextNode.new(location: @location, content: 'Text ')
    caption.add_child(text1)

    # Create nested inline: @<i>{italic @<b>{bold}}
    bold_text = ReVIEW::AST::TextNode.new(location: @location, content: 'bold')
    bold_inline = ReVIEW::AST::InlineNode.new(location: @location, inline_type: :b)
    bold_inline.add_child(bold_text)

    italic_text = ReVIEW::AST::TextNode.new(location: @location, content: 'italic ')
    italic_inline = ReVIEW::AST::InlineNode.new(location: @location, inline_type: :i)
    italic_inline.add_child(italic_text)
    italic_inline.add_child(bold_inline)
    caption.add_child(italic_inline)

    text2 = ReVIEW::AST::TextNode.new(location: @location, content: ' more')
    caption.add_child(text2)

    assert_equal true, caption.contains_inline?

    # Verify structure: "Text @<i>{italic @<b>{bold}} more"
    assert_equal 3, caption.children.size
    assert_instance_of(ReVIEW::AST::TextNode, caption.children[0])
    assert_equal 'Text ', caption.children[0].content

    # Check nested inline structure
    assert_instance_of(ReVIEW::AST::InlineNode, caption.children[1])
    assert_equal :i, caption.children[1].inline_type
    assert_equal 2, caption.children[1].children.size
    assert_equal 'italic ', caption.children[1].children[0].content

    # Check inner inline
    inner_inline = caption.children[1].children[1]
    assert_instance_of(ReVIEW::AST::InlineNode, inner_inline)
    assert_equal :b, inner_inline.inline_type
    assert_equal 1, inner_inline.children.size
    assert_equal 'bold', inner_inline.children[0].content

    assert_instance_of(ReVIEW::AST::TextNode, caption.children[2])
    assert_equal ' more', caption.children[2].content
  end

  def test_caption_serialization_simple
    caption = ReVIEW::AST::CaptionNode.new(location: @location)
    text_node = ReVIEW::AST::TextNode.new(location: @location, content: 'Simple caption')
    caption.add_child(text_node)

    # Simple text caption should serialize as children array for compatibility
    result = caption.to_h
    expected = {
      type: 'CaptionNode',
      location: { filename: 'test.re', lineno: 1 },
      children: [
        {
          type: 'TextNode',
          content: 'Simple caption',
          location: { filename: 'test.re', lineno: 1 }
        }
      ]
    }
    assert_equal expected, result
  end

  def test_caption_serialization_complex
    caption = ReVIEW::AST::CaptionNode.new(location: @location)
    caption.add_child(ReVIEW::AST::TextNode.new(location: @location, content: 'Caption with '))

    inline_node = ReVIEW::AST::InlineNode.new(location: @location, inline_type: :b)
    inline_node.add_child(ReVIEW::AST::TextNode.new(location: @location, content: 'bold'))
    caption.add_child(inline_node)

    # Complex caption should serialize as node structure
    result = caption.to_h
    assert_instance_of(Hash, result)
    assert_equal 'CaptionNode', result[:type]
    assert_equal 2, result[:children].size
  end

  def test_empty_whitespace_caption
    caption = ReVIEW::AST::CaptionNode.new(location: @location)
    text_node = ReVIEW::AST::TextNode.new(location: @location, content: '   ')
    caption.add_child(text_node)

    # Whitespace-only caption should be considered empty
    assert_equal true, caption.empty?
  end

  def test_to_text_simple
    caption = ReVIEW::AST::CaptionNode.new(location: @location)
    text_node = ReVIEW::AST::TextNode.new(location: @location, content: 'Simple caption')
    caption.add_child(text_node)

    assert_equal 'Simple caption', caption.to_text
  end

  def test_to_text_with_inline
    caption = ReVIEW::AST::CaptionNode.new(location: @location)
    caption.add_child(ReVIEW::AST::TextNode.new(location: @location, content: 'Caption with '))

    inline_node = ReVIEW::AST::InlineNode.new(location: @location, inline_type: :b)
    inline_node.add_child(ReVIEW::AST::TextNode.new(location: @location, content: 'bold text'))
    caption.add_child(inline_node)

    caption.add_child(ReVIEW::AST::TextNode.new(location: @location, content: ' content'))

    # Markup should be removed: "Caption with @<b>{bold text} content" -> "Caption with bold text content"
    assert_equal 'Caption with bold text content', caption.to_text
  end

  def test_to_text_with_nested_inline
    caption = ReVIEW::AST::CaptionNode.new(location: @location)
    caption.add_child(ReVIEW::AST::TextNode.new(location: @location, content: 'Text '))

    # Create nested inline: @<i>{italic @<b>{bold}}
    bold_text = ReVIEW::AST::TextNode.new(location: @location, content: 'bold')
    bold_inline = ReVIEW::AST::InlineNode.new(location: @location, inline_type: :b)
    bold_inline.add_child(bold_text)

    italic_text = ReVIEW::AST::TextNode.new(location: @location, content: 'italic ')
    italic_inline = ReVIEW::AST::InlineNode.new(location: @location, inline_type: :i)
    italic_inline.add_child(italic_text)
    italic_inline.add_child(bold_inline)
    caption.add_child(italic_inline)

    caption.add_child(ReVIEW::AST::TextNode.new(location: @location, content: ' more'))

    # Nested markup should be removed: "Text @<i>{italic @<b>{bold}} more" -> "Text italic bold more"
    assert_equal 'Text italic bold more', caption.to_text
  end

  def test_to_text_empty
    caption = ReVIEW::AST::CaptionNode.new(location: @location)
    assert_equal '', caption.to_text
  end
end
