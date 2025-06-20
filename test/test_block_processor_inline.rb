# frozen_string_literal: true

require_relative 'test_helper'
require 'ostruct'
require 'review/ast/code_block_node'
require 'review/ast/paragraph_node'
require 'review/ast/text_node'
require 'review/ast/inline_node'

class TestBlockProcessorInline < Test::Unit::TestCase
  def setup
    @location = OpenStruct.new(filename: 'test.re', lineno: 10)
  end

  def test_code_block_node_original_text_attribute
    # Test that CodeBlockNode has original_text attribute
    code_block = ReVIEW::AST::CodeBlockNode.new(
      location: @location,
      original_text: 'test content'
    )

    assert_respond_to code_block, :original_text
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

    assert_respond_to code_block, :processed_lines
    assert_equal processed_lines, code_block.processed_lines
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