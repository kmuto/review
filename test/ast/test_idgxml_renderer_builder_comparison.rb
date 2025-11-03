# frozen_string_literal: true

require_relative '../test_helper'
require 'review/idgxml_converter'
require 'review/ast/diff/idgxml'

class TestIdgxmlRendererBuilderComparison < Test::Unit::TestCase
  include ReVIEW

  def setup
    @converter = IDGXMLConverter.new
    @comparator = AST::Diff::Idgxml.new
  end

  def test_simple_paragraph_comparison
    source = 'This is a simple paragraph.'

    builder_idgxml = @converter.convert_with_builder(source)
    renderer_idgxml = @converter.convert_with_renderer(source)

    result = @comparator.compare(builder_idgxml, renderer_idgxml)

    unless result.same_hash?
      puts "Builder IDGXML: #{builder_idgxml.inspect}"
      puts "Renderer IDGXML: #{renderer_idgxml.inspect}"
      puts result.pretty_diff
    end

    assert result.same_hash?, 'Simple paragraph should produce equivalent IDGXML'
  end

  def test_headline_comparison
    source = '= Chapter Title'

    builder_idgxml = @converter.convert_with_builder(source)
    renderer_idgxml = @converter.convert_with_renderer(source)

    result = @comparator.compare(builder_idgxml, renderer_idgxml)

    unless result.same_hash?
      puts "Builder IDGXML: #{builder_idgxml.inspect}"
      puts "Renderer IDGXML: #{renderer_idgxml.inspect}"
      puts result.pretty_diff
    end

    assert result.same_hash?, 'Headline should produce equivalent IDGXML'
  end

  def test_inline_formatting_comparison
    source = 'This has @<b>{bold} and @<i>{italic} and @<code>{code} text.'

    builder_idgxml = @converter.convert_with_builder(source)
    renderer_idgxml = @converter.convert_with_renderer(source)

    result = @comparator.compare(builder_idgxml, renderer_idgxml)

    unless result.same_hash?
      puts "Builder IDGXML: #{builder_idgxml.inspect}"
      puts "Renderer IDGXML: #{renderer_idgxml.inspect}"
      puts result.pretty_diff
    end

    assert result.same_hash?, 'Inline formatting should produce equivalent IDGXML'
  end

  def test_code_block_comparison
    source = <<~RE
      //list[example][Code Example]{
      def hello
        puts "Hello World"
      end
      //}
    RE

    builder_idgxml = @converter.convert_with_builder(source)
    renderer_idgxml = @converter.convert_with_renderer(source)

    result = @comparator.compare(builder_idgxml, renderer_idgxml)

    unless result.same_hash?
      puts "Builder IDGXML: #{builder_idgxml.inspect}"
      puts "Renderer IDGXML: #{renderer_idgxml.inspect}"
      puts result.pretty_diff
    end

    assert result.same_hash?
  end

  def test_table_comparison
    source = <<~RE
      //table[sample][Sample Table]{
      Header 1	Header 2
      ---------------------
      Data 1	Data 2
      Data 3	Data 4
      //}
    RE

    builder_idgxml = @converter.convert_with_builder(source)
    renderer_idgxml = @converter.convert_with_renderer(source)

    result = @comparator.compare(builder_idgxml, renderer_idgxml)

    unless result.same_hash?
      puts "Builder IDGXML: #{builder_idgxml.inspect}"
      puts "Renderer IDGXML: #{renderer_idgxml.inspect}"
      puts result.pretty_diff
    end

    assert result.same_hash?
  end

  def test_list_comparison
    source = <<~RE
      * First item
      * Second item
      * Third item
    RE

    builder_idgxml = @converter.convert_with_builder(source)
    renderer_idgxml = @converter.convert_with_renderer(source)

    result = @comparator.compare(builder_idgxml, renderer_idgxml)

    unless result.same_hash?
      puts "Builder IDGXML: #{builder_idgxml.inspect}"
      puts "Renderer IDGXML: #{renderer_idgxml.inspect}"
      puts result.pretty_diff
    end

    assert result.same_hash?
  end

  def test_note_block_comparison
    source = <<~RE
      //note[Note Title]{
      This is a note block.
      //}
    RE

    builder_idgxml = @converter.convert_with_builder(source)
    renderer_idgxml = @converter.convert_with_renderer(source)

    result = @comparator.compare(builder_idgxml, renderer_idgxml)

    unless result.same_hash?
      puts "Builder IDGXML: #{builder_idgxml.inspect}"
      puts "Renderer IDGXML: #{renderer_idgxml.inspect}"
      puts result.pretty_diff
    end

    assert result.same_hash?
  end

  def test_complex_document_comparison
    source = <<~RE
      = Chapter Title

      This is a paragraph with @<b>{bold} text.

      == Section Title

      Here's a list:

      * Item 1
      * Item 2

      And a code block:

      //list[example][Example]{
      puts "Hello"
      //}

      //table[data][Data Table]{
      Name	Value
      ----------------------
      A	1
      B	2
      //}
    RE

    builder_idgxml = @converter.convert_with_builder(source)
    renderer_idgxml = @converter.convert_with_renderer(source)

    result = @comparator.compare(builder_idgxml, renderer_idgxml)

    unless result.same_hash?
      puts 'Complex document differences found:'
      puts "Builder IDGXML length: #{builder_idgxml.length}"
      puts "Renderer IDGXML length: #{renderer_idgxml.length}"
      puts "Builder IDGXML: #{builder_idgxml.inspect}"
      puts "Renderer IDGXML: #{renderer_idgxml.inspect}"
      puts result.pretty_diff
    end

    assert result.same_hash?
  end

  # Tests with actual Re:VIEW files from samples/syntax-book
  def test_syntax_book_ch01
    file_path = File.join(__dir__, '../../samples/syntax-book/ch01.re')
    source = File.read(file_path)

    builder_idgxml = @converter.convert_with_builder(source)
    renderer_idgxml = @converter.convert_with_renderer(source)

    result = @comparator.compare(builder_idgxml, renderer_idgxml)

    unless result.same_hash?
      puts 'ch01.re differences found:'
      puts "Builder IDGXML length: #{builder_idgxml.length}"
      puts "Renderer IDGXML length: #{renderer_idgxml.length}"
      puts result.pretty_diff
    end

    assert result.same_hash?, 'ch01.re should produce equivalent IDGXML'
  end

  def test_syntax_book_ch02
    book_dir = File.join(__dir__, '../../samples/syntax-book')
    result = @converter.convert_chapter_with_book_context(book_dir, 'ch02')

    builder_idgxml = result[:builder]
    renderer_idgxml = result[:renderer]

    result = @comparator.compare(builder_idgxml, renderer_idgxml)

    unless result.same_hash?
      puts 'ch02.re differences found:'
      puts "Builder IDGXML length: #{builder_idgxml.length}"
      puts "Renderer IDGXML length: #{renderer_idgxml.length}"
      puts result.pretty_diff
    end

    assert result.same_hash?, 'ch02.re should produce equivalent IDGXML'
  end

  def test_syntax_book_ch03
    file_path = File.join(__dir__, '../../samples/syntax-book/ch03.re')
    source = File.read(file_path)

    builder_idgxml = @converter.convert_with_builder(source)
    renderer_idgxml = @converter.convert_with_renderer(source)

    result = @comparator.compare(builder_idgxml, renderer_idgxml)

    unless result.same_hash?
      puts 'ch03.re differences found:'
      puts "Builder IDGXML: #{builder_idgxml}"
      puts "Renderer IDGXML: #{renderer_idgxml}"
      puts result.pretty_diff
    end

    assert result.same_hash?, 'ch03.re should produce equivalent IDGXML'
  end

  def test_syntax_book_pre01
    file_path = File.join(__dir__, '../../samples/syntax-book/pre01.re')
    source = File.read(file_path)

    builder_idgxml = @converter.convert_with_builder(source)
    renderer_idgxml = @converter.convert_with_renderer(source)

    result = @comparator.compare(builder_idgxml, renderer_idgxml)

    unless result.same_hash?
      puts 'pre01.re differences found:'
      puts "Builder IDGXML length: #{builder_idgxml.length}"
      puts "Renderer IDGXML length: #{renderer_idgxml.length}"
      puts result.pretty_diff
    end

    assert result.same_hash?, 'pre01.re should produce equivalent IDGXML'
  end

  def test_syntax_book_appA
    file_path = File.join(__dir__, '../../samples/syntax-book/appA.re')
    source = File.read(file_path)

    builder_idgxml = @converter.convert_with_builder(source)
    renderer_idgxml = @converter.convert_with_renderer(source)

    result = @comparator.compare(builder_idgxml, renderer_idgxml)

    unless result.same_hash?
      puts 'appA.re differences found:'
      puts "Builder IDGXML length: #{builder_idgxml.length}"
      puts "Renderer IDGXML length: #{renderer_idgxml.length}"
      puts result.pretty_diff
    end

    assert result.same_hash?, 'appA.re should produce equivalent IDGXML'
  end

  def test_syntax_book_part2
    file_path = File.join(__dir__, '../../samples/syntax-book/part2.re')
    source = File.read(file_path)

    builder_idgxml = @converter.convert_with_builder(source)
    renderer_idgxml = @converter.convert_with_renderer(source)

    result = @comparator.compare(builder_idgxml, renderer_idgxml)

    unless result.same_hash?
      puts 'part2.re differences found:'
      puts "Builder IDGXML length: #{builder_idgxml.length}"
      puts "Renderer IDGXML length: #{renderer_idgxml.length}"
      puts result.pretty_diff
    end

    assert result.same_hash?, 'part2.re should produce equivalent IDGXML'
  end

  def test_syntax_book_bib
    book_dir = File.join(__dir__, '../../samples/syntax-book')
    result = @converter.convert_chapter_with_book_context(book_dir, 'bib')

    builder_idgxml = result[:builder]
    renderer_idgxml = result[:renderer]

    result = @comparator.compare(builder_idgxml, renderer_idgxml)

    unless result.same_hash?
      puts 'bib.re differences found:'
      puts "Builder IDGXML length: #{builder_idgxml.length}"
      puts "Renderer IDGXML length: #{renderer_idgxml.length}"
      puts result.pretty_diff
    end

    assert result.same_hash?, 'bib.re should produce equivalent IDGXML'
  end

  # Tests with actual Re:VIEW files from samples/debug-book
  def test_debug_book_advanced_features
    file_path = File.join(__dir__, '../../samples/debug-book/advanced_features.re')
    source = File.read(file_path)

    builder_idgxml = @converter.convert_with_builder(source)
    renderer_idgxml = @converter.convert_with_renderer(source)

    result = @comparator.compare(builder_idgxml, renderer_idgxml)

    unless result.same_hash?
      puts 'advanced_features.re differences found:'
      puts "Builder IDGXML length: #{builder_idgxml.length}"
      puts "Renderer IDGXML length: #{renderer_idgxml.length}"
      puts result.pretty_diff
    end

    assert result.same_hash?, 'advanced_features.re should produce equivalent IDGXML'
  end

  def test_debug_book_comprehensive
    file_path = File.join(__dir__, '../../samples/debug-book/comprehensive.re')
    source = File.read(file_path)

    builder_idgxml = @converter.convert_with_builder(source)
    renderer_idgxml = @converter.convert_with_renderer(source)

    result = @comparator.compare(builder_idgxml, renderer_idgxml)

    unless result.same_hash?
      puts 'comprehensive.re differences found:'
      puts "Builder IDGXML length: #{builder_idgxml.length}"
      puts "Renderer IDGXML length: #{renderer_idgxml.length}"
      puts result.pretty_diff
    end

    assert result.same_hash?, 'comprehensive.re should produce equivalent IDGXML'
  end

  def test_debug_book_edge_cases_test
    file_path = File.join(__dir__, '../../samples/debug-book/edge_cases_test.re')
    source = File.read(file_path)

    builder_idgxml = @converter.convert_with_builder(source)
    renderer_idgxml = @converter.convert_with_renderer(source)

    result = @comparator.compare(builder_idgxml, renderer_idgxml)

    unless result.same_hash?
      puts 'edge_cases_test.re differences found:'
      puts "Builder IDGXML length: #{builder_idgxml.length}"
      puts "Renderer IDGXML length: #{renderer_idgxml.length}"
      puts result.pretty_diff
    end

    assert result.same_hash?, 'edge_cases_test.re should produce equivalent IDGXML'
  end

  def test_debug_book_extreme_features
    file_path = File.join(__dir__, '../../samples/debug-book/extreme_features.re')
    source = File.read(file_path)

    builder_idgxml = @converter.convert_with_builder(source)
    renderer_idgxml = @converter.convert_with_renderer(source)

    result = @comparator.compare(builder_idgxml, renderer_idgxml)

    unless result.same_hash?
      puts 'extreme_features.re differences found:'
      puts "Builder IDGXML length: #{builder_idgxml.length}"
      puts "Renderer IDGXML length: #{renderer_idgxml.length}"
      puts result.pretty_diff
    end

    assert result.same_hash?, 'extreme_features.re should produce equivalent IDGXML'
  end

  def test_debug_book_multicontent_test
    file_path = File.join(__dir__, '../../samples/debug-book/multicontent_test.re')
    source = File.read(file_path)

    builder_idgxml = @converter.convert_with_builder(source)
    renderer_idgxml = @converter.convert_with_renderer(source)

    result = @comparator.compare(builder_idgxml, renderer_idgxml)

    unless result.same_hash?
      puts 'multicontent_test.re differences found:'
      puts "Builder IDGXML length: #{builder_idgxml.length}"
      puts "Renderer IDGXML length: #{renderer_idgxml.length}"
      puts result.pretty_diff
    end

    assert result.same_hash?, 'multicontent_test.re should produce equivalent IDGXML'
  end
end
