# frozen_string_literal: true

require_relative '../test_helper'
require 'review/ast'
require 'review/ast/compiler'
require 'review/configure'
require 'review/book'
require 'review/book/chapter'

class TestASTInline < Test::Unit::TestCase
  def setup
    @config = ReVIEW::Configure.values
    @config['secnolevel'] = 2
    @config['language'] = 'ja'
    @book = ReVIEW::Book::Base.new(config: @config)
    @log_io = StringIO.new
    ReVIEW.logger = ReVIEW::Logger.new(@log_io)
    ReVIEW::I18n.setup(@config['language'])
  end

  def test_text_node_creation
    node = ReVIEW::AST::TextNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), content: 'Hello world')

    hash = node.to_h
    assert_equal 'TextNode', hash[:type]
    assert_equal 'Hello world', hash[:content]
  end

  def test_inline_node_creation
    node = ReVIEW::AST::InlineNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0),
                                       inline_type: :b,
                                       args: ['bold text'])

    hash = node.to_h
    assert_equal 'InlineNode', hash[:type]
    assert_equal :b, hash[:inline_type]
    assert_equal ['bold text'], hash[:args]
  end

  def test_simple_inline_parsing
    content = <<~EOB
      This is @<b>{bold text} in a paragraph.
    EOB

    ast_root = compile_to_ast(content)
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
    bold_node = inline_nodes.find { |n| n.inline_type == :b }
    assert_not_nil(bold_node, 'Should have bold inline node')
    assert_equal :b, bold_node.inline_type
  end

  def test_multiple_inline_elements
    content = <<~EOB
      Text with @<b>{bold} and @<i>{italic} elements.
    EOB

    ast_root = compile_to_ast(content)
    paragraph_node = ast_root.children.find { |n| n.is_a?(ReVIEW::AST::ParagraphNode) }
    assert_not_nil(paragraph_node)

    # Check for both bold and italic inline nodes
    inline_nodes = paragraph_node.children.select { |n| n.is_a?(ReVIEW::AST::InlineNode) }
    assert_equal 2, inline_nodes.size

    bold_node = inline_nodes.find { |n| n.inline_type == :b }
    italic_node = inline_nodes.find { |n| n.inline_type == :i }

    assert_not_nil(bold_node, 'Should have bold inline node')
    assert_not_nil(italic_node, 'Should have italic inline node')
    assert_equal :b, bold_node.inline_type
    assert_equal :i, italic_node.inline_type
  end

  def test_inline_output_compatibility
    content = <<~EOB
      This is @<b>{bold} and @<code>{inline code} text.
    EOB

    ast_root = compile_to_ast(content)

    paragraph_node = ast_root.children.find { |n| n.is_a?(ReVIEW::AST::ParagraphNode) }
    assert_not_nil(paragraph_node, 'Should have paragraph node')

    # Check inline elements in AST
    inline_nodes = paragraph_node.children.select { |n| n.is_a?(ReVIEW::AST::InlineNode) }
    assert_equal(2, inline_nodes.size, 'Should have two inline elements')

    bold_node = inline_nodes.find { |n| n.inline_type == :b }
    code_node = inline_nodes.find { |n| n.inline_type == :code }

    assert_not_nil(bold_node, 'Should have bold inline node')
    assert_not_nil(code_node, 'Should have code inline node')
    assert_equal(['bold'], bold_node.args)
    assert_equal(['inline code'], code_node.args)
  end

  def test_mixed_content_parsing
    content = <<~EOB
      = Chapter Title

      Normal paragraph with @<b>{bold text}.

      Another paragraph with @<code>{code} and @<i>{italic}.
    EOB

    ast_root = compile_to_ast(content)
    # Check headline
    headline_node = ast_root.children.find { |n| n.is_a?(ReVIEW::AST::HeadlineNode) }
    assert_not_nil(headline_node)
    assert_equal 'Chapter Title', headline_node.caption_markup_text

    # Check paragraphs with inline elements
    paragraph_nodes = ast_root.children.select { |n| n.is_a?(ReVIEW::AST::ParagraphNode) }
    assert_equal 2, paragraph_nodes.size

    # First paragraph should have bold inline
    first_para = paragraph_nodes[0]
    bold_node = first_para.children.find { |n| n.is_a?(ReVIEW::AST::InlineNode) && n.inline_type == :b }
    assert_not_nil(bold_node)

    # Second paragraph should have code and italic inlines
    second_para = paragraph_nodes[1]
    code_node = second_para.children.find { |n| n.is_a?(ReVIEW::AST::InlineNode) && n.inline_type == :code }
    italic_node = second_para.children.find { |n| n.is_a?(ReVIEW::AST::InlineNode) && n.inline_type == :i }
    assert_not_nil(code_node)
    assert_not_nil(italic_node)
  end

  private

  def compile_to_ast(content)
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = content

    ast_compiler = ReVIEW::AST::Compiler.new
    ast_compiler.compile_to_ast(chapter)
  end
end
