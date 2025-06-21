# frozen_string_literal: true

require_relative 'test_helper'
require 'review/ast'
require 'review/compiler'
require 'review/htmlbuilder'
require 'review/book'
require 'review/book/chapter'

class TestASTEmbed < Test::Unit::TestCase
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

  def test_embed_node_creation
    node = ReVIEW::AST::EmbedNode.new
    node.embed_type = :block
    node.lines = ['content line 1', 'content line 2']
    node.arg = 'html'

    hash = node.to_h
    assert_equal 'EmbedNode', hash[:type]
    assert_equal :block, hash[:embed_type]
    assert_equal ['content line 1', 'content line 2'], hash[:lines]
    assert_equal 'html', hash[:arg]
  end

  def test_embed_block_ast_processing
    content = <<~EOB
      = Chapter Title

      Normal paragraph before embed.

      //embed[html]{
      <div class="special">
      HTML content here
      </div>
      //}

      Paragraph after embed.
    EOB

    builder = ReVIEW::HTMLBuilder.new
    compiler = ReVIEW::Compiler.new(builder, ast_mode: true)
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = content

    compiler.compile(chapter)
    ast_root = compiler.ast_result

    # Check that embed node exists
    embed_node = ast_root.children.find { |n| n.is_a?(ReVIEW::AST::EmbedNode) }
    assert_not_nil(embed_node, 'Should have embed node')
    assert_equal :block, embed_node.embed_type
    assert_equal 'html', embed_node.arg
    assert_equal ['<div class="special">', 'HTML content here', '</div>'], embed_node.lines
  end

  def test_embed_block_without_arg
    content = <<~EOB
      //embed{
      Raw content
      No builder filter
      //}
    EOB

    builder = ReVIEW::HTMLBuilder.new
    compiler = ReVIEW::Compiler.new(builder, ast_mode: true)
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = content

    compiler.compile(chapter)
    ast_root = compiler.ast_result

    embed_node = ast_root.children.find { |n| n.is_a?(ReVIEW::AST::EmbedNode) }
    assert_not_nil(embed_node)
    assert_equal :block, embed_node.embed_type
    assert_nil(embed_node.arg)
    assert_equal ['Raw content', 'No builder filter'], embed_node.lines
  end

  def test_inline_embed_ast_processing
    content = <<~EOB
      This paragraph has @<embed>{inline content} in it.
    EOB

    builder = ReVIEW::HTMLBuilder.new
    compiler = ReVIEW::Compiler.new(builder, ast_mode: true)
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = content

    compiler.compile(chapter)
    ast_root = compiler.ast_result

    paragraph_node = ast_root.children.find { |n| n.is_a?(ReVIEW::AST::ParagraphNode) }
    assert_not_nil(paragraph_node)

    # Find embed node within paragraph
    embed_node = paragraph_node.children.find { |n| n.is_a?(ReVIEW::AST::EmbedNode) }
    assert_not_nil(embed_node, 'Should have inline embed node')
    assert_equal :inline, embed_node.embed_type
    assert_equal 'inline content', embed_node.arg
    assert_equal ['inline content'], embed_node.lines
  end

  def test_inline_embed_with_builder_filter
    content = <<~EOB
      Text with @<embed>{|html|<strong>HTML only</strong>} content.
    EOB

    builder = ReVIEW::HTMLBuilder.new
    compiler = ReVIEW::Compiler.new(builder, ast_mode: true)
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = content

    compiler.compile(chapter)
    ast_root = compiler.ast_result

    paragraph_node = ast_root.children.find { |n| n.is_a?(ReVIEW::AST::ParagraphNode) }
    embed_node = paragraph_node.children.find { |n| n.is_a?(ReVIEW::AST::EmbedNode) }

    assert_not_nil(embed_node)
    assert_equal :inline, embed_node.embed_type
    assert_equal '|html|<strong>HTML only</strong>', embed_node.arg
  end

  def test_embed_output_compatibility
    content = <<~EOB
      Normal text @<embed>{inline embed} more text.

      //embed[html]{
      <div>Block embed content</div>
      //}
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

    # Both should produce similar output
    assert(result_ast.include?('inline embed'), 'AST mode should process inline embed')
    assert(result_ast.include?('<div>Block embed content</div>'), 'AST mode should process block embed')
    assert(result_trad.include?('inline embed'), 'Traditional mode should process inline embed')
    assert(result_trad.include?('<div>Block embed content</div>'), 'Traditional mode should process block embed')
  end

  def test_mixed_content_with_embed
    content = <<~EOB
      = Chapter with Embeds

      This paragraph has @<b>{bold} and @<embed>{inline embed} elements.

      //embed[html]{
      <div class="example">
      <p>Some HTML content</p>
      </div>
      //}

      Another paragraph after the embed block.
    EOB

    builder = ReVIEW::HTMLBuilder.new
    compiler = ReVIEW::Compiler.new(builder, ast_mode: true)
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = content

    compiler.compile(chapter)
    ast_root = compiler.ast_result

    # Check all components exist
    headline_node = ast_root.children.find { |n| n.is_a?(ReVIEW::AST::HeadlineNode) }
    paragraph_nodes = ast_root.children.select { |n| n.is_a?(ReVIEW::AST::ParagraphNode) }
    embed_node = ast_root.children.find { |n| n.is_a?(ReVIEW::AST::EmbedNode) }

    assert_not_nil(headline_node)
    assert_equal 2, paragraph_nodes.size
    assert_not_nil(embed_node)
    assert_equal :block, embed_node.embed_type

    # Check inline elements in first paragraph
    first_para = paragraph_nodes[0]
    bold_node = first_para.children.find { |n| n.is_a?(ReVIEW::AST::InlineNode) && n.inline_type == 'b' }
    inline_embed_node = first_para.children.find { |n| n.is_a?(ReVIEW::AST::EmbedNode) && n.embed_type == :inline }

    assert_not_nil(bold_node)
    assert_not_nil(inline_embed_node)
  end
end
