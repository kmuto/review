# frozen_string_literal: true

require_relative '../test_helper'
require 'review/ast/compiler'
require 'review/ast/noindent_processor'
require 'review/book'
require 'review/book/chapter'

class TestNoIndentProcessor < Test::Unit::TestCase
  def setup
    @book = ReVIEW::Book::Base.new
    @config = ReVIEW::Configure.values
    @config['secnolevel'] = 2
    @config['language'] = 'ja'
    @book.config = @config

    @log_io = StringIO.new
    ReVIEW.logger = ReVIEW::Logger.new(@log_io)

    @chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test_chapter', 'test_chapter.re', StringIO.new)
    ReVIEW::I18n.setup(@config['language'])
  end

  def test_noindent_with_paragraph
    source = <<~EOS
      = Chapter Title

      //noindent

      This paragraph should have noindent.

      This paragraph should be normal.
    EOS

    @chapter.content = source

    # Build AST
    ast_compiler = ReVIEW::AST::Compiler.new
    ast_root = ast_compiler.compile_to_ast(@chapter)

    # Find the paragraph nodes
    paragraphs = find_paragraph_nodes(ast_root)

    # First paragraph should have noindent attribute
    assert_equal 2, paragraphs.length
    assert_true(paragraphs[0].attribute?(:noindent))
    assert_false(paragraphs[1].attribute?(:noindent))
  end

  def test_noindent_with_quote_block
    source = <<~EOS
      = Chapter Title

      //noindent

      //quote{
      This quote should have noindent.
      //}

      Normal paragraph.
    EOS

    @chapter.content = source

    # Build AST
    ast_compiler = ReVIEW::AST::Compiler.new
    ast_root = ast_compiler.compile_to_ast(@chapter)

    # Find the quote block
    quote_blocks = find_block_nodes(ast_root, 'quote')
    paragraphs = find_paragraph_nodes(ast_root)

    # Quote block should have noindent attribute
    assert_equal 1, quote_blocks.length
    assert_true(quote_blocks[0].attribute?(:noindent))

    # Paragraph should not have noindent attribute
    assert_equal 2, paragraphs.length
    assert_false(paragraphs[0].attribute?(:noindent))
  end

  def test_multiple_noindent_commands
    source = <<~EOS
      = Chapter Title

      //noindent

      First paragraph with noindent.

      //noindent

      Second paragraph with noindent.

      Normal paragraph.
    EOS

    @chapter.content = source

    # Build AST
    ast_compiler = ReVIEW::AST::Compiler.new
    ast_root = ast_compiler.compile_to_ast(@chapter)

    # Find the paragraph nodes
    paragraphs = find_paragraph_nodes(ast_root)

    # First two paragraphs should have noindent attribute
    assert_equal 3, paragraphs.length
    assert_true(paragraphs[0].attribute?(:noindent))
    assert_true(paragraphs[1].attribute?(:noindent))
    assert_false(paragraphs[2].attribute?(:noindent))
  end

  def test_noindent_blocks_are_removed
    source = <<~EOS
      = Chapter Title

      //noindent

      Paragraph with noindent.
    EOS

    @chapter.content = source

    # Build AST
    ast_compiler = ReVIEW::AST::Compiler.new
    ast_root = ast_compiler.compile_to_ast(@chapter)

    # Check that no noindent block nodes remain
    noindent_blocks = find_block_nodes(ast_root, 'noindent')
    assert_equal 0, noindent_blocks.length
  end

  private

  def find_paragraph_nodes(node)
    result = []
    if node.is_a?(ReVIEW::AST::ParagraphNode)
      result << node
    end

    if node.children
      node.children.each do |child|
        result.concat(find_paragraph_nodes(child))
      end
    end

    result
  end

  def find_block_nodes(node, block_type)
    result = []
    if node.is_a?(ReVIEW::AST::BlockNode) && node.block_type.to_s == block_type
      result << node
    end

    if node.children
      node.children.each do |child|
        result.concat(find_block_nodes(child, block_type))
      end
    end

    result
  end
end
