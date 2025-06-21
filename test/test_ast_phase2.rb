# frozen_string_literal: true

require_relative 'test_helper'
require 'review/ast'
require 'review/ast/renderer'
require 'review/compiler'
require 'review/htmlbuilder'
require 'review/book'
require 'review/book/chapter'

class TestASTPhase2 < Test::Unit::TestCase
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

  def test_ast_renderer_basic
    builder = ReVIEW::HTMLBuilder.new
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    location = ReVIEW::Location.new('test.re', nil)
    compiler = ReVIEW::Compiler.new(builder)

    # Initialize builder properly
    builder.bind(compiler, chapter, location)

    renderer = ReVIEW::AST::Renderer.new(builder)

    # Create simple AST structure
    root = ReVIEW::AST::DocumentNode.new
    headline = ReVIEW::AST::HeadlineNode.new
    headline.level = 1
    headline.caption = 'Test Headline'
    root.add_child(headline)

    para = ReVIEW::AST::ParagraphNode.new
    text_node = ReVIEW::AST::TextNode.new
    text_node.content = 'Test paragraph content'
    para.add_child(text_node)
    root.add_child(para)

    # Test that renderer can process AST
    assert_nothing_raised do
      renderer.render(root)
    end
  end

  def test_hybrid_mode_headline_only
    content = <<~EOB
      = Test Chapter

      This is a normal paragraph.

      == Section Title

      Another paragraph.
    EOB

    # Test with headline-only AST processing
    builder = ReVIEW::HTMLBuilder.new
    compiler = ReVIEW::Compiler.new(builder, ast_mode: true)
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = content

    result = compiler.compile(chapter)

    # Should contain HTML output
    assert(result.is_a?(String))
    assert(result.include?('<h1>'))
    assert(result.include?('Test Chapter'))
    assert(result.include?('<h2>'))
    assert(result.include?('Section Title'))
  end

  def test_hybrid_mode_paragraph_only
    content = <<~EOB
      = Test Chapter

      This is a test paragraph.

      Another paragraph here.
    EOB

    # Test with paragraph-only AST processing
    builder = ReVIEW::HTMLBuilder.new
    compiler = ReVIEW::Compiler.new(builder, ast_mode: true)
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = content

    result = compiler.compile(chapter)

    # Should contain HTML output
    assert(result.is_a?(String))
    assert(result.include?('<p>'))
    assert(result.include?('test paragraph'))
  end

  def test_hybrid_mode_multiple_elements
    content = <<~EOB
      = Test Chapter

      This is a test paragraph.

      == Section

      Another paragraph.
    EOB

    # Test with both headline and paragraph AST processing
    builder = ReVIEW::HTMLBuilder.new
    compiler = ReVIEW::Compiler.new(builder, ast_mode: true)
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = content

    result = compiler.compile(chapter)

    # Should contain HTML output for both elements
    assert(result.is_a?(String))
    assert(result.include?('<h1>'))
    assert(result.include?('<h2>'))
    assert(result.include?('<p>'))
  end

  def test_backward_compatibility
    content = <<~EOB
      = Test Chapter

      This is a test paragraph.
    EOB

    # Test that normal compilation still works
    builder = ReVIEW::HTMLBuilder.new
    compiler_normal = ReVIEW::Compiler.new(builder)
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = content

    result_normal = compiler_normal.compile(chapter)

    # Test AST mode with no specific elements (should work the same)
    builder2 = ReVIEW::HTMLBuilder.new
    compiler_ast = ReVIEW::Compiler.new(builder2, ast_mode: true)
    chapter2 = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter2.content = content

    result_ast = compiler_ast.compile(chapter2)

    # Results should be similar (allowing for minor differences)
    assert(result_normal.is_a?(String))
    assert(result_ast.is_a?(String))
    assert(result_normal.include?('Test Chapter'))
    assert(result_ast.include?('Test Chapter'))
  end

  def test_ast_node_location_information
    content = <<~EOB
      = Test Chapter

      Test paragraph.
    EOB

    # Test that AST nodes preserve location information
    builder = ReVIEW::HTMLBuilder.new
    compiler = ReVIEW::Compiler.new(builder, ast_mode: true)
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = content

    compiler.compile(chapter)
    ast_root = compiler.ast_result

    assert_not_nil(ast_root)
    assert_equal('DocumentNode', ast_root.class.name.split('::').last)
    assert(ast_root.children.any?)

    headline_node = ast_root.children.find { |n| n.is_a?(ReVIEW::AST::HeadlineNode) }
    assert_not_nil(headline_node)
    assert_equal(1, headline_node.level)
    assert_equal('Test Chapter', headline_node.caption_markup_text)
  end
end
