# frozen_string_literal: true

require_relative 'test_helper'
require 'review/ast/compiler'
require 'review/ast/node'
require 'review/renderer/html_renderer'
require 'review/book'
require 'review/book/chapter'
require 'review/configure'

class TestHTMLRenderer < Test::Unit::TestCase
  def setup
    @config = ReVIEW::Configure.values
    @book = ReVIEW::Book::Base.new('.')
    @book.config = @config
    @compiler = ReVIEW::AST::Compiler.new(nil)
    @renderer = ReVIEW::Renderer::HTMLRenderer.new(
      config: @config,
      options: { book: @book }
    )
  end

  def test_headline_rendering
    content = "= Test Chapter\n\nParagraph text.\n"

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = @compiler.compile_to_ast(chapter)
    html_output = @renderer.render(ast_root)

    assert_match(%r{<h1>Test Chapter</h1>}, html_output)
    assert_match(%r{<p>Paragraph text\.</p>}, html_output)
  end

  def test_inline_elements
    content = "= Chapter\n\nThis is @<b>{bold} and @<i>{italic} text.\n"

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
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
    ast_root = @compiler.compile_to_ast(chapter)
    html_output = @renderer.render(ast_root)

    assert_match(/<div class="code"/, html_output)
    assert_match(%r{<div class="caption-code">Sample Code</div>}, html_output)
    assert_match(%r{<pre><code class="language-ruby">puts &quot;Hello World&quot;</code></pre>}, html_output)
  end

  def test_table_rendering
    content = <<~REVIEW
      = Chapter

      //table[sample][Sample Table]{
      Header1	Header2
      -----
      Cell1	Cell2
      //}
    REVIEW

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = @compiler.compile_to_ast(chapter)
    html_output = @renderer.render(ast_root)

    assert_match(/<div class="table">/, html_output)
    assert_match(%r{<div class="caption-table">Sample Table</div>}, html_output)
    assert_match(/<thead>/, html_output)
    assert_match(/<tbody>/, html_output)
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
    ast_root = @compiler.compile_to_ast(chapter)
    html_output = @renderer.render(ast_root)

    assert_match(/<div class="note">/, html_output)
    assert_match(%r{<div class="note-header">Sample Note</div>}, html_output)
    # Note content should be present (may not have <p> tags in minicolumn)
    assert_match(/This is a note\./, html_output)
  end

  def test_text_escaping
    content = "= Chapter\n\nText with <html> & \"quotes\".\n"

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = @compiler.compile_to_ast(chapter)
    html_output = @renderer.render(ast_root)

    assert_match(/&lt;html&gt; &amp; &quot;quotes&quot;/, html_output)
  end

  def test_id_normalization
    content = "= Test Chapter{#test-chapter}\n\nParagraph.\n"

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = @compiler.compile_to_ast(chapter)
    html_output = @renderer.render(ast_root)

    assert_match(/<h1 id="test-chapter">/, html_output)
  end

  def test_href_inline
    content = "= Chapter\n\nVisit @<href>{https://example.com, Example Site}.\n"

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = @compiler.compile_to_ast(chapter)
    html_output = @renderer.render(ast_root)

    assert_match(%r{<a href="https://example\.com">Example Site</a>}, html_output)
  end
end
