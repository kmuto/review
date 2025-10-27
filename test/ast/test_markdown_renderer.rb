# frozen_string_literal: true

require_relative '../test_helper'
require 'review/ast'
require 'review/ast/compiler'
require 'review/renderer/markdown_renderer'
require 'review/markdownbuilder'
require 'review/configure'
require 'review/book'
require 'review/book/chapter'

class TestMarkdownRenderer < Test::Unit::TestCase
  def setup
    @config = ReVIEW::Configure.values
    @config['secnolevel'] = 2
    @config['language'] = 'ja'
    @config['disable_reference_resolution'] = true
    @book = ReVIEW::Book::Base.new(config: @config)
    @log_io = StringIO.new
    ReVIEW.logger = ReVIEW::Logger.new(@log_io)
    ReVIEW::I18n.setup(@config['language'])
  end

  def test_markdown_renderer_basic_functionality
    content = <<~EOB
      = Chapter Title

      This is a paragraph with @<b>{bold} and @<i>{italic} text.

      == Section Title

       * First item
       * Second item with @<code>{inline code}

       1. Ordered item one
       2. Ordered item two

      //list[sample-code][Sample Code][ruby]{
      def hello
        puts "Hello, World!"
      end
      //}

      //table[data-table][Sample Table]{
      Name	Age
      -----
      Alice	25
      Bob	30
      //}
    EOB

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))

    ast_compiler = ReVIEW::AST::Compiler.new
    ast_root = ast_compiler.compile_to_ast(chapter)

    markdown_renderer = ReVIEW::Renderer::MarkdownRenderer.new(chapter)
    markdown_result = markdown_renderer.render(ast_root)

    # Verify basic Markdown elements
    assert(markdown_result.include?('# Chapter Title'), 'Should have h1 with # syntax')
    assert(markdown_result.include?('## Section Title'), 'Should have h2 with ## syntax')
    assert(markdown_result.include?('**bold**'), 'Should have bold with ** syntax')
    assert(markdown_result.include?('*italic*'), 'Should have italic with * syntax')
    assert(markdown_result.include?('* First item'), 'Should have unordered list items')
    assert(markdown_result.include?('1. Ordered item one'), 'Should have ordered list items')
    assert(markdown_result.include?('```ruby'), 'Should have fenced code blocks')
    assert(markdown_result.include?('| Name | Age |'), 'Should have markdown table headers')
  end

  def test_markdown_renderer_inline_elements
    content = <<~EOB
      = Inline Elements Test

      Text with @<code>{code}, @<tt>{typewriter}, @<del>{deleted}, @<sup>{super}, @<sub>{sub}.

      Links: @<href>{http://example.com,Example Link} and @<href>{http://direct.com}.

      Ruby: @<ruby>{漢字,かんじ} annotation.

      Footnote reference@<fn>{note1}.

      //footnote[note1][This is a footnote]
    EOB

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))

    ast_compiler = ReVIEW::AST::Compiler.new
    ast_root = ast_compiler.compile_to_ast(chapter)

    markdown_renderer = ReVIEW::Renderer::MarkdownRenderer.new(chapter)
    markdown_result = markdown_renderer.render(ast_root)

    # Verify inline elements
    assert(markdown_result.include?('`code`'), 'Should render code with backticks')
    assert(markdown_result.include?('~~deleted~~'), 'Should render strikethrough')
    assert(markdown_result.include?('<sup>super</sup>'), 'Should render superscript with HTML')
    assert(markdown_result.include?('<sub>sub</sub>'), 'Should render subscript with HTML')
    assert(markdown_result.include?('[Example Link](http://example.com)'), 'Should render href links')
    assert(markdown_result.include?('<ruby>'), 'Should render ruby with HTML')
    assert(markdown_result.include?('[^note1]'), 'Should render footnote references')
    assert(markdown_result.include?('[^note1]: This is a footnote'), 'Should render footnote definitions')
  end

  def test_markdown_renderer_complex_structures
    content = <<~EOB
      = Complex Document

      == Section with Nested Lists

       * First level
       ** Second level with @<b>{bold text}
       *** Third level
       * Back to first level

      === Code with Line Numbers

      //listnum[numbered-code][Numbered Code][python]{
      def fibonacci(n):
          if n <= 1:
              return n
          return fibonacci(n-1) + fibonacci(n-2)
      //}

      === Quote Block

      //quote{
      This is a quoted text with @<i>{emphasis}.
      Multiple lines are supported.
      //}

      === Note Block

      //note[important-note][Important Note]{
      This is a note with @<code>{code} and other formatting.
      //}
    EOB

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))

    ast_compiler = ReVIEW::AST::Compiler.new
    ast_root = ast_compiler.compile_to_ast(chapter)

    markdown_renderer = ReVIEW::Renderer::MarkdownRenderer.new(chapter)
    markdown_result = markdown_renderer.render(ast_root)

    # Verify complex structures
    assert(markdown_result.include?('  * Second level'), 'Should handle nested lists with proper indentation')
    assert(markdown_result.include?('```python'), 'Should handle code blocks with language specification')
    assert(markdown_result.include?('> This is a quoted'), 'Should handle quote blocks with > prefix')
    assert(markdown_result.include?('<div class="note">'), 'Should handle minicolumns with HTML div')
  end

  def test_target_name
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    markdown_renderer = ReVIEW::Renderer::MarkdownRenderer.new(chapter)

    assert_equal('markdown', markdown_renderer.target_name)
  end
end
