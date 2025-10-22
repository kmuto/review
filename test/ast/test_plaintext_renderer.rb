# frozen_string_literal: true

require_relative '../test_helper'
require 'review/ast/compiler'
require 'review/ast/node'
require 'review/renderer/plaintext_renderer'
require 'review/book'
require 'review/book/chapter'
require 'review/configure'
require 'review/i18n'

class TestPlaintextRenderer < Test::Unit::TestCase
  def setup
    @config = ReVIEW::Configure.values
    @config['language'] = 'ja'
    @config['secnolevel'] = 2
    @book = ReVIEW::Book::Base.new('.')
    @book.config = @config

    # Initialize I18n for proper list numbering
    ReVIEW::I18n.setup('ja')

    @compiler = ReVIEW::AST::Compiler.new
  end

  def test_headline_level1_rendering
    content = "= Test Chapter\n\nParagraph text.\n"

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    chapter.generate_indexes
    @book.generate_indexes
    ast_root = @compiler.compile_to_ast(chapter)
    renderer = ReVIEW::Renderer::PlaintextRenderer.new(chapter)
    plaintext_output = renderer.render(ast_root)

    assert_match(/第1章　Test Chapter/, plaintext_output)
    assert_match(/Paragraph text\./, plaintext_output)
  end

  def test_headline_level1_without_secno
    @config['secnolevel'] = 0
    content = "= Test Chapter\n\nParagraph text.\n"

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    chapter.generate_indexes
    @book.generate_indexes
    ast_root = @compiler.compile_to_ast(chapter)
    renderer = ReVIEW::Renderer::PlaintextRenderer.new(chapter)
    plaintext_output = renderer.render(ast_root)

    assert_match(/Test Chapter/, plaintext_output)
    assert_no_match(/第1章/, plaintext_output)
    assert_match(/Paragraph text\./, plaintext_output)
  end

  def test_headline_level2
    content = "= Chapter\n\n== Section\n\nParagraph.\n"

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    chapter.generate_indexes
    @book.generate_indexes
    ast_root = @compiler.compile_to_ast(chapter)
    renderer = ReVIEW::Renderer::PlaintextRenderer.new(chapter)
    plaintext_output = renderer.render(ast_root)

    assert_match(/Section/, plaintext_output)
  end

  def test_inline_elements
    content = "= Chapter\n\nThis is @<b>{bold} and @<i>{italic} text.\n"

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    chapter.generate_indexes
    @book.generate_indexes
    ast_root = @compiler.compile_to_ast(chapter)
    renderer = ReVIEW::Renderer::PlaintextRenderer.new(chapter)
    plaintext_output = renderer.render(ast_root)

    # Plain text renderer should output text without markup
    assert_match(/bold/, plaintext_output)
    assert_match(/italic/, plaintext_output)
    # Should not contain HTML tags
    assert_no_match(/<b>/, plaintext_output)
    assert_no_match(/<i>/, plaintext_output)
  end

  def test_code_block
    content = <<~REVIEW
      = Chapter

      //list[sample][Sample Code][ruby]{
      puts "Hello World"
      //}
    REVIEW

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    chapter.generate_indexes
    @book.generate_indexes
    ast_root = @compiler.compile_to_ast(chapter)
    renderer = ReVIEW::Renderer::PlaintextRenderer.new(chapter)
    plaintext_output = renderer.render(ast_root)

    assert_match(/リスト1\.1.*Sample Code/, plaintext_output)
    assert_match(/puts "Hello World"/, plaintext_output)
  end

  def test_table_rendering
    content = <<~REVIEW
      = Chapter

      //table[sample][Sample Table]{
      Header1	Header2
      Cell1	Cell2
      //}
    REVIEW

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    chapter.generate_indexes
    @book.generate_indexes
    ast_root = @compiler.compile_to_ast(chapter)
    renderer = ReVIEW::Renderer::PlaintextRenderer.new(chapter)
    plaintext_output = renderer.render(ast_root)

    assert_match(/表1\.1.*Sample Table/, plaintext_output)
    assert_match(/Header1\tHeader2/, plaintext_output)
    assert_match(/Cell1\tCell2/, plaintext_output)
  end

  def test_ul_rendering
    content = <<~REVIEW
      = Chapter

       * Item 1
       * Item 2
       * Item 3
    REVIEW

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    chapter.generate_indexes
    @book.generate_indexes
    ast_root = @compiler.compile_to_ast(chapter)
    renderer = ReVIEW::Renderer::PlaintextRenderer.new(chapter)
    plaintext_output = renderer.render(ast_root)

    assert_match(/Item 1/, plaintext_output)
    assert_match(/Item 2/, plaintext_output)
    assert_match(/Item 3/, plaintext_output)
  end

  def test_ol_rendering
    content = <<~REVIEW
      = Chapter

       1. First item
       2. Second item
       3. Third item
    REVIEW

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    chapter.generate_indexes
    @book.generate_indexes
    ast_root = @compiler.compile_to_ast(chapter)
    renderer = ReVIEW::Renderer::PlaintextRenderer.new(chapter)
    plaintext_output = renderer.render(ast_root)

    assert_match(/1　First item/, plaintext_output)
    assert_match(/2　Second item/, plaintext_output)
    assert_match(/3　Third item/, plaintext_output)
  end

  def test_image_rendering
    content = <<~REVIEW
      = Chapter

      //image[sampleimg][Sample Image]{
      //}
    REVIEW

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    chapter.generate_indexes
    @book.generate_indexes
    ast_root = @compiler.compile_to_ast(chapter)
    renderer = ReVIEW::Renderer::PlaintextRenderer.new(chapter)
    plaintext_output = renderer.render(ast_root)

    assert_match(/図1\.1.*Sample Image/, plaintext_output)
  end

  def test_inline_kw
    content = "= Chapter\n\n@<kw>{keyword, キーワード}\n"

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    chapter.generate_indexes
    @book.generate_indexes
    ast_root = @compiler.compile_to_ast(chapter)
    renderer = ReVIEW::Renderer::PlaintextRenderer.new(chapter)
    plaintext_output = renderer.render(ast_root)

    assert_match(/keyword（キーワード）/, plaintext_output)
  end

  def test_inline_href
    content = "= Chapter\n\n@<href>{http://example.com, Example Site}\n"

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    chapter.generate_indexes
    @book.generate_indexes
    ast_root = @compiler.compile_to_ast(chapter)
    renderer = ReVIEW::Renderer::PlaintextRenderer.new(chapter)
    plaintext_output = renderer.render(ast_root)

    assert_match(%r{Example Site（http://example\.com）}, plaintext_output)
  end

  def test_emlist_rendering
    content = <<~REVIEW
      = Chapter

      //emlist[Sample Code][ruby]{
      puts "Hello"
      //}
    REVIEW

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    chapter.generate_indexes
    @book.generate_indexes
    ast_root = @compiler.compile_to_ast(chapter)
    renderer = ReVIEW::Renderer::PlaintextRenderer.new(chapter)
    plaintext_output = renderer.render(ast_root)

    assert_match(/Sample Code/, plaintext_output)
    assert_match(/puts "Hello"/, plaintext_output)
  end

  def test_emlistnum_rendering
    content = <<~REVIEW
      = Chapter

      //emlistnum[Sample Code][ruby]{
      puts "Hello"
      puts "World"
      //}
    REVIEW

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    chapter.generate_indexes
    @book.generate_indexes
    ast_root = @compiler.compile_to_ast(chapter)
    renderer = ReVIEW::Renderer::PlaintextRenderer.new(chapter)
    plaintext_output = renderer.render(ast_root)

    assert_match(/Sample Code/, plaintext_output)
    assert_match(/ 1: puts "Hello"/, plaintext_output)
    assert_match(/ 2: puts "World"/, plaintext_output)
  end

  def test_quote_block
    content = <<~REVIEW
      = Chapter

      //quote{
      This is a quote.
      //}
    REVIEW

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    chapter.generate_indexes
    @book.generate_indexes
    ast_root = @compiler.compile_to_ast(chapter)
    renderer = ReVIEW::Renderer::PlaintextRenderer.new(chapter)
    plaintext_output = renderer.render(ast_root)

    assert_match(/This is a quote\./, plaintext_output)
  end

  def test_note_block
    content = <<~REVIEW
      = Chapter

      //note[Sample Note]{
      This is a note.
      //}
    REVIEW

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    chapter.generate_indexes
    @book.generate_indexes
    ast_root = @compiler.compile_to_ast(chapter)
    renderer = ReVIEW::Renderer::PlaintextRenderer.new(chapter)
    plaintext_output = renderer.render(ast_root)

    assert_match(/Sample Note/, plaintext_output)
    assert_match(/This is a note\./, plaintext_output)
  end
end
