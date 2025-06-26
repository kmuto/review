# frozen_string_literal: true

require_relative 'test_helper'
require 'review/ast/compiler'
require 'review/ast/node'
require 'review/renderer/html_renderer'
require 'review/book'
require 'review/book/chapter'
require 'review/configure'
require 'review/i18n'

class TestHTMLRenderer < Test::Unit::TestCase
  def setup
    @config = ReVIEW::Configure.values
    @config['language'] = 'ja'
    @book = ReVIEW::Book::Base.new('.')
    @book.config = @config

    # Initialize I18n for proper list numbering
    ReVIEW::I18n.setup('ja')

    @compiler = ReVIEW::AST::Compiler.new
    @renderer = ReVIEW::Renderer::HTMLRenderer.new(
      config: @config,
      options: { book: @book }
    )
  end

  def test_headline_rendering
    content = "= Test Chapter\n\nParagraph text.\n"

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    chapter.generate_indexes
    @book.generate_indexes
    ast_root = @compiler.compile_to_ast(chapter)
    html_output = @renderer.render(ast_root)

    assert_match(%r{<h1>.*Test Chapter</h1>}, html_output)
    assert_match(%r{<p>Paragraph text\.</p>}, html_output)
  end

  def test_inline_elements
    content = "= Chapter\n\nThis is @<b>{bold} and @<i>{italic} text.\n"

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    chapter.generate_indexes
    @book.generate_indexes
    ast_root = @compiler.compile_to_ast(chapter)
    html_output = @renderer.render(ast_root)

    assert_match(%r{<b>bold</b>}, html_output)
    assert_match(%r{<i>italic</i>}, html_output)
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
    html_output = @renderer.render(ast_root)

    assert_match(/<div id="sample" class="caption-code">/, html_output)
    assert_match(%r{<p class="caption">リスト1\.1: Sample Code</p>}, html_output)
    assert_match(%r{<pre class="list.*">puts &quot;Hello World&quot;\n</pre>}, html_output)
  end

  def test_table_rendering
    content = <<~REVIEW
      = Chapter

      //table[sample][Sample Table]{
      Header1	Header2
      --------------------
      Cell1	Cell2
      //}
    REVIEW

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    chapter.generate_indexes
    @book.generate_indexes
    ast_root = @compiler.compile_to_ast(chapter)
    html_output = @renderer.render(ast_root)

    assert_match(/<div id="sample" class="table">/, html_output)
    assert_match(%r{<p class="caption">表1\.1: Sample Table</p>}, html_output)
    # No thead/tbody sections like HTMLBuilder
    assert_no_match(/<thead>/, html_output)
    assert_no_match(/<tbody>/, html_output)
    # Since ---- is only 5 chars, it's not a separator, so it appears as body content
    assert_match(%r{<th>Header1</th>}, html_output)
    assert_match(%r{<td>Cell1</td>}, html_output)
  end

  def test_column_rendering
    content = <<~REVIEW
      = Chapter

      ===[column] Column Title

      Column content here.

      ===[/column]
    REVIEW

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    chapter.generate_indexes
    @book.generate_indexes
    ast_root = @compiler.compile_to_ast(chapter)
    html_output = @renderer.render(ast_root)

    assert_match(/<div class="column">/, html_output)
    assert_match(%r{<div class="column-header">Column Title</div>}, html_output)
    assert_match(%r{<p>Column content here\.</p>}, html_output)
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
    html_output = @renderer.render(ast_root)

    assert_match(/<div class="note">/, html_output)
    assert_match(%r{<p class="caption">Sample Note</p>}, html_output)
    # Note content should be wrapped in paragraph tags like HTMLBuilder
    assert_match(%r{<p>This is a note\.</p>}, html_output)
  end

  def test_text_escaping
    content = "= Chapter\n\nText with <html> & \"quotes\".\n"

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    chapter.generate_indexes
    @book.generate_indexes
    ast_root = @compiler.compile_to_ast(chapter)
    html_output = @renderer.render(ast_root)

    assert_match(/&lt;html&gt; &amp; &quot;quotes&quot;/, html_output)
  end

  def test_id_normalization
    content = "= Test Chapter{#test-chapter}\n\nParagraph.\n"

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    chapter.generate_indexes
    @book.generate_indexes
    ast_root = @compiler.compile_to_ast(chapter)
    html_output = @renderer.render(ast_root)

    # HTMLRenderer now uses fixed anchor IDs like HTMLBuilder
    assert_match(%r{<h1>.*</h1>}, html_output)
    # Chapter title should be present
    assert_match(/Test Chapter/, html_output)
  end

  def test_href_inline
    content = "= Chapter\n\nVisit @<href>{https://example.com, Example Site}.\n"

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    chapter.generate_indexes
    @book.generate_indexes
    ast_root = @compiler.compile_to_ast(chapter)
    html_output = @renderer.render(ast_root)

    assert_match(%r{<a href="https://example\.com".*>Example Site</a>}, html_output)
  end
end
