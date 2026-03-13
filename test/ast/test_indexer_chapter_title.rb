# frozen_string_literal: true

require_relative '../test_helper'
require 'review/ast/indexer'
require 'review/ast/markdown_compiler'
require 'review/book'
require 'review/book/chapter'
require 'review/configure'
require 'stringio'

return unless Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('3.1.0')

# Tests for Indexer#extract_and_set_chapter_title functionality
# This feature extracts chapter titles from Markdown files
class TestIndexerChapterTitle < Test::Unit::TestCase
  def setup
    @config = ReVIEW::Configure.values
    @config['chapter_no'] = 1
    @book = ReVIEW::Book::Base.new(config: @config)
    @compiler = ReVIEW::AST::MarkdownCompiler.new
    ReVIEW::I18n.setup(@config['language'])
  end

  def create_chapter(content, basename = 'test.md')
    ReVIEW::Book::Chapter.new(@book, 1, 'test', basename, StringIO.new(content))
  end

  # Test basic chapter title extraction from first level-1 headline
  def test_extract_chapter_title_from_markdown
    markdown = <<~MD
      # Chapter Title

      This is the content.
    MD

    chapter = create_chapter(markdown)
    ast = @compiler.compile_to_ast(chapter, reference_resolution: false)

    indexer = ReVIEW::AST::Indexer.new(chapter)
    indexer.build_indexes(ast)

    assert_equal 'Chapter Title', chapter.title, 'Chapter title should be extracted from first level-1 headline'
  end

  # Test that existing title is not overwritten
  def test_does_not_overwrite_existing_title
    markdown = <<~MD
      # Markdown Title

      Content here.
    MD

    chapter = create_chapter(markdown)
    # Simulate chapter with existing title (like from Re:VIEW format)
    chapter.instance_variable_set(:@title, 'Existing Title')

    ast = @compiler.compile_to_ast(chapter, reference_resolution: false)

    indexer = ReVIEW::AST::Indexer.new(chapter)
    indexer.build_indexes(ast)

    assert_equal 'Existing Title', chapter.title, 'Existing title should not be overwritten'
  end

  # Test with multiple level-1 headlines (should use first one)
  def test_uses_first_level_1_headline
    markdown = <<~MD
      # First Title

      Content for first section.

      # Second Title

      This should be ignored.
    MD

    chapter = create_chapter(markdown)
    ast = @compiler.compile_to_ast(chapter, reference_resolution: false)

    indexer = ReVIEW::AST::Indexer.new(chapter)
    indexer.build_indexes(ast)

    assert_equal 'First Title', chapter.title, 'Should use first level-1 headline only'
  end

  # Test with nested inline elements in title
  def test_extracts_text_from_inline_elements
    markdown = <<~MD
      # Chapter with **bold** and *italic* text

      Content here.
    MD

    chapter = create_chapter(markdown)
    ast = @compiler.compile_to_ast(chapter, reference_resolution: false)

    indexer = ReVIEW::AST::Indexer.new(chapter)
    indexer.build_indexes(ast)

    # Inline elements should be included as plain text
    assert_equal 'Chapter with bold and italic text', chapter.title,
                 'Should extract plain text from inline elements'
  end

  # Test with level-2 headline only (no level-1)
  def test_no_level_1_headline
    markdown = <<~MD
      ## Section Title

      Content without chapter title.
    MD

    chapter = create_chapter(markdown)
    ast = @compiler.compile_to_ast(chapter, reference_resolution: false)

    indexer = ReVIEW::AST::Indexer.new(chapter)
    indexer.build_indexes(ast)

    # Chapter title should remain empty
    assert_true(chapter.title.nil? || chapter.title.empty?,
                'Chapter title should remain empty when no level-1 headline exists')
  end

  # Test with empty document
  def test_empty_document
    markdown = ''

    chapter = create_chapter(markdown)
    ast = @compiler.compile_to_ast(chapter, reference_resolution: false)

    indexer = ReVIEW::AST::Indexer.new(chapter)
    indexer.build_indexes(ast)

    assert_true(chapter.title.nil? || chapter.title.empty?,
                'Chapter title should remain empty for empty document')
  end

  # Test with complex nested inline elements
  def test_complex_nested_inline_elements
    markdown = <<~MD
      # Title with `code` and [link](url)

      Content.
    MD

    chapter = create_chapter(markdown)
    ast = @compiler.compile_to_ast(chapter, reference_resolution: false)

    indexer = ReVIEW::AST::Indexer.new(chapter)
    indexer.build_indexes(ast)

    # Should extract all text content
    assert_include(chapter.title, 'Title with',
                   'Should extract text from complex inline elements')
    assert_include(chapter.title, 'code',
                   'Should extract code content')
    assert_include(chapter.title, 'link',
                   'Should extract link text')
  end

  # Test with only level-1 headline and no content
  def test_only_headline_no_content
    markdown = "# Standalone Title\n"

    chapter = create_chapter(markdown)
    ast = @compiler.compile_to_ast(chapter, reference_resolution: false)

    indexer = ReVIEW::AST::Indexer.new(chapter)
    indexer.build_indexes(ast)

    assert_equal 'Standalone Title', chapter.title,
                 'Should extract title even when it is the only content'
  end

  # Test with Japanese characters
  def test_japanese_characters
    markdown = <<~MD
      # 第1章　はじめに

      日本語の内容です。
    MD

    chapter = create_chapter(markdown)
    ast = @compiler.compile_to_ast(chapter, reference_resolution: false)

    indexer = ReVIEW::AST::Indexer.new(chapter)
    indexer.build_indexes(ast)

    assert_equal '第1章　はじめに', chapter.title,
                 'Should correctly extract Japanese characters'
  end

  # Test with whitespace-only headline
  def test_whitespace_only_headline
    markdown = <<~MD
      #

      Content.
    MD

    chapter = create_chapter(markdown)
    ast = @compiler.compile_to_ast(chapter, reference_resolution: false)

    indexer = ReVIEW::AST::Indexer.new(chapter)
    indexer.build_indexes(ast)

    # Empty or whitespace-only titles should not be set
    assert_true(chapter.title.nil? || chapter.title.empty?,
                'Whitespace-only headline should not set title')
  end

  # Test title extraction with Re:VIEW inline notation in caption
  def test_with_review_inline_notation
    markdown = <<~MD
      # Chapter @<b>{Bold Title}

      Content with references.
    MD

    chapter = create_chapter(markdown)
    ast = @compiler.compile_to_ast(chapter, reference_resolution: false)

    indexer = ReVIEW::AST::Indexer.new(chapter)
    indexer.build_indexes(ast)

    # The title should include the bold text
    assert_include(chapter.title, 'Chapter',
                   'Should extract text before inline notation')
    assert_include(chapter.title, 'Bold Title',
                   'Should extract text from inline notation')
  end
end
