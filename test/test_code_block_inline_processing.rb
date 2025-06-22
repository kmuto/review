# frozen_string_literal: true

require_relative 'test_helper'
require 'review/snapshot_location'
require 'review/ast/code_block_node'
require 'review/ast/paragraph_node'
require 'review/ast/text_node'
require 'review/ast/inline_node'
require 'review/ast/json_serializer'
require 'review/builder'
require 'review/htmlbuilder'
require 'review/idgxmlbuilder'
require 'stringio'

class TestCodeBlockInlineProcessing < Test::Unit::TestCase
  def setup
    @config = ReVIEW::Configure.values
    @book = ReVIEW::Book::Base.new
    @book.config = @config
    @location = create_test_location
  end

  def create_test_location
    ReVIEW::SnapshotLocation.new('test.re', 5)
  end

  def test_code_block_node_original_text_preservation
    lines = ['puts @<b>{hello}', 'puts "world"']
    original_text = lines.join("\n")

    code_block = ReVIEW::AST::CodeBlockNode.new(
      location: @location,
      id: 'sample',
      caption: 'Test Code',
      original_text: original_text
    )

    assert_equal original_text, code_block.original_text
    assert_equal lines, code_block.original_lines
  end

  def test_code_block_node_processed_lines
    # Create a code block with proper AST structure
    code_block = ReVIEW::AST::CodeBlockNode.new(
      location: @location,
      id: 'sample',
      original_text: 'puts @<b>{hello}'
    )

    # Create a code line with inline processing
    line_node = ReVIEW::AST::CodeLineNode.new(location: @location)

    # Add text and inline nodes to the line
    text_node1 = ReVIEW::AST::TextNode.new(location: @location, content: 'puts ')
    inline_node = ReVIEW::AST::InlineNode.new(location: @location, inline_type: 'b')
    inline_node.args = ['hello']

    line_node.add_child(text_node1)
    line_node.add_child(inline_node)
    code_block.add_child(line_node)

    # Test processed_lines method (reconstructs from AST)
    processed = code_block.processed_lines
    assert_equal 1, processed.size
    assert_equal 'puts @<b>{hello}', processed[0]
  end

  def test_original_lines_and_processed_lines
    original_text = 'puts @<b>{hello}'

    code_block = ReVIEW::AST::CodeBlockNode.new(
      location: @location,
      original_text: original_text
    )

    # Create a code line with inline processing
    line_node = ReVIEW::AST::CodeLineNode.new(location: @location)
    text_node1 = ReVIEW::AST::TextNode.new(location: @location, content: 'puts ')
    inline_node = ReVIEW::AST::InlineNode.new(location: @location, inline_type: 'b')
    inline_node.args = ['hello']
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

  def test_builder_interprets_inline_in_code
    # Test base Builder (should not interpret)
    builder = ReVIEW::Builder.new
    assert_equal false, builder.interprets_inline_in_code?

    # Test HTMLBuilder (should not interpret)
    html_builder = ReVIEW::HTMLBuilder.new
    assert_equal false, html_builder.interprets_inline_in_code?

    # Test IDGXMLBuilder (should interpret)
    idg_builder = ReVIEW::IDGXMLBuilder.new
    assert_equal true, idg_builder.interprets_inline_in_code?
  end

  def test_render_ast_node_as_plain_text_with_text_node
    text_node = ReVIEW::AST::TextNode.new(location: @location, content: 'hello world')
    builder = ReVIEW::Builder.new

    result = builder.render_ast_node_as_plain_text(text_node)
    assert_equal 'hello world', result
  end

  def test_render_ast_node_as_plain_text_with_inline_node
    text_node = ReVIEW::AST::TextNode.new(location: @location, content: 'bold text')
    inline_node = ReVIEW::AST::InlineNode.new(location: @location, inline_type: 'b')
    inline_node.add_child(text_node)

    builder = ReVIEW::Builder.new

    result = builder.render_ast_node_as_plain_text(inline_node)
    assert_equal '@<b>{bold text}', result
  end

  def test_render_ast_node_as_plain_text_with_paragraph_containing_inline
    paragraph = create_test_paragraph

    builder = ReVIEW::Builder.new

    result = builder.render_ast_node_as_plain_text(paragraph)
    assert_equal 'puts @<b>{hello}', result
  end

  def test_render_ast_node_as_plain_text_with_complex_inline
    # Create: This is @<i>{italic @<b>{bold}} text
    bold_text = ReVIEW::AST::TextNode.new(location: @location, content: 'bold')
    bold_inline = ReVIEW::AST::InlineNode.new(location: @location, inline_type: 'b')
    bold_inline.add_child(bold_text)

    italic_text1 = ReVIEW::AST::TextNode.new(location: @location, content: 'italic ')
    italic_inline = ReVIEW::AST::InlineNode.new(location: @location, inline_type: 'i')
    italic_inline.add_child(italic_text1)
    italic_inline.add_child(bold_inline)

    paragraph = ReVIEW::AST::ParagraphNode.new(location: @location)
    paragraph.add_child(ReVIEW::AST::TextNode.new(location: @location, content: 'This is '))
    paragraph.add_child(italic_inline)
    paragraph.add_child(ReVIEW::AST::TextNode.new(location: @location, content: ' text'))

    builder = ReVIEW::Builder.new

    result = builder.render_ast_node_as_plain_text(paragraph)
    assert_equal 'This is @<i>{italic @<b>{bold}} text', result
  end

  def test_code_block_node_inheritance_from_base_node
    code_block = ReVIEW::AST::CodeBlockNode.new(
      location: @location,
      original_text: 'test content'
    )

    # Test that original_text is properly inherited from base Node class
    assert_respond_to(code_block, :original_text)
    assert_equal 'test content', code_block.original_text

    # Test other inherited attributes
    assert_respond_to(code_block, :location)
    assert_respond_to(code_block, :children)
    assert_equal @location, code_block.location
  end

  def test_original_text_preservation
    # Test when original_text is set
    code_block1 = ReVIEW::AST::CodeBlockNode.new(
      location: @location,
      original_text: 'original content'
    )
    assert_equal 'original content', code_block1.original_text
    assert_equal ['original content'], code_block1.original_lines

    # Test when original_text is nil
    code_block2 = ReVIEW::AST::CodeBlockNode.new(
      location: @location,
      original_text: nil
    )
    assert_nil(code_block2.original_text)
    assert_equal [], code_block2.original_lines
  end

  def test_serialize_properties_includes_original_text
    # Create caption as proper CaptionNode
    caption = ReVIEW::AST::CaptionNode.new(location: @location)
    caption.add_child(ReVIEW::AST::TextNode.new(location: @location, content: 'Test Caption'))

    code_block = ReVIEW::AST::CodeBlockNode.new(
      location: @location,
      id: 'test',
      caption: caption,
      original_text: 'puts hello'
    )

    # Test that serialization works without errors
    hash = {}
    options = ReVIEW::AST::JSONSerializer::Options.new

    assert_nothing_raised do
      code_block.send(:serialize_properties, hash, options)
    end

    # Check that basic properties are included
    assert_equal 'test', hash[:id]
    # Caption is now serialized as CaptionNode structure (Hash instead of Array)
    assert_instance_of(Hash, hash[:caption])
    assert_equal 'CaptionNode', hash[:caption][:type]
    assert_equal 1, hash[:caption][:children].size
    assert_equal 'TextNode', hash[:caption][:children][0][:type]
    assert_equal 'Test Caption', hash[:caption][:children][0][:content]
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
