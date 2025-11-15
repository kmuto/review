# frozen_string_literal: true

require_relative '../test_helper'
require 'review/ast/compiler'
require 'review/book'

# Skip Markdown tests if Ruby < 3.1 (markly requires Ruby >= 3.1)
# Note: Some tests use Markdown format detection and compilation
if Gem::Version.new(RUBY_VERSION) < Gem::Version.new('3.1.0')
  # Define empty test class to avoid load errors
  class TestFormatAutoDetection < Test::Unit::TestCase
    def test_skipped
      omit('Markdown tests require Ruby >= 3.1')
    end
  end
  return
end

class TestFormatAutoDetection < Test::Unit::TestCase
  def setup
    @config = ReVIEW::Configure.values
    @book = ReVIEW::Book::Base.new('.', config: @config)
  end

  def test_markdown_file_detection
    # Test .md extension
    chapter_md = create_chapter('test.md', '# Markdown heading')
    compiler = ReVIEW::AST::Compiler.for_chapter(chapter_md)

    assert_instance_of(ReVIEW::AST::MarkdownCompiler, compiler)
  end

  def test_review_file_detection
    # Test .re extension (Re:VIEW format)
    chapter_re = create_chapter('test.re', '= Re:VIEW heading')
    compiler = ReVIEW::AST::Compiler.for_chapter(chapter_re)

    assert_instance_of(ReVIEW::AST::Compiler, compiler)
    assert_not_instance_of(ReVIEW::AST::MarkdownCompiler, compiler)
  end

  def test_unknown_extension_defaults_to_review
    # Test unknown extension defaults to Re:VIEW format
    chapter_unknown = create_chapter('test.txt', '= Some heading')
    compiler = ReVIEW::AST::Compiler.for_chapter(chapter_unknown)

    assert_instance_of(ReVIEW::AST::Compiler, compiler)
    assert_not_instance_of(ReVIEW::AST::MarkdownCompiler, compiler)
  end

  def test_no_extension_defaults_to_review
    # Test no extension defaults to Re:VIEW format
    chapter_no_ext = create_chapter('test', '= Some heading')
    compiler = ReVIEW::AST::Compiler.for_chapter(chapter_no_ext)

    assert_instance_of(ReVIEW::AST::Compiler, compiler)
    assert_not_instance_of(ReVIEW::AST::MarkdownCompiler, compiler)
  end

  def test_markdown_compilation_with_auto_detection
    # Test that Markdown file actually compiles to AST
    content = <<~MD
      # Main Title
      
      This is a paragraph with **bold** text.
      
      ## Subsection
      
      - List item 1
      - List item 2
    MD

    chapter = create_chapter('test.md', content)
    compiler = ReVIEW::AST::Compiler.for_chapter(chapter)
    ast = compiler.compile_to_ast(chapter)

    assert_not_nil(ast)
    assert_instance_of(ReVIEW::AST::DocumentNode, ast)
    assert(ast.children.size > 0)

    # Check that we get headline nodes
    headlines = ast.children.select { |child| child.is_a?(ReVIEW::AST::HeadlineNode) }
    assert_equal(2, headlines.size)
    assert_equal(1, headlines[0].level)
    assert_equal(2, headlines[1].level)
  end

  def test_review_compilation_with_auto_detection
    # Test that Re:VIEW file actually compiles to AST
    content = <<~RE
      = Main Title
      
      This is a paragraph with @<b>{bold} text.
      
      == Subsection
      
       * List item 1
       * List item 2
    RE

    chapter = create_chapter('test.re', content)
    compiler = ReVIEW::AST::Compiler.for_chapter(chapter)
    ast = compiler.compile_to_ast(chapter)

    assert_not_nil(ast)
    assert_instance_of(ReVIEW::AST::DocumentNode, ast)
    assert(ast.children.size > 0)

    # Check that we get headline nodes
    headlines = ast.children.select { |child| child.is_a?(ReVIEW::AST::HeadlineNode) }
    assert_equal(2, headlines.size)
    assert_equal(1, headlines[0].level)
    assert_equal(2, headlines[1].level)
  end

  private

  def create_chapter(filename, content)
    require 'stringio'
    ReVIEW::Book::Chapter.new(@book, 1, filename, filename, StringIO.new(content))
  end
end
