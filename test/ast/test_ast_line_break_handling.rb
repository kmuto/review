# frozen_string_literal: true

require_relative '../test_helper'
require 'review'
require 'review/ast'
require 'review/ast/compiler'
require 'review/configure'
require 'review/book'
require 'review/i18n'
require 'stringio'

class TestASTLineBreakHandling < Test::Unit::TestCase
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

  def create_chapter(content)
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = content
    chapter
  end

  def test_single_line_paragraph
    content = 'これは一行のテストです。'
    compiler = ReVIEW::AST::Compiler.new
    ast_root = compiler.compile_to_ast(create_chapter(content))

    # Should have one paragraph with one text node
    assert_equal 1, ast_root.children.length
    paragraph = ast_root.children.first
    assert_instance_of(ReVIEW::AST::ParagraphNode, paragraph)

    assert_equal 1, paragraph.children.length
    text_node = paragraph.children.first
    assert_instance_of(ReVIEW::AST::TextNode, text_node)
    assert_equal 'これは一行のテストです。', text_node.content
  end

  def test_single_paragraph_with_line_break
    # This is the main test case - single paragraph should remain single paragraph
    content = "この文章は改行が含まれています。\nしかし同じ段落のはずです。"
    compiler = ReVIEW::AST::Compiler.new
    ast_root = compiler.compile_to_ast(create_chapter(content))

    # Should have one paragraph with one text node
    assert_equal 1, ast_root.children.length, 'Should have exactly one paragraph'
    paragraph = ast_root.children.first
    assert_instance_of(ReVIEW::AST::ParagraphNode, paragraph)

    assert_equal 1, paragraph.children.length, 'Paragraph should have exactly one text node'
    text_node = paragraph.children.first
    assert_instance_of(ReVIEW::AST::TextNode, text_node)

    # The key assertion: should preserve single line break, not double
    expected_content = "この文章は改行が含まれています。\nしかし同じ段落のはずです。"
    assert_equal expected_content, text_node.content,
                 'Single line break should be preserved as single line break'
  end

  def test_two_paragraphs_with_empty_line
    # This should correctly create two separate paragraphs
    content = "最初の段落です。\n\n次の段落です。"
    compiler = ReVIEW::AST::Compiler.new
    ast_root = compiler.compile_to_ast(create_chapter(content))

    # Should have two paragraphs
    assert_equal 2, ast_root.children.length, 'Should have exactly two paragraphs'

    # First paragraph
    paragraph1 = ast_root.children[0]
    assert_instance_of(ReVIEW::AST::ParagraphNode, paragraph1)
    assert_equal 1, paragraph1.children.length
    text1 = paragraph1.children.first
    assert_instance_of(ReVIEW::AST::TextNode, text1)
    assert_equal '最初の段落です。', text1.content

    # Second paragraph
    paragraph2 = ast_root.children[1]
    assert_instance_of(ReVIEW::AST::ParagraphNode, paragraph2)
    assert_equal 1, paragraph2.children.length
    text2 = paragraph2.children.first
    assert_instance_of(ReVIEW::AST::TextNode, text2)
    assert_equal '次の段落です。', text2.content
  end

  def test_multiple_single_line_breaks
    # Multiple single line breaks should be preserved as single line breaks
    content = "行1\n行2\n行3"
    compiler = ReVIEW::AST::Compiler.new
    ast_root = compiler.compile_to_ast(create_chapter(content))

    # Should have one paragraph
    assert_equal 1, ast_root.children.length, 'Should have exactly one paragraph'
    paragraph = ast_root.children.first
    assert_instance_of(ReVIEW::AST::ParagraphNode, paragraph)

    assert_equal 1, paragraph.children.length
    text_node = paragraph.children.first
    assert_instance_of(ReVIEW::AST::TextNode, text_node)

    # Should preserve single line breaks
    expected_content = "行1\n行2\n行3"
    assert_equal expected_content, text_node.content,
                 'Multiple single line breaks should be preserved'
  end

  def test_mixed_single_and_double_line_breaks
    # Test complex case with both single and double line breaks
    content = "段落1の行1\n段落1の行2\n\n段落2の行1\n段落2の行2"
    compiler = ReVIEW::AST::Compiler.new
    ast_root = compiler.compile_to_ast(create_chapter(content))

    # Should have two paragraphs
    assert_equal 2, ast_root.children.length, 'Should have exactly two paragraphs'

    # First paragraph should preserve single line breaks
    paragraph1 = ast_root.children[0]
    text1 = paragraph1.children.first
    assert_equal "段落1の行1\n段落1の行2", text1.content

    # Second paragraph should preserve single line breaks
    paragraph2 = ast_root.children[1]
    text2 = paragraph2.children.first
    assert_equal "段落2の行1\n段落2の行2", text2.content
  end
end
