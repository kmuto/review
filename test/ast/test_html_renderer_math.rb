# frozen_string_literal: true

require_relative '../test_helper'
require 'review/ast/compiler'
require 'review/ast/node'
require 'review/renderer/html_renderer'
require 'review/book'
require 'review/book/chapter'
require 'review/configure'
require 'review/i18n'
require 'tmpdir'

class TestHtmlRendererMath < Test::Unit::TestCase
  def setup
    @config = ReVIEW::Configure.values
    @config['language'] = 'ja'
    @book = ReVIEW::Book::Base.new(config: @config)

    ReVIEW::I18n.setup('ja')

    @compiler = ReVIEW::AST::Compiler.new
  end

  # Test for texequation block with mathjax format
  def test_texequation_mathjax
    @config['math_format'] = 'mathjax'

    content = <<~REVIEW
      = Chapter

      //texequation{
      x = \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}
      //}
    REVIEW

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    chapter.generate_indexes
    @book.generate_indexes
    ast_root = @compiler.compile_to_ast(chapter)
    renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter)
    html_output = renderer.render_body(ast_root)

    assert_match(/<div class="equation">/, html_output)
    assert_match(/\$\$.*\\frac.*\$\$/, html_output)
    assert_match(/x = \\frac\{-b \\pm \\sqrt\{b\^2 - 4ac\}\}\{2a\}/, html_output)
  end

  # Test for texequation block with ID and caption using mathjax
  def test_texequation_with_id_caption_mathjax
    @config['math_format'] = 'mathjax'

    content = <<~REVIEW
      = Chapter

      //texequation[quadratic][二次方程式の解の公式]{
      x = \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}
      //}
    REVIEW

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    chapter.generate_indexes
    @book.generate_indexes
    ast_root = @compiler.compile_to_ast(chapter)
    renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter)
    html_output = renderer.render_body(ast_root)

    assert_match(/<div id="quadratic" class="caption-equation">/, html_output)
    assert_match(%r{<p class="caption">式1\.1: 二次方程式の解の公式</p>}, html_output)
    assert_match(/<div class="equation">/, html_output)
    assert_match(/\$\$.*\\frac.*\$\$/, html_output)
  end

  # Test for mathjax escaping of special characters
  def test_texequation_mathjax_escaping
    @config['math_format'] = 'mathjax'

    content = <<~REVIEW
      = Chapter

      //texequation{
      a < b & c > d
      //}
    REVIEW

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    chapter.generate_indexes
    @book.generate_indexes
    ast_root = @compiler.compile_to_ast(chapter)
    renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter)
    html_output = renderer.render_body(ast_root)

    # Check that <, >, & are properly escaped for mathjax
    assert_match(/\\lt\{\}/, html_output)
    assert_match(/\\gt\{\}/, html_output)
    assert_match(/&amp;/, html_output)
    # Verify that the equation content itself has escaped characters
    assert_match(/\$\$a \\lt\{\} b &amp; c \\gt\{\} d\$\$/, html_output)
  end

  # Test for inline math with mathjax format
  def test_inline_m_mathjax
    @config['math_format'] = 'mathjax'

    content = <<~REVIEW
      = Chapter

      Einstein's equation is @<m>{E = mc^2}.
    REVIEW

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    chapter.generate_indexes
    @book.generate_indexes
    ast_root = @compiler.compile_to_ast(chapter)
    renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter)
    html_output = renderer.render_body(ast_root)

    assert_match(%r{<span class="equation">\\\\?\( E = mc\^2 \\\\?\)</span>}, html_output)
  end

  # Test for inline math with mathjax escaping
  def test_inline_m_mathjax_escaping
    @config['math_format'] = 'mathjax'

    content = <<~REVIEW
      = Chapter

      Test equation @<m>{a < b & c > d}.
    REVIEW

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    chapter.generate_indexes
    @book.generate_indexes
    ast_root = @compiler.compile_to_ast(chapter)
    renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter)
    html_output = renderer.render_body(ast_root)

    assert_match(/\\lt\{\}/, html_output)
    assert_match(/\\gt\{\}/, html_output)
    assert_match(/&amp;/, html_output)
  end

  # Test for texequation with mathml format (requires math_ml gem)
  def test_texequation_mathml
    begin
      require 'math_ml'
      require 'math_ml/symbol/character_reference'
    rescue LoadError
      omit('math_ml gem not installed')
    end

    @config['math_format'] = 'mathml'

    content = <<~REVIEW
      = Chapter

      //texequation{
      E = mc^2
      //}
    REVIEW

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    chapter.generate_indexes
    @book.generate_indexes
    ast_root = @compiler.compile_to_ast(chapter)
    renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter)
    html_output = renderer.render_body(ast_root)

    assert_match(/<div class="equation">/, html_output)
    # MathML output contains <math> tags
    assert_match(/<math/, html_output)
  end

  # Test for inline math with mathml format
  def test_inline_m_mathml
    begin
      require 'math_ml'
      require 'math_ml/symbol/character_reference'
    rescue LoadError
      omit('math_ml gem not installed')
    end

    @config['math_format'] = 'mathml'

    content = <<~REVIEW
      = Chapter

      Einstein's equation is @<m>{E = mc^2}.
    REVIEW

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    chapter.generate_indexes
    @book.generate_indexes
    ast_root = @compiler.compile_to_ast(chapter)
    renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter)
    html_output = renderer.render_body(ast_root)

    assert_match(/<span class="equation">/, html_output)
    assert_match(/<math/, html_output)
  end

  # Test for texequation with imgmath format (requires latex/dvipng)
  def test_texequation_imgmath
    # Check if latex and dvipng are available
    unless system('which latex > /dev/null 2>&1') && system('which dvipng > /dev/null 2>&1')
      omit('latex or dvipng not installed')
    end

    Dir.mktmpdir do |tmpdir|
      @config['math_format'] = 'imgmath'
      @config['imagedir'] = tmpdir
      @config['imgmath_options'] = {
        'fontsize' => 12,
        'lineheight' => 14.4,
        'format' => 'png'
      }

      content = <<~REVIEW
        = Chapter

        //texequation{
        E = mc^2
        //}
      REVIEW

      chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
      chapter.generate_indexes
      @book.generate_indexes
      ast_root = @compiler.compile_to_ast(chapter)
      renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter)
      html_output = renderer.render_body(ast_root)

      assert_match(/<div class="equation">/, html_output)
      # Should contain img tag with math image
      assert_match(%r{<img src=".*_review_math/_gen_.*\.png"}, html_output)
      assert_match(/alt="E = mc\^2"/, html_output)
    end
  end

  # Test for inline math with imgmath format
  def test_inline_m_imgmath
    unless system('which latex > /dev/null 2>&1') && system('which dvipng > /dev/null 2>&1')
      omit('latex or dvipng not installed')
    end

    Dir.mktmpdir do |tmpdir|
      @config['math_format'] = 'imgmath'
      @config['imagedir'] = tmpdir
      @config['imgmath_options'] = {
        'fontsize' => 12,
        'lineheight' => 14.4,
        'format' => 'png'
      }

      content = <<~REVIEW
        = Chapter

        Einstein's equation is @<m>{E = mc^2}.
      REVIEW

      chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
      chapter.generate_indexes
      @book.generate_indexes
      ast_root = @compiler.compile_to_ast(chapter)
      renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter)
      html_output = renderer.render_body(ast_root)

      assert_match(/<span class="equation">/, html_output)
      assert_match(%r{<img src=".*_review_math/_gen_.*\.png"}, html_output)
    end
  end

  # Test for texequation with fallback (no math_format set)
  def test_texequation_fallback
    @config['math_format'] = nil

    content = <<~REVIEW
      = Chapter

      //texequation{
      E = mc^2
      //}
    REVIEW

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    chapter.generate_indexes
    @book.generate_indexes
    ast_root = @compiler.compile_to_ast(chapter)
    renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter)
    html_output = renderer.render_body(ast_root)

    assert_match(/<div class="equation">/, html_output)
    # Should fall back to <pre> tag
    assert_match(/<pre>E = mc\^2/, html_output)
  end

  # Test for inline math with fallback
  def test_inline_m_fallback
    @config['math_format'] = nil

    content = <<~REVIEW
      = Chapter

      Einstein's equation is @<m>{E = mc^2}.
    REVIEW

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    chapter.generate_indexes
    @book.generate_indexes
    ast_root = @compiler.compile_to_ast(chapter)
    renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter)
    html_output = renderer.render_body(ast_root)

    assert_match(%r{<span class="equation">E = mc\^2</span>}, html_output)
  end

  # Test for caption positioning (top/bottom)
  def test_texequation_caption_top
    @config['math_format'] = 'mathjax'
    @config['caption_position'] = { 'equation' => 'top' }

    content = <<~REVIEW
      = Chapter

      //texequation[einstein][アインシュタインの式]{
      E = mc^2
      //}
    REVIEW

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    chapter.generate_indexes
    @book.generate_indexes
    ast_root = @compiler.compile_to_ast(chapter)
    renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter)
    html_output = renderer.render_body(ast_root)

    # Caption should appear before equation div
    assert_match(%r{<p class="caption">.*アインシュタインの式</p>\s*<div class="equation">}m, html_output)
  end

  # Test for caption positioning (bottom)
  def test_texequation_caption_bottom
    @config['math_format'] = 'mathjax'
    @config['caption_position'] = { 'equation' => 'bottom' }

    content = <<~REVIEW
      = Chapter

      //texequation[einstein][アインシュタインの式]{
      E = mc^2
      //}
    REVIEW

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    chapter.generate_indexes
    @book.generate_indexes
    ast_root = @compiler.compile_to_ast(chapter)
    renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter)
    html_output = renderer.render_body(ast_root)

    # Caption should appear after equation div
    assert_match(%r{</div>\s*<p class="caption">.*アインシュタインの式</p>}m, html_output)
  end

  # Test for equation reference (@<eq>)
  def test_equation_reference
    @config['math_format'] = 'mathjax'

    content = <<~REVIEW
      = Chapter

      //texequation[einstein][アインシュタインの式]{
      E = mc^2
      //}

      See @<eq>{einstein} for details.
    REVIEW

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    chapter.generate_indexes
    @book.generate_indexes
    ast_root = @compiler.compile_to_ast(chapter)
    renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter)
    html_output = renderer.render_body(ast_root)

    # Check equation reference link (with chapterlink enabled, it includes file path)
    assert_match(%r{<span class="eqref"><a href=".*#einstein">式1\.1</a></span>}, html_output)
  end
end
