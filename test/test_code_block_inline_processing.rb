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
      lines: lines,
      original_text: original_text
    )

    assert_equal original_text, code_block.original_text
    assert_equal lines, code_block.lines
    assert_equal original_text, code_block.raw_content
  end

  def test_code_block_node_processed_lines
    # Create inline AST structure manually for testing
    text_node = ReVIEW::AST::TextNode.new(location: @location, content: 'hello')
    inline_node = ReVIEW::AST::InlineNode.new(location: @location, inline_type: 'b')
    inline_node.add_child(text_node)

    paragraph = ReVIEW::AST::ParagraphNode.new(location: @location)
    paragraph.add_child(ReVIEW::AST::TextNode.new(location: @location, content: 'puts '))
    paragraph.add_child(inline_node)

    lines = ['puts @<b>{hello}']
    processed_lines = [paragraph]

    code_block = ReVIEW::AST::CodeBlockNode.new(
      location: @location,
      id: 'sample',
      caption: 'Test Code',
      lines: lines,
      processed_lines: processed_lines,
      original_text: lines.first
    )

    assert_equal processed_lines, code_block.processed_lines
    assert_equal 1, code_block.processed_lines.size
    assert_instance_of(ReVIEW::AST::ParagraphNode, code_block.processed_lines.first)
  end

  def test_get_lines_for_builder
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

  def test_get_lines_for_builder_without_processed_lines
    lines = ['puts @<b>{hello}']

    code_block = ReVIEW::AST::CodeBlockNode.new(
      location: @location,
      lines: lines,
      processed_lines: nil
    )

    # Both should return lines when processed_lines is nil
    result_no_inline = code_block.get_lines_for_builder(builder_needs_inline: false)
    assert_equal lines, result_no_inline

    result_inline = code_block.get_lines_for_builder(builder_needs_inline: true)
    assert_equal lines, result_inline
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
    italic_text2 = ReVIEW::AST::TextNode.new(location: @location, content: '')
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

  def test_original_text_fallback_in_raw_content
    # Test when original_text is set
    code_block1 = ReVIEW::AST::CodeBlockNode.new(
      original_text: 'original content',
      lines: ['line1', 'line2']
    )
    assert_equal 'original content', code_block1.raw_content

    # Test when original_text is nil but lines exist
    code_block2 = ReVIEW::AST::CodeBlockNode.new(
      original_text: nil,
      lines: ['line1', 'line2']
    )
    assert_equal "line1\nline2", code_block2.raw_content

    # Test when both are nil/empty
    code_block3 = ReVIEW::AST::CodeBlockNode.new(
      original_text: nil,
      lines: nil
    )
    assert_equal '', code_block3.raw_content
  end

  def test_serialize_properties_includes_original_text
    code_block = ReVIEW::AST::CodeBlockNode.new(
      location: @location,
      id: 'test',
      caption: 'Test Caption',
      lines: ['puts hello'],
      original_text: 'puts hello'
    )

    # Test that serialization works without errors
    hash = {}
    options = ReVIEW::AST::JSONSerializer::Options.new(jsonbuilder_mode: true)

    assert_nothing_raised do
      code_block.send(:serialize_properties, hash, options)
    end

    # Check that basic properties are included
    assert_equal 'test', hash[:id]
    # Caption is now serialized as array in jsonbuilder_mode
    assert_instance_of(Array, hash[:caption])
    assert_equal 1, hash[:caption].size
    assert_equal 'TextNode', hash[:caption][0][:type]
    assert_equal 'Test Caption', hash[:caption][0][:content]
    assert_equal ['puts hello'], hash[:lines]
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
