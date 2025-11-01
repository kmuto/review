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
    @book = ReVIEW::Book::Base.new(config: @config)

    ReVIEW::I18n.setup('ja')

    @compiler = ReVIEW::AST::Compiler.new
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
    assert_match(/Column Title/, html_output)
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
    content = "={test-chapter} Test Chapter\n\nParagraph.\n"

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    chapter.generate_indexes
    @book.generate_indexes
    ast_root = @compiler.compile_to_ast(chapter)
    renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter)
    html_output = renderer.render(ast_root)

    # HtmlRenderer now uses fixed anchor IDs like HTMLBuilder
    assert_match(%r{<h1 id="test-chapter">.*</h1>}, html_output)
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
    item1 = ReVIEW::AST::ListItemNode.new(level: 1)
    item1.parent = list # Set parent for list type detection
    # Term goes to term_children
    term1 = ReVIEW::AST::TextNode.new(content: 'Alpha')
    item1.term_children << term1
    # Definition goes to children
    def1 = ReVIEW::AST::TextNode.new(content: 'RISC CPU made by DEC.')
    item1.add_child(def1)

    # Second definition item
    item2 = ReVIEW::AST::ListItemNode.new(level: 1)
    item2.parent = list # Set parent for list type detection
    # Term goes to term_children
    term2 = ReVIEW::AST::TextNode.new(content: 'POWER')
    item2.term_children << term2
    # Definition goes to children
    def2 = ReVIEW::AST::TextNode.new(content: 'RISC CPU made by IBM and Motorola.')
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

    item = ReVIEW::AST::ListItemNode.new(level: 1)
    item.parent = list # Set parent for list type detection
    # Term goes to term_children
    term = ReVIEW::AST::TextNode.new(content: 'Term Only')
    item.term_children << term
    # No definition (children is empty)

    list.add_child(item)

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(''))
    renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter)
    result = renderer.visit(list)

    expected = "<dl>\n" +
               '<dt>Term Only</dt><dd></dd>' +
               "\n</dl>\n"

    assert_equal expected, result
  end

  def test_tex_equation_without_id_mathjax
    # Test TexEquationNode without ID using MathJax
    @config['math_format'] = 'mathjax'
    @book.config = @config

    require 'review/ast/tex_equation_node'
    equation = ReVIEW::AST::TexEquationNode.new(
      location: nil,
      id: nil,
      latex_content: 'E = mc^2'
    )

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(''))
    renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter)
    result = renderer.visit(equation)

    # HTMLBuilder uses $$ for display mode
    expected = "<div class=\"equation\">\n$$E = mc^2$$\n</div>\n"

    assert_equal expected, result
  end

  def test_tex_equation_without_id_plain
    # Test TexEquationNode without ID using plain text
    @config['math_format'] = nil
    @book.config = @config

    require 'review/ast/tex_equation_node'
    equation = ReVIEW::AST::TexEquationNode.new(
      location: nil,
      id: nil,
      latex_content: 'E = mc^2'
    )

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(''))
    renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter)
    result = renderer.visit(equation)

    # Fallback format wraps in div.equation and pre tags
    expected = "<div class=\"equation\">\n<pre>E = mc^2\n</pre>\n</div>\n"

    assert_equal expected, result
  end

  def test_tex_equation_with_id_and_caption_mathjax
    # Test TexEquationNode with ID and caption using MathJax
    @config['math_format'] = 'mathjax'
    @book.config = @config

    content = <<~REVIEW
      = Chapter

      //texequation[eq1][Einstein's Mass-Energy Equivalence]{
      E = mc^2
      //}
    REVIEW

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    chapter.generate_indexes
    @book.generate_indexes
    ast_root = @compiler.compile_to_ast(chapter)
    renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter)
    html_output = renderer.render(ast_root)

    # Use caption-equation class like HTMLBuilder
    assert_match(/<div id="eq1" class="caption-equation">/, html_output)
    # Caption should use I18n.t('equation') and proper formatting
    assert_match(%r{<p class="caption">式1\.1: Einstein&#39;s Mass-Energy Equivalence</p>}, html_output)
    # MathJax uses $$ delimiters
    assert_match(/\$\$E = mc\^2\$\$/, html_output)
  end

  def test_tex_equation_with_id_only_mathjax
    # Test TexEquationNode with ID only (no caption) using MathJax
    @config['math_format'] = 'mathjax'
    @book.config = @config

    content = <<~REVIEW
      = Chapter

      //texequation[eq1]{
      \\int_{-\\infty}^{\\infty} e^{-x^2} dx = \\sqrt{\\pi}
      //}
    REVIEW

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    chapter.generate_indexes
    @book.generate_indexes
    ast_root = @compiler.compile_to_ast(chapter)
    renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter)
    html_output = renderer.render(ast_root)

    # Use caption-equation class like HTMLBuilder
    assert_match(/<div id="eq1" class="caption-equation">/, html_output)
    # Caption should show equation number only (with colon from format_number_header)
    assert_match(%r{<p class="caption">式1\.1:</p>}, html_output)
    # Check that equation content is present
    assert_match(/\\int_/, html_output)
  end

  def test_nest_ul
    content = <<~EOS
      = Chapter

       * UL1

      //beginchild

       1. UL1-OL1
       2. UL1-OL2

       * UL1-UL1
       * UL1-UL2

       : UL1-DL1
      \tUL1-DD1
       : UL1-DL2
      \tUL1-DD2

      //endchild

       * UL2

      //beginchild

      UL2-PARA

      //endchild
    EOS

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    chapter.generate_indexes
    @book.generate_indexes
    ast_root = @compiler.compile_to_ast(chapter)
    renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter)
    html_output = renderer.render(ast_root)

    # Verify that nested structure is present
    assert_match(/<li>UL1/, html_output)
    assert_match(/<li>UL2/, html_output)
    assert_match(/<li>UL1-OL1/, html_output)
    assert_match(/<li>UL1-UL1/, html_output)
    assert_match(/<dt>UL1-DL1/, html_output)
  end

  def test_nest_ol
    content = <<~EOS
      = Chapter

       1. OL1

      //beginchild

       1. OL1-OL1
       2. OL1-OL2

       * OL1-UL1
       * OL1-UL2

       : OL1-DL1
      \tOL1-DD1
       : OL1-DL2
      \tOL1-DD2

      //endchild

       2. OL2

      //beginchild

      OL2-PARA

      //endchild
    EOS

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    chapter.generate_indexes
    @book.generate_indexes
    ast_root = @compiler.compile_to_ast(chapter)
    renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter)
    html_output = renderer.render(ast_root)

    # Verify that nested structure is present
    assert_match(/<li>OL1/, html_output)
    assert_match(/<li>OL2/, html_output)
    assert_match(/<li>OL1-OL1/, html_output)
    assert_match(/<li>OL1-UL1/, html_output)
    assert_match(/<dt>OL1-DL1/, html_output)
  end

  def test_nest_dl
    content = <<~EOS
      = Chapter

       : DL1

      //beginchild

       1. DL1-OL1
       2. DL1-OL2

       * DL1-UL1
       * DL1-UL2

       : DL1-DL1
      \tDL1-DD1
       : DL1-DL2
      \tDL1-DD2

      //endchild

       : DL2
      \tDD2

      //beginchild

       * DD2-UL1
       * DD2-UL2

      DD2-PARA

      //endchild
    EOS

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    chapter.generate_indexes
    @book.generate_indexes
    ast_root = @compiler.compile_to_ast(chapter)
    renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter)
    html_output = renderer.render(ast_root)

    # Verify that nested structure is present
    assert_match(/<dt>DL1/, html_output)
    assert_match(/<dt>DL2/, html_output)
    assert_match(/<li>DL1-OL1/, html_output)
    assert_match(/<li>DL1-UL1/, html_output)
    assert_match(/<li>DD2-UL1/, html_output)
  end
end
