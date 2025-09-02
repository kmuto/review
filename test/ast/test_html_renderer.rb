# frozen_string_literal: true

require_relative '../test_helper'
require 'review/ast/compiler'
require 'review/ast/node'
require 'review/renderer/html_renderer'
require 'review/book'
require 'review/book/chapter'
require 'review/configure'
require 'review/i18n'

class TestHtmlRenderer < Test::Unit::TestCase
  def setup
    @config = ReVIEW::Configure.values
    @config['language'] = 'ja'
    @book = ReVIEW::Book::Base.new('.')
    @book.config = @config

    # Initialize I18n for proper list numbering
    ReVIEW::I18n.setup('ja')

    @compiler = ReVIEW::AST::Compiler.new
    # NOTE: renderer will be created with chapter in each test
  end

  def test_headline_rendering
    content = "= Test Chapter\n\nParagraph text.\n"

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    chapter.generate_indexes
    @book.generate_indexes
    ast_root = @compiler.compile_to_ast(chapter)
    renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter)
    html_output = renderer.render(ast_root)

    assert_match(%r{<h1>.*Test Chapter</h1>}, html_output)
    assert_match(%r{<p>Paragraph text\.</p>}, html_output)
  end

  def test_inline_elements
    content = "= Chapter\n\nThis is @<b>{bold} and @<i>{italic} text.\n"

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    chapter.generate_indexes
    @book.generate_indexes
    ast_root = @compiler.compile_to_ast(chapter)
    renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter)
    html_output = renderer.render(ast_root)

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
    renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter)
    html_output = renderer.render(ast_root)

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
    renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter)
    html_output = renderer.render(ast_root)

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
    renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter)
    html_output = renderer.render(ast_root)

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
    renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter)
    html_output = renderer.render(ast_root)

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
    renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter)
    html_output = renderer.render(ast_root)

    assert_match(/&lt;html&gt; &amp; &quot;quotes&quot;/, html_output)
  end

  def test_id_normalization
    content = "= Test Chapter{#test-chapter}\n\nParagraph.\n"

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    chapter.generate_indexes
    @book.generate_indexes
    ast_root = @compiler.compile_to_ast(chapter)
    renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter)
    html_output = renderer.render(ast_root)

    # HtmlRenderer now uses fixed anchor IDs like HTMLBuilder
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
    renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter)
    html_output = renderer.render(ast_root)

    assert_match(%r{<a href="https://example\.com".*>Example Site</a>}, html_output)
  end

  def test_visit_embed_raw_basic
    # Test basic //raw command without builder specification
    embed = ReVIEW::AST::EmbedNode.new(
      embed_type: :raw,
      arg: 'Raw HTML content with <br> tag',
      target_builders: nil,
      content: 'Raw HTML content with <br> tag'
    )

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(''))
    renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter)
    result = renderer.visit(embed)
    expected = 'Raw HTML content with <br /> tag'

    assert_equal expected, result
  end

  def test_visit_embed_raw_html_targeted
    # Test //raw command targeted for HTML
    embed = ReVIEW::AST::EmbedNode.new(
      embed_type: :raw,
      arg: '|html|<div class="custom">HTML content</div>',
      target_builders: ['html'],
      content: '<div class="custom">HTML content</div>'
    )

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(''))
    renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter)
    result = renderer.visit(embed)
    expected = '<div class="custom">HTML content</div>'

    assert_equal expected, result
  end

  def test_visit_embed_raw_latex_targeted
    # Test //raw command targeted for LaTeX (should output nothing)
    embed = ReVIEW::AST::EmbedNode.new(
      embed_type: :raw,
      arg: '|latex|\\textbf{LaTeX content}',
      target_builders: ['latex'],
      content: '\\textbf{LaTeX content}'
    )

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(''))
    renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter)
    result = renderer.visit(embed)
    expected = ''

    assert_equal expected, result
  end

  def test_visit_embed_raw_multiple_builders
    # Test //raw command targeted for multiple builders including HTML
    embed = ReVIEW::AST::EmbedNode.new(
      embed_type: :raw,
      arg: '|html,latex|Content for both',
      target_builders: ['html', 'latex'],
      content: 'Content for both'
    )

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(''))
    renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter)
    result = renderer.visit(embed)
    expected = 'Content for both'

    assert_equal expected, result
  end

  def test_visit_embed_raw_inline
    # Test inline @<raw> command
    embed = ReVIEW::AST::EmbedNode.new(
      embed_type: :inline,
      arg: '|html|<span class="inline">HTML</span>',
      target_builders: ['html'],
      content: '<span class="inline">HTML</span>'
    )

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(''))
    renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter)
    result = renderer.visit(embed)
    expected = '<span class="inline">HTML</span>'

    assert_equal expected, result
  end

  def test_visit_embed_raw_newline_conversion
    # Test \\n to newline conversion
    embed = ReVIEW::AST::EmbedNode.new(
      embed_type: :raw,
      arg: 'Line 1\\nLine 2\\nLine 3',
      target_builders: nil,
      content: 'Line 1\\nLine 2\\nLine 3'
    )

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(''))
    renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter)
    result = renderer.visit(embed)
    expected = "Line 1\nLine 2\nLine 3"

    assert_equal expected, result
  end

  def test_visit_embed_raw_xhtml_compliance
    # Test XHTML compliance for self-closing tags
    embed = ReVIEW::AST::EmbedNode.new(
      embed_type: :raw,
      arg: '<hr><br><img src="test.png"><input type="text">',
      target_builders: nil,
      content: '<hr><br><img src="test.png"><input type="text">'
    )

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(''))
    renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter)
    result = renderer.visit(embed)
    expected = '<hr /><br /><img src="test.png" /><input type="text" />'

    assert_equal expected, result
  end

  def test_visit_list_definition
    # Test definition list
    list = ReVIEW::AST::ListNode.new(list_type: :dl)

    # First definition item
    item1 = ReVIEW::AST::ListItemNode.new(content: 'Alpha', level: 1)
    item1.parent = list # Set parent for list type detection
    term1 = ReVIEW::AST::TextNode.new(content: 'Alpha')
    def1 = ReVIEW::AST::TextNode.new(content: 'RISC CPU made by DEC.')
    item1.add_child(term1)
    item1.add_child(def1)

    # Second definition item
    item2 = ReVIEW::AST::ListItemNode.new(content: 'POWER', level: 1)
    item2.parent = list # Set parent for list type detection
    term2 = ReVIEW::AST::TextNode.new(content: 'POWER')
    def2 = ReVIEW::AST::TextNode.new(content: 'RISC CPU made by IBM and Motorola.')
    item2.add_child(term2)
    item2.add_child(def2)

    list.add_child(item1)
    list.add_child(item2)

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(''))
    renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter)
    result = renderer.visit(list)

    expected = "<dl>\n" +
               '<dt>Alpha</dt><dd>RISC CPU made by DEC.</dd>' +
               '<dt>POWER</dt><dd>RISC CPU made by IBM and Motorola.</dd>' +
               "\n</dl>\n"

    assert_equal expected, result
  end

  def test_visit_list_definition_single_child
    # Test definition list with term only (no definition)
    list = ReVIEW::AST::ListNode.new(list_type: :dl)

    item = ReVIEW::AST::ListItemNode.new(content: 'Term Only', level: 1)
    item.parent = list # Set parent for list type detection
    term = ReVIEW::AST::TextNode.new(content: 'Term Only')
    item.add_child(term)

    list.add_child(item)

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(''))
    renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter)
    result = renderer.visit(list)

    expected = "<dl>\n" +
               '<dt>Term Only</dt>' +
               "\n</dl>\n"

    assert_equal expected, result
  end
end
