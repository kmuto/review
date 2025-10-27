# frozen_string_literal: true

require_relative '../test_helper'
require_relative '../book_test_helper'
require 'review/ast/compiler'
require 'review/ast/node'
require 'review/renderer/html_renderer'
require 'review/book'
require 'review/book/chapter'
require 'review/configure'
require 'review/i18n'

class TestHtmlRendererInlineElements < Test::Unit::TestCase
  include BookTestHelper

  def setup
    @config = ReVIEW::Configure.values
    @config['language'] = 'ja'
    @config['secnolevel'] = 2
    @book = ReVIEW::Book::Base.new(config: @config)

    ReVIEW::I18n.setup('ja')

    @compiler = ReVIEW::AST::Compiler.new
  end

  def render_inline(content)
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    chapter.generate_indexes
    @book.generate_indexes
    ast_root = @compiler.compile_to_ast(chapter)
    renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter)
    renderer.render(ast_root)
  end

  # Basic text formatting
  def test_inline_b
    content = "= Chapter\n\nThis is @<b>{bold} text.\n"
    output = render_inline(content)
    assert_match(%r{<b>bold</b>}, output)
  end

  def test_inline_strong
    content = "= Chapter\n\nThis is @<strong>{strong} text.\n"
    output = render_inline(content)
    assert_match(%r{<strong>strong</strong>}, output)
  end

  def test_inline_i
    content = "= Chapter\n\nThis is @<i>{italic} text.\n"
    output = render_inline(content)
    assert_match(%r{<i>italic</i>}, output)
  end

  def test_inline_em
    content = "= Chapter\n\nThis is @<em>{emphasized} text.\n"
    output = render_inline(content)
    assert_match(%r{<em>emphasized</em>}, output)
  end

  def test_inline_u
    content = "= Chapter\n\nThis is @<u>{underlined} text.\n"
    output = render_inline(content)
    assert_match(%r{<u>underlined</u>}, output)
  end

  def test_inline_del
    content = "= Chapter\n\nThis is @<del>{deleted} text.\n"
    output = render_inline(content)
    assert_match(%r{<del>deleted</del>}, output)
  end

  def test_inline_ins
    content = "= Chapter\n\nThis is @<ins>{inserted} text.\n"
    output = render_inline(content)
    assert_match(%r{<ins>inserted</ins>}, output)
  end

  # Code and monospace formatting
  def test_inline_code
    content = "= Chapter\n\nInline code: @<code>{var x = 10}\n"
    output = render_inline(content)
    assert_match(%r{<code class="inline-code tt">var x = 10</code>}, output)
  end

  def test_inline_tt
    content = "= Chapter\n\nMonospace: @<tt>{monospace}\n"
    output = render_inline(content)
    assert_match(%r{<code class="tt">monospace</code>}, output)
  end

  def test_inline_ttb
    content = "= Chapter\n\nBold monospace: @<ttb>{bold mono}\n"
    output = render_inline(content)
    assert_match(%r{<code class="tt"><b>bold mono</b></code>}, output)
  end

  def test_inline_tti
    content = "= Chapter\n\nItalic monospace: @<tti>{italic mono}\n"
    output = render_inline(content)
    assert_match(%r{<code class="tt"><i>italic mono</i></code>}, output)
  end

  def test_inline_kbd
    content = "= Chapter\n\nPress @<kbd>{Enter} key.\n"
    output = render_inline(content)
    assert_match(%r{<kbd>Enter</kbd>}, output)
  end

  def test_inline_samp
    content = "= Chapter\n\nOutput: @<samp>{sample output}\n"
    output = render_inline(content)
    assert_match(%r{<samp>sample output</samp>}, output)
  end

  def test_inline_var
    content = "= Chapter\n\nVariable: @<var>{variableName}\n"
    output = render_inline(content)
    assert_match(%r{<var>variableName</var>}, output)
  end

  # Superscript and subscript
  def test_inline_sup
    content = "= Chapter\n\nE = mc@<sup>{2}\n"
    output = render_inline(content)
    assert_match(%r{mc<sup>2</sup>}, output)
  end

  def test_inline_sub
    content = "= Chapter\n\nH@<sub>{2}O\n"
    output = render_inline(content)
    assert_match(%r{H<sub>2</sub>O}, output)
  end

  # Ruby annotation
  def test_inline_ruby
    content = "= Chapter\n\n@<ruby>{漢字, かんじ}\n"
    output = render_inline(content)
    # InlineElementRenderer outputs simple ruby without rp tags
    assert_match(%r{<ruby>漢字<rt>かんじ</rt></ruby>}, output)
  end

  # Special Japanese formatting
  def test_inline_bou
    content = "= Chapter\n\n@<bou>{傍点}\n"
    output = render_inline(content)
    assert_match(%r{<span class="bou">傍点</span>}, output)
  end

  def test_inline_ami
    content = "= Chapter\n\n@<ami>{網掛け}\n"
    output = render_inline(content)
    assert_match(%r{<span class="ami">網掛け</span>}, output)
  end

  def test_inline_tcy
    content = "= Chapter\n\n縦中横@<tcy>{10}文字\n"
    output = render_inline(content)
    assert_match(%r{<span class="tcy">10</span>}, output)
  end

  def test_inline_tcy_single_ascii
    content = "= Chapter\n\n@<tcy>{A}文字\n"
    output = render_inline(content)
    assert_match(%r{<span class="upright">A</span>}, output)
  end

  # Keywords and index
  def test_inline_kw
    content = "= Chapter\n\n@<kw>{キーワード, keyword}\n"
    output = render_inline(content)
    # Uses half-width parentheses and includes IDX comment
    assert_match(%r{<b class="kw">キーワード \(keyword\)</b><!-- IDX:キーワード -->}, output)
  end

  def test_inline_idx
    content = "= Chapter\n\n@<idx>{索引項目}\n"
    output = render_inline(content)
    # idx displays the text and outputs an IDX comment (no anchor tag)
    assert_match(/索引項目/, output)
    assert_match(/<!-- IDX:索引項目 -->/, output)
  end

  def test_inline_idx_hierarchical
    content = "= Chapter\n\n@<idx>{親項目<<>>子項目}\n"
    output = render_inline(content)
    # Display text includes the full hierarchical path with <<>>
    assert_match(/親項目&lt;&lt;&gt;&gt;子項目/, output)
    # IDX comment preserves the <<>> delimiter (not escaped in HTML comments)
    assert_match(/<!-- IDX:親項目<<>>子項目 -->/, output)
  end

  def test_inline_hidx
    content = "= Chapter\n\n@<hidx>{隠し索引}\n"
    output = render_inline(content)
    # hidx outputs only an IDX comment (no text, no anchor tag)
    assert_match(/<!-- IDX:隠し索引 -->/, output)
    # Text should not be displayed
    refute_match(/>隠し索引</, output)
  end

  def test_inline_hidx_hierarchical
    content = "= Chapter\n\n@<hidx>{索引<<>>項目}\n"
    output = render_inline(content)
    # hidx outputs only an IDX comment with <<>> delimiter (no text, no anchor tag)
    # Note: <<>> is not escaped in HTML comments
    assert_match(/<!-- IDX:索引<<>>項目 -->/, output)
    # Text should not be displayed
    refute_match(/>索引/, output)
    refute_match(/項目</, output)
  end

  # Links
  def test_inline_href
    content = "= Chapter\n\n@<href>{https://example.com, Example}\n"
    output = render_inline(content)
    assert_match(%r{<a href="https://example\.com" class="link">Example</a>}, output)
  end

  def test_inline_href_url_only
    content = "= Chapter\n\n@<href>{https://example.com}\n"
    output = render_inline(content)
    assert_match(%r{<a href="https://example\.com" class="link">https://example\.com</a>}, output)
  end

  def test_inline_href_internal_reference_with_label
    content = "= Chapter\n\n@<href>{#anchor,Jump to anchor}\n"
    output = render_inline(content)
    assert_match(%r{<a href="#anchor" class="link">Jump to anchor</a>}, output)
  end

  def test_inline_href_internal_reference_without_label
    content = "= Chapter\n\n@<href>{#anchor}\n"
    output = render_inline(content)
    assert_match(%r{<a href="#anchor" class="link">#anchor</a>}, output)
  end

  # Special characters
  def test_inline_br
    content = "= Chapter\n\nLine1@<br>{}Line2\n"
    output = render_inline(content)
    assert_match(%r{Line1<br />Line2}, output)
  end

  def test_inline_uchar
    content = "= Chapter\n\n@<uchar>{2764} is a heart.\n"
    output = render_inline(content)
    assert_match(/&#x2764;/, output)
  end

  # HTML semantic elements
  def test_inline_abbr
    content = "= Chapter\n\n@<abbr>{HTML}\n"
    output = render_inline(content)
    assert_match(%r{<abbr>HTML</abbr>}, output)
  end

  def test_inline_acronym
    content = "= Chapter\n\n@<acronym>{NATO}\n"
    output = render_inline(content)
    assert_match(%r{<acronym>NATO</acronym>}, output)
  end

  def test_inline_cite
    content = "= Chapter\n\n@<cite>{Book Title}\n"
    output = render_inline(content)
    assert_match(%r{<cite>Book Title</cite>}, output)
  end

  def test_inline_dfn
    content = "= Chapter\n\n@<dfn>{definition}\n"
    output = render_inline(content)
    assert_match(%r{<dfn>definition</dfn>}, output)
  end

  def test_inline_big
    content = "= Chapter\n\n@<big>{large text}\n"
    output = render_inline(content)
    assert_match(%r{<big>large text</big>}, output)
  end

  def test_inline_small
    content = "= Chapter\n\n@<small>{small text}\n"
    output = render_inline(content)
    assert_match(%r{<small>small text</small>}, output)
  end

  # Special formatting
  def test_inline_recipe
    content = "= Chapter\n\n@<recipe>{レシピ名}\n"
    output = render_inline(content)
    assert_match(%r{<span class="recipe">「レシピ名」</span>}, output)
  end

  def test_inline_balloon
    content = "= Chapter\n\n@<balloon>{吹き出し}\n"
    output = render_inline(content)
    assert_match(%r{<span class="balloon">吹き出し</span>}, output)
  end

  def test_inline_dtp
    content = "= Chapter\n\n@<dtp>{command}\n"
    output = render_inline(content)
    assert_match(/<\?dtp command \?>/, output)
  end

  # Math
  def test_inline_m
    content = "= Chapter\n\n@<m>{E = mc^2}\n"
    output = render_inline(content)
    # InlineElementRenderer uses class="equation" like HTMLBuilder
    assert_match(%r{<span class="equation">E = mc\^2</span>}, output)
  end

  # Comments (draft mode)
  def test_inline_comment_draft_mode
    @config['draft'] = true
    content = "= Chapter\n\nText @<comment>{draft comment} here.\n"
    output = render_inline(content)
    assert_match(%r{<span class="draft-comment">draft comment</span>}, output)
  end

  def test_inline_comment_non_draft_mode
    @config['draft'] = false
    content = "= Chapter\n\nText @<comment>{draft comment} here.\n"
    output = render_inline(content)
    assert_no_match(/draft-comment/, output)
    assert_no_match(/draft comment/, output)
  end

  # Cross-references (basic tests)
  def test_inline_list_reference
    content = <<~REVIEW
      = Chapter

      //list[sample][Sample]{
      code
      //}

      See @<list>{sample}.
    REVIEW
    output = render_inline(content)
    assert_match(/リスト1\.1/, output)
    # Reference text is rendered but not wrapped in span by InlineElementRenderer
    assert_match(/リスト1\.1/, output)
  end

  def test_inline_table_reference
    content = <<~REVIEW
      = Chapter

      //table[sample][Sample]{
      A	B
      -----
      1	2
      //}

      See @<table>{sample}.
    REVIEW
    output = render_inline(content)
    assert_match(/表1\.1/, output)
    # Reference text is rendered but not wrapped in span by InlineElementRenderer
    assert_match(/表1\.1/, output)
  end

  def test_inline_img_reference
    content = <<~REVIEW
      = Chapter

      //image[sample][Sample Image]{
      //}

      See @<img>{sample}.
    REVIEW
    output = render_inline(content)
    assert_match(/図1\.1/, output)
    # Reference text is rendered but not wrapped in span by InlineElementRenderer
    assert_match(/図1\.1/, output)
  end

  # Footnote reference
  def test_inline_fn
    content = <<~REVIEW
      = Chapter

      Text with footnote@<fn>{note1}.

      //footnote[note1][Footnote text here.]
    REVIEW
    output = render_inline(content)
    assert_match(/<a id="fnb-note1" href="#fn-note1"/, output)
    assert_match(/class="noteref"/, output)
  end

  # Headline reference
  def test_inline_hd
    content = <<~REVIEW
      = Chapter

      == Section Title

      See @<hd>{Section Title}.
    REVIEW
    output = render_inline(content)
    # Should contain section reference
    assert_match(/Section Title/, output)
  end

  # Section reference
  def test_inline_sec
    content = <<~REVIEW
      = Chapter

      == Section 1

      See @<sec>{Section 1}.
    REVIEW
    output = render_inline(content)
    assert_match(/1\.1/, output)
  end

  # Column reference
  def test_inline_column
    content = <<~REVIEW
      = Chapter

      ===[column] Column Title

      Column content.

      ===[/column]

      See @<column>{Column Title}.
    REVIEW
    output = render_inline(content)
    assert_match(/Column Title/, output)
  end

  # Chapter reference
  def test_inline_chap
    # Use mktmpbookdir to create a proper book with chapters
    mktmpbookdir('test.re' => "= Chapter Title\n\nSee @<chap>{test}.\n") do |_dir, book|
      chapter = book.chapters[0]
      chapter.generate_indexes
      book.generate_indexes
      ast_root = @compiler.compile_to_ast(chapter)
      renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter)
      output = renderer.render(ast_root)
      # Should contain chapter number
      assert_match(/第1章/, output)
    end
  end

  def test_inline_title
    # Use mktmpbookdir to create a proper book with chapters
    mktmpbookdir('test.re' => "= Chapter Title\n\nSee @<title>{test}.\n") do |_dir, book|
      chapter = book.chapters[0]
      chapter.generate_indexes
      book.generate_indexes
      ast_root = @compiler.compile_to_ast(chapter)
      renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter)
      output = renderer.render(ast_root)
      assert_match(/Chapter Title/, output)
    end
  end

  # Page reference (unsupported in HTML)
  def test_inline_pageref
    content = "= Chapter\n\nSee @<pageref>{test}.\n"
    output = render_inline(content)
    # Should just output the content without error
    assert_match(/test/, output)
  end

  # Icon images
  def test_inline_icon
    content = "= Chapter\n\n@<icon>{sample}\n"
    output = render_inline(content)
    # Should attempt to reference image or show missing image
    assert_match(/sample/, output)
  end

  # Escaping special characters
  def test_inline_escaping
    content = "= Chapter\n\n@<b>{text with <html> & \"quotes\"}\n"
    output = render_inline(content)
    # Content is escaped once by visit_text, then rendered as-is
    assert_match(%r{<b>text with &lt;html&gt; &amp; &quot;quotes&quot;</b>}, output)
  end

  # Raw inline content
  def test_inline_raw_html
    content = "= Chapter\n\nText @<raw>{|html|<span class=\"custom\">HTML</span>} here.\n"
    output = render_inline(content)
    assert_match(%r{<span class="custom">HTML</span>}, output)
  end

  def test_inline_raw_other_format
    content = "= Chapter\n\nText @<raw>{|latex|\\textbf{LaTeX}} here.\n"
    output = render_inline(content)
    # Should not output LaTeX content in HTML
    assert_no_match(/textbf/, output)
  end

  # Complex inline combinations
  def test_inline_nested_formatting
    content = "= Chapter\n\n@<b>{bold @<i>{and italic\\}}\n"
    output = render_inline(content)
    assert_match(%r{<b>bold <i>and italic</i></b>}, output)
  end

  def test_inline_code_with_special_chars
    content = "= Chapter\n\n@<code>{<tag> & \"value\"}\n"
    output = render_inline(content)
    # Content is escaped once by visit_text, then rendered as-is
    assert_match(%r{<code class="inline-code tt">&lt;tag&gt; &amp; &quot;value&quot;</code>}, output)
  end

  # Bibliography reference (requires bib file setup)
  def test_inline_bib_basic
    mktmpbookdir('bib.re' => '//bibpaper[ref1][Reference Title]{Author Name, Publisher, 2020}') do |_dir, book|
      chapter = ReVIEW::Book::Chapter.new(book, 1, 'test', 'test.re', StringIO.new("= Chapter\n\nReference @<bib>{ref1}.\n"))
      chapter.generate_indexes
      book.generate_indexes
      ast_root = @compiler.compile_to_ast(chapter)
      renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter)
      output = renderer.render(ast_root)
      # Should contain reference markup with the bibliography reference
      assert_match(/ref1/, output)
    end
  end

  # Equation reference
  def test_inline_eq_basic
    content = <<~REVIEW
       = Chapter
  
       //texequation[eq1]{
       E = mc^2
       //}
  
       See @<eq>{eq1}.
     REVIEW
    output = render_inline(content)
    # Should contain equation reference
    assert_match(/式1\.1/, output)
  end

  # Endnote reference
  def test_inline_endnote_basic
    content = <<~REVIEW
      = Chapter

      Text @<endnote>{note1}.

      //endnote[note1][Endnote content]
    REVIEW
    output = render_inline(content)
    # Should contain endnote reference markup
    assert_match(/note1/, output)
  end

  # Section title reference
  def test_inline_sectitle_basic
    content = <<~REVIEW
      = Chapter

      == Section Title

      See @<sectitle>{Section Title}.
    REVIEW
    output = render_inline(content)
    assert_match(/Section Title/, output)
  end
end
