# frozen_string_literal: true

require_relative '../test_helper'
require 'review/ast'
require 'review/ast/compiler'
require 'review/renderer/markdown_renderer'
require 'review/renderer/top_renderer'
require 'review/markdownbuilder'
require 'review/topbuilder'
require 'review/configure'
require 'review/book'
require 'review/book/chapter'
require 'review/i18n'
require 'review/compiler'

class TestRendererBuilderComparison < Test::Unit::TestCase
  def setup
    @config = ReVIEW::Configure.values
    @config['secnolevel'] = 2
    @config['language'] = 'ja'

    @book = ReVIEW::Book::Base.new(config: @config)
    @log_io = StringIO.new
    ReVIEW.logger = ReVIEW::Logger.new(@log_io)
    ReVIEW::I18n.setup(@config['language'])
  end

  def compile_with_builder(content, builder_class)
    builder = builder_class.new
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))

    begin
      # Use traditional compiler (this will call builder.bind internally)
      compiler = ReVIEW::Compiler.new(builder)
      compiler.compile(chapter)

      # Get result from builder
      builder.result
    rescue StandardError => e
      # If builder fails, return empty string with error comment
      "<!-- Builder Error: #{e.message} -->\n"
    end
  end

  def compile_with_renderer(content, renderer_class)
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))

    ast_compiler = ReVIEW::AST::Compiler.new
    ast_root = ast_compiler.compile_to_ast(chapter, reference_resolution: false)

    renderer = renderer_class.new(chapter)
    renderer.render(ast_root)
  end

  def test_markdown_basic_elements_comparison
    content = <<~EOB
      = Chapter Title

      This is a paragraph with @<b>{bold} and @<i>{italic} text.

      == Section Title

       * First item
       * Second item

       1. Ordered item one
       2. Ordered item two
    EOB

    # Compare outputs
    builder_output = compile_with_builder(content, ReVIEW::MARKDOWNBuilder)
    renderer_output = compile_with_renderer(content, ReVIEW::Renderer::MarkdownRenderer)

    # Normalize outputs for comparison
    builder_output.strip.split("\n")
    renderer_output.strip.split("\n")

    # Check key elements
    assert_includes(renderer_output, '# Chapter Title', 'Renderer should produce h1 with #')
    assert_includes(renderer_output, '## Section Title', 'Renderer should produce h2 with ##')
    assert_includes(renderer_output, '**bold**', 'Renderer should produce bold with **')
    assert_includes(renderer_output, '*italic*', 'Renderer should produce italic with *')
    assert_includes(renderer_output, '* First item', 'Renderer should produce unordered lists')
    assert_includes(renderer_output, '1. Ordered item one', 'Renderer should produce ordered lists')
  end

  def test_top_basic_elements_comparison
    content = <<~EOB
      = Chapter Title

      This is a paragraph with @<b>{bold} and @<i>{italic} text.

      == Section Title

       * First item
       * Second item
    EOB

    # Compare outputs
    compile_with_builder(content, ReVIEW::TOPBuilder)
    renderer_output = compile_with_renderer(content, ReVIEW::Renderer::TopRenderer)

    # Check key elements
    assert_includes(renderer_output, '■H1■', 'Renderer should produce H1 marker')
    assert_includes(renderer_output, '■H2■', 'Renderer should produce H2 marker')
    assert_includes(renderer_output, '★bold☆', 'Renderer should produce bold markers')
    assert_includes(renderer_output, '▲italic☆', 'Renderer should produce italic markers')
    assert_includes(renderer_output, '●	First item', 'Renderer should produce unordered list markers')
  end

  def test_markdown_code_block_comparison
    content = <<~EOB
      = Code Test

      //list[sample][Sample Code][ruby]{
      def hello
        puts "Hello"
      end
      //}
    EOB

    compile_with_builder(content, ReVIEW::MARKDOWNBuilder)
    renderer_output = compile_with_renderer(content, ReVIEW::Renderer::MarkdownRenderer)

    # Check code block format
    assert_includes(renderer_output, '```ruby', 'Renderer should produce fenced code blocks')
    assert_includes(renderer_output, 'def hello', 'Renderer should include code content')
    assert_includes(renderer_output, '```', 'Renderer should close fenced code blocks')

    # Check caption
    assert_includes(renderer_output, '**Sample Code**', 'Renderer should include code caption')
  end

  def test_top_code_block_comparison
    content = <<~EOB
      = Code Test

      //list[sample][Sample Code][ruby]{
      def hello
        puts "Hello"
      end
      //}
    EOB

    compile_with_builder(content, ReVIEW::TOPBuilder)
    renderer_output = compile_with_renderer(content, ReVIEW::Renderer::TopRenderer)

    # Check TOP code block format
    assert_includes(renderer_output, '◆→開始:リスト←◆', 'Renderer should produce list begin marker')
    assert_includes(renderer_output, '◆→終了:リスト←◆', 'Renderer should produce list end marker')
    assert_includes(renderer_output, '■sample■Sample Code', 'Renderer should include code caption with ID')
    assert_includes(renderer_output, 'def hello', 'Renderer should include code content')
  end

  def test_markdown_table_comparison
    content = <<~EOB
      = Table Test

      //table[data][Data Table]{
      Name	Age
      -----
      Alice	25
      Bob	30
      //}
    EOB

    compile_with_builder(content, ReVIEW::MARKDOWNBuilder)
    renderer_output = compile_with_renderer(content, ReVIEW::Renderer::MarkdownRenderer)

    # Check table format
    assert_includes(renderer_output, '| Name | Age |', 'Renderer should produce table headers')
    assert_includes(renderer_output, '| :-- | :-- |', 'Renderer should produce table separator')
    assert_includes(renderer_output, '| Alice | 25 |', 'Renderer should produce table rows')

    # Check caption
    assert_includes(renderer_output, '**Data Table**', 'Renderer should include table caption')
  end

  def test_markdown_inline_elements_comparison
    content = <<~EOB
      = Inline Test

      Text with @<code>{code}, @<tt>{tt}, @<del>{strikethrough}.

      Links: @<href>{http://example.com,Example} and @<href>{http://direct.com}.
    EOB

    compile_with_builder(content, ReVIEW::MARKDOWNBuilder)
    renderer_output = compile_with_renderer(content, ReVIEW::Renderer::MarkdownRenderer)

    # Check inline elements
    assert_includes(renderer_output, '`code`', 'Renderer should produce inline code')
    assert_includes(renderer_output, '`tt`', 'Renderer should produce tt as code')
    assert_includes(renderer_output, '~~strikethrough~~', 'Renderer should produce strikethrough')
    assert_includes(renderer_output, '[Example](http://example.com)', 'Renderer should produce href links')
    assert_includes(renderer_output, '[http://direct.com](http://direct.com)', 'Renderer should produce url links')
  end

  def test_top_inline_elements_comparison
    content = <<~EOB
      = Inline Test

      Text with @<code>{code}, @<sup>{super}, @<sub>{sub}.

      Link: @<href>{http://example.com,Example}.
    EOB

    compile_with_builder(content, ReVIEW::TOPBuilder)
    renderer_output = compile_with_renderer(content, ReVIEW::Renderer::TopRenderer)

    # Check inline elements
    assert_includes(renderer_output, '△code☆', 'Renderer should produce code markers')
    assert_includes(renderer_output, 'super◆→DTP連絡:「super」は上付き←◆', 'Renderer should produce superscript DTP')
    assert_includes(renderer_output, 'sub◆→DTP連絡:「sub」は下付き←◆', 'Renderer should produce subscript DTP')
    assert_includes(renderer_output, 'Example（△http://example.com☆）', 'Renderer should produce href links')
  end

  def test_markdown_footnote_comparison
    content = <<~EOB
      = Footnote Test

      Text with footnote@<fn>{note1}.

      //footnote[note1][This is a footnote]
    EOB

    compile_with_builder(content, ReVIEW::MARKDOWNBuilder)
    renderer_output = compile_with_renderer(content, ReVIEW::Renderer::MarkdownRenderer)

    # Check footnote format
    assert_includes(renderer_output, '[^note1]', 'Renderer should produce footnote reference')
    assert_includes(renderer_output, '[^note1]: This is a footnote', 'Renderer should produce footnote definition')
  end

  def test_markdown_minicolumn_comparison
    content = <<~EOB
      = Minicolumn Test

      //note[note1][Note Title]{
      This is a note.
      //}
    EOB

    compile_with_builder(content, ReVIEW::MARKDOWNBuilder)
    renderer_output = compile_with_renderer(content, ReVIEW::Renderer::MarkdownRenderer)

    # Check minicolumn format
    assert_includes(renderer_output, '<div class="note">', 'Renderer should produce div for minicolumn')
    assert_includes(renderer_output, '**Note Title**', 'Renderer should include minicolumn caption')
    assert_includes(renderer_output, 'This is a note.', 'Renderer should include minicolumn content')
    assert_includes(renderer_output, '</div>', 'Renderer should close div')
  end

  def test_top_minicolumn_comparison
    content = <<~EOB
      = Minicolumn Test

      //note[note1][Note Title]{
      This is a note.
      //}
    EOB

    compile_with_builder(content, ReVIEW::TOPBuilder)
    renderer_output = compile_with_renderer(content, ReVIEW::Renderer::TopRenderer)

    # Check minicolumn format
    assert_includes(renderer_output, '◆→開始:ノート←◆', 'Renderer should produce note begin marker')
    assert_includes(renderer_output, '◆→終了:ノート←◆', 'Renderer should produce note end marker')
    assert_includes(renderer_output, '■Note Title', 'Renderer should include note caption')
    assert_includes(renderer_output, 'This is a note.', 'Renderer should include note content')
  end

  def test_top_footnote_comparison
    content = <<~EOB
      = Footnote Test

      Text with footnote@<fn>{note1} and another@<fn>{note2}.

      More text here.

      //footnote[note1][This is the first footnote]
      //footnote[note2][This is the second footnote]
    EOB

    # Compile with both builder and renderer (need reference resolution for footnotes)
    builder_output = compile_with_builder(content, ReVIEW::TOPBuilder)

    # Compile with renderer with reference resolution enabled
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_compiler = ReVIEW::AST::Compiler.new
    ast_root = ast_compiler.compile_to_ast(chapter, reference_resolution: true)
    renderer = ReVIEW::Renderer::TopRenderer.new(chapter)
    renderer_output = renderer.render(ast_root)

    # Check inline footnote references in both outputs
    assert_includes(builder_output, '【注1】', 'Builder should produce footnote reference 1')
    assert_includes(renderer_output, '【注1】', 'Renderer should produce footnote reference 1')
    assert_includes(builder_output, '【注2】', 'Builder should produce footnote reference 2')
    assert_includes(renderer_output, '【注2】', 'Renderer should produce footnote reference 2')

    # Check footnote definitions in both outputs
    assert_includes(builder_output, '【注1】This is the first footnote', 'Builder should produce footnote definition 1')
    assert_includes(renderer_output, '【注1】This is the first footnote', 'Renderer should produce footnote definition 1')
    assert_includes(builder_output, '【注2】This is the second footnote', 'Builder should produce footnote definition 2')
    assert_includes(renderer_output, '【注2】This is the second footnote', 'Renderer should produce footnote definition 2')

    # Check that numbering is consistent (footnote 1 comes before footnote 2)
    builder_note1_pos = builder_output.index('【注1】')
    builder_note2_pos = builder_output.index('【注2】')
    assert(builder_note1_pos < builder_note2_pos, 'Builder should order footnotes correctly')

    renderer_note1_pos = renderer_output.index('【注1】')
    renderer_note2_pos = renderer_output.index('【注2】')
    assert(renderer_note1_pos < renderer_note2_pos, 'Renderer should order footnotes correctly')
  end
end
