# frozen_string_literal: true

require_relative '../test_helper'
require 'review/ast/compiler'
require 'review/renderer/html_renderer'
require 'review/renderer/markdown_renderer'
require 'review/renderer/plaintext_renderer'
require 'review/renderer/idgxml_renderer'
require 'review/renderer/latex_renderer'
require 'review/book'
require 'review/book/chapter'
require 'review/configure'
require 'review/i18n'

class TestRendererCaptionMultiline < Test::Unit::TestCase
  def setup
    @config = ReVIEW::Configure.values
    @config['language'] = 'ja'
    @book = ReVIEW::Book::Base.new(config: @config)

    ReVIEW::I18n.setup('ja')

    @compiler = ReVIEW::AST::Compiler.new
  end

  def test_html_renderer_caption_with_br
    content = <<~REVIEW
      = Chapter

      //list[sample][First line@<br>{}Second line]{
      code here
      //}
    REVIEW

    html_output = render_with(ReVIEW::Renderer::HtmlRenderer, content)

    assert_match(%r{<p class="caption">リスト1\.1: First line<br />Second line</p>}, html_output)
  end

  def test_html_renderer_caption_multiline_text_with_join_lines_by_lang
    @config['join_lines_by_lang'] = true
    content = "= Chapter\n\nParagraph line1\nline2\n"

    html_output = render_with(ReVIEW::Renderer::HtmlRenderer, content)

    # Paragraph should have space between lines when join_lines_by_lang is enabled
    assert_match(%r{<p>Paragraph line1 line2</p>}, html_output)
  end

  def test_markdown_renderer_caption_with_br
    content = <<~REVIEW
      = Chapter

      //list[sample][First line@<br>{}Second line][ruby]{
      code here
      //}
    REVIEW

    md_output = render_with(ReVIEW::Renderer::MarkdownRenderer, content)

    # Markdown renderer should join lines with a single space (br becomes newline, then joined with space)
    assert_match(/First line Second line/, md_output)
  end

  def test_plaintext_renderer_caption_with_br
    content = <<~REVIEW
      = Chapter

      //list[sample][First line@<br>{}Second line]{
      code here
      //}
    REVIEW

    text_output = render_with(ReVIEW::Renderer::PlaintextRenderer, content)

    # Plaintext renderer should join lines without spaces
    assert_match(/First lineSecond line/, text_output)
  end

  def test_idgxml_renderer_caption_with_br
    content = <<~REVIEW
      = Chapter

      //list[sample][First line@<br>{}Second line]{
      code here
      //}
    REVIEW

    xml_output = render_with(ReVIEW::Renderer::IdgxmlRenderer, content)

    # IDGXML renderer currently generates br tag with newline in caption
    # This is because render_caption_inline is called but br generates actual newline
    # TODO: Investigate if this is the intended behavior or if caption should be on one line
    assert_match(/First line/, xml_output)
    assert_match(/Second line/, xml_output)
    # NOTE: Currently newline is preserved in caption
  end

  def test_idgxml_renderer_caption_multiline_text_with_join_lines_by_lang
    @config['join_lines_by_lang'] = true
    content = "= Chapter\n\nParagraph line1\nline2\n"

    xml_output = render_with(ReVIEW::Renderer::IdgxmlRenderer, content)

    # Paragraph should have space between lines when join_lines_by_lang is enabled
    assert_match(/Paragraph line1 line2/, xml_output)
  end

  def test_latex_renderer_caption_with_br
    content = <<~REVIEW
      = Chapter

      //list[sample][First line@<br>{}Second line]{
      code here
      //}
    REVIEW

    latex_output = render_with(ReVIEW::Renderer::LatexRenderer, content)

    # LaTeX renderer should preserve br as linebreak (\\ + newline)
    assert_match(/First line\\\\/, latex_output)
    assert_match(/Second line/, latex_output)
  end

  def test_table_caption_with_br
    content = <<~REVIEW
      = Chapter

      //table[sample][First line@<br>{}Second line]{
      Header1	Header2
      --------------------
      Cell1	Cell2
      //}
    REVIEW

    # Test HTML renderer - caption should have no literal newlines
    html_output = render_with(ReVIEW::Renderer::HtmlRenderer, content)
    assert_match(%r{First line<br />Second line}, html_output)
    refute_match(%r{<p class="caption">.*\n.*</p>}, html_output)

    # Test IDGXML renderer - currently preserves newlines
    xml_output = render_with(ReVIEW::Renderer::IdgxmlRenderer, content)
    assert_match(/First line/, xml_output)
    assert_match(/Second line/, xml_output)
  end

  def test_image_caption_with_br
    content = <<~REVIEW
      = Chapter

      //image[sample][First line@<br>{}Second line]{
      //}
    REVIEW

    # Test HTML renderer - caption should include br and have newlines removed
    html_output = render_with(ReVIEW::Renderer::HtmlRenderer, content)
    assert_match(%r{First line<br />Second line}, html_output)
    # The caption should not contain literal newlines (join_paragraph_lines removes them)
    refute_match(%r{<p class="caption">.*\n.*</p>}, html_output)
  end

  private

  # Helper to create chapter and compile to AST
  def compile_content(content)
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    chapter.generate_indexes
    @book.generate_indexes
    @compiler.compile_to_ast(chapter)
  end

  # Helper to render content with a specific renderer
  def render_with(renderer_class, content)
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    chapter.generate_indexes
    @book.generate_indexes
    ast_root = @compiler.compile_to_ast(chapter)
    renderer = renderer_class.new(chapter)
    renderer.render(ast_root)
  end
end
