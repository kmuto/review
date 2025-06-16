# frozen_string_literal: true

require_relative 'test_helper'
require 'review/ast'
require 'review/ast/renderer'
require 'review/compiler'
require 'review/htmlbuilder'
require 'review/book'
require 'review/book/chapter'

class TestASTInline < Test::Unit::TestCase
  def setup
    @config = ReVIEW::Configure.values
    @config['secnolevel'] = 2
    @config['language'] = 'ja'
    @book = ReVIEW::Book::Base.new
    @book.config = @config
    @log_io = StringIO.new
    ReVIEW.logger = ReVIEW::Logger.new(@log_io)
    ReVIEW::I18n.setup(@config['language'])
  end

  def test_text_node_creation
    node = ReVIEW::AST::TextNode.new
    node.content = 'Hello world'

    hash = node.to_h
    assert_equal 'TextNode', hash[:type]
    assert_equal 'Hello world', hash[:content]
  end

  def test_inline_node_creation
    node = ReVIEW::AST::InlineNode.new
    node.inline_type = 'b'
    node.args = ['bold text']

    hash = node.to_h
    assert_equal 'InlineNode', hash[:type]
    assert_equal 'b', hash[:inline_type]
    assert_equal ['bold text'], hash[:args]
  end

  def test_simple_inline_parsing
    content = <<~EOB
      This is @<b>{bold text} in a paragraph.
    EOB

    builder = ReVIEW::HTMLBuilder.new
    compiler = ReVIEW::Compiler.new(builder, ast_mode: true)
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = content

    compiler.compile(chapter)
    ast_root = compiler.ast_result

    # Check that paragraph node exists and has children
    paragraph_node = ast_root.children.find { |n| n.is_a?(ReVIEW::AST::ParagraphNode) }
    assert_not_nil(paragraph_node)
    assert(paragraph_node.children.any?, 'Paragraph should have inline children')

    # Check for text and inline nodes
    text_nodes = paragraph_node.children.select { |n| n.is_a?(ReVIEW::AST::TextNode) }
    inline_nodes = paragraph_node.children.select { |n| n.is_a?(ReVIEW::AST::InlineNode) }

    assert(text_nodes.any?, 'Should have text nodes')
    assert(inline_nodes.any?, 'Should have inline nodes')

    # Check inline node details
    bold_node = inline_nodes.find { |n| n.inline_type == 'b' }
    assert_not_nil(bold_node, 'Should have bold inline node')
    assert_equal 'b', bold_node.inline_type
  end

  def test_multiple_inline_elements
    content = <<~EOB
      Text with @<b>{bold} and @<i>{italic} elements.
    EOB

    builder = ReVIEW::HTMLBuilder.new
    compiler = ReVIEW::Compiler.new(builder, ast_mode: true)
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = content

    compiler.compile(chapter)
    ast_root = compiler.ast_result

    paragraph_node = ast_root.children.find { |n| n.is_a?(ReVIEW::AST::ParagraphNode) }
    assert_not_nil(paragraph_node)

    # Check for both bold and italic inline nodes
    inline_nodes = paragraph_node.children.select { |n| n.is_a?(ReVIEW::AST::InlineNode) }
    assert_equal 2, inline_nodes.size

    bold_node = inline_nodes.find { |n| n.inline_type == 'b' }
    italic_node = inline_nodes.find { |n| n.inline_type == 'i' }

    assert_not_nil(bold_node, 'Should have bold inline node')
    assert_not_nil(italic_node, 'Should have italic inline node')
    assert_equal 'b', bold_node.inline_type
    assert_equal 'i', italic_node.inline_type
  end

  def test_inline_output_compatibility
    content = <<~EOB
      This is @<b>{bold} and @<code>{inline code} text.
    EOB

    # Test with AST mode
    builder_ast = ReVIEW::HTMLBuilder.new
    compiler_ast = ReVIEW::Compiler.new(builder_ast, ast_mode: true)
    chapter_ast = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter_ast.content = content
    result_ast = compiler_ast.compile(chapter_ast)

    # Test with traditional mode
    builder_trad = ReVIEW::HTMLBuilder.new
    compiler_trad = ReVIEW::Compiler.new(builder_trad)
    chapter_trad = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter_trad.content = content
    result_trad = compiler_trad.compile(chapter_trad)

    # Both should produce HTML output with inline elements
    assert(result_ast.include?('<b>'), 'AST mode should produce bold HTML')
    assert(result_ast.include?('<code'), 'AST mode should produce code HTML')
    assert(result_trad.include?('<b>'), 'Traditional mode should produce bold HTML')
    assert(result_trad.include?('<code'), 'Traditional mode should produce code HTML')
  end

  def test_mixed_content_parsing
    content = <<~EOB
      = Chapter Title

      Normal paragraph with @<b>{bold text}.

      Another paragraph with @<code>{code} and @<i>{italic}.
    EOB

    builder = ReVIEW::HTMLBuilder.new
    compiler = ReVIEW::Compiler.new(builder, ast_mode: true)
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = content

    compiler.compile(chapter)
    ast_root = compiler.ast_result

    # Check headline
    headline_node = ast_root.children.find { |n| n.is_a?(ReVIEW::AST::HeadlineNode) }
    assert_not_nil(headline_node)
    assert_equal 'Chapter Title', headline_node.caption

    # Check paragraphs with inline elements
    paragraph_nodes = ast_root.children.select { |n| n.is_a?(ReVIEW::AST::ParagraphNode) }
    assert_equal 2, paragraph_nodes.size

    # First paragraph should have bold inline
    first_para = paragraph_nodes[0]
    bold_node = first_para.children.find { |n| n.is_a?(ReVIEW::AST::InlineNode) && n.inline_type == 'b' }
    assert_not_nil(bold_node)

    # Second paragraph should have code and italic inlines
    second_para = paragraph_nodes[1]
    code_node = second_para.children.find { |n| n.is_a?(ReVIEW::AST::InlineNode) && n.inline_type == 'code' }
    italic_node = second_para.children.find { |n| n.is_a?(ReVIEW::AST::InlineNode) && n.inline_type == 'i' }
    assert_not_nil(code_node)
    assert_not_nil(italic_node)
  end
end
