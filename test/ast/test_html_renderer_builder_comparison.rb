# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require_relative '../test_helper'
require 'review/html_converter'
require 'review/ast/html_diff'

class TestHtmlRendererBuilderComparison < Test::Unit::TestCase
  include ReVIEW

  def setup
    @converter = HTMLConverter.new
  end

  def test_simple_paragraph_comparison
    source = 'This is a simple paragraph.'

    builder_html = @converter.convert_with_builder(source)
    renderer_html = @converter.convert_with_renderer(source)

    diff = ReVIEW::AST::HtmlDiff.new(builder_html, renderer_html)

    unless diff.same_hash?
      puts "Builder HTML: #{builder_html.inspect}"
      puts "Renderer HTML: #{renderer_html.inspect}"
      puts diff.pretty_diff
    end

    assert diff.same_hash?, 'Simple paragraph should produce equivalent HTML'
  end

  def test_headline_comparison
    source = '= Chapter Title'

    builder_html = @converter.convert_with_builder(source)
    renderer_html = @converter.convert_with_renderer(source)

    diff = ReVIEW::AST::HtmlDiff.new(builder_html, renderer_html)

    unless diff.same_hash?
      puts "Builder HTML: #{builder_html.inspect}"
      puts "Renderer HTML: #{renderer_html.inspect}"
      puts diff.pretty_diff
    end

    assert diff.same_hash?, 'Headline should produce equivalent HTML'
  end

  def test_inline_formatting_comparison
    source = 'This has @<b>{bold} and @<i>{italic} and @<code>{code} text.'

    builder_html = @converter.convert_with_builder(source)
    renderer_html = @converter.convert_with_renderer(source)

    diff = ReVIEW::AST::HtmlDiff.new(builder_html, renderer_html)

    unless diff.same_hash?
      puts "Builder HTML: #{builder_html.inspect}"
      puts "Renderer HTML: #{renderer_html.inspect}"
      puts diff.pretty_diff
    end

    assert diff.same_hash?, 'Inline formatting should produce equivalent HTML'
  end

  def test_code_block_comparison
    source = <<~RE
      //list[example][Code Example]{
      def hello
        puts "Hello World"
      end
      //}
    RE

    builder_html = @converter.convert_with_builder(source)
    renderer_html = @converter.convert_with_renderer(source)

    diff = ReVIEW::AST::HtmlDiff.new(builder_html, renderer_html)

    unless diff.same_hash?
      puts "Builder HTML: #{builder_html.inspect}"
      puts "Renderer HTML: #{renderer_html.inspect}"
      puts diff.pretty_diff
    end

    assert diff.same_hash?
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

    builder_html = @converter.convert_with_builder(source)
    renderer_html = @converter.convert_with_renderer(source)

    diff = ReVIEW::AST::HtmlDiff.new(builder_html, renderer_html)

    unless diff.same_hash?
      puts "Builder HTML: #{builder_html.inspect}"
      puts "Renderer HTML: #{renderer_html.inspect}"
      puts diff.pretty_diff
    end

    assert diff.same_hash?
  end

  def test_list_comparison
    source = <<~RE
      * First item
      * Second item
      * Third item
    RE

    builder_html = @converter.convert_with_builder(source)
    renderer_html = @converter.convert_with_renderer(source)

    diff = ReVIEW::AST::HtmlDiff.new(builder_html, renderer_html)

    unless diff.same_hash?
      puts "Builder HTML: #{builder_html.inspect}"
      puts "Renderer HTML: #{renderer_html.inspect}"
      puts diff.pretty_diff
    end

    assert diff.same_hash?
  end

  def test_note_block_comparison
    source = <<~RE
      //note[Note Title]{
      This is a note block.
      //}
    RE

    builder_html = @converter.convert_with_builder(source)
    renderer_html = @converter.convert_with_renderer(source)

    diff = ReVIEW::AST::HtmlDiff.new(builder_html, renderer_html)

    unless diff.same_hash?
      puts "Builder HTML: #{builder_html.inspect}"
      puts "Renderer HTML: #{renderer_html.inspect}"
      puts diff.pretty_diff
    end

    assert diff.same_hash?
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

    builder_html = @converter.convert_with_builder(source)
    renderer_html = @converter.convert_with_renderer(source)

    diff = ReVIEW::AST::HtmlDiff.new(builder_html, renderer_html)

    unless diff.same_hash?
      puts 'Complex document differences found:'
      puts "Builder HTML length: #{builder_html.length}"
      puts "Renderer HTML length: #{renderer_html.length}"
      puts "Builder HTML: #{builder_html.inspect}"
      puts "Renderer HTML: #{renderer_html.inspect}"
      puts diff.pretty_diff
    end

    assert diff.same_hash?
  end

  # Tests with actual Re:VIEW files from samples/syntax-book
  def test_syntax_book_ch01
    file_path = File.join(__dir__, '../../samples/syntax-book/ch01.re')
    source = File.read(file_path)

    builder_html = @converter.convert_with_builder(source)
    renderer_html = @converter.convert_with_renderer(source)

    diff = ReVIEW::AST::HtmlDiff.new(builder_html, renderer_html)

    unless diff.same_hash?
      puts 'ch01.re differences found:'
      puts "Builder HTML length: #{builder_html.length}"
      puts "Renderer HTML length: #{renderer_html.length}"
      puts diff.pretty_diff
    end

    assert diff.same_hash?, 'ch01.re should produce equivalent HTML'
  end

  def test_syntax_book_ch02
    pend('ch02.re has cross-reference errors that prevent compilation')
    file_path = File.join(__dir__, '../../samples/syntax-book/ch02.re')
    source = File.read(file_path)

    builder_html = @converter.convert_with_builder(source)
    renderer_html = @converter.convert_with_renderer(source)

    diff = ReVIEW::AST::HtmlDiff.new(builder_html, renderer_html)

    unless diff.same_hash?
      puts 'ch02.re differences found:'
      puts "Builder HTML length: #{builder_html.length}"
      puts "Renderer HTML length: #{renderer_html.length}"
      puts diff.pretty_diff
    end

    assert diff.same_hash?, 'ch02.re should produce equivalent HTML'
  end

  def test_syntax_book_ch03
    file_path = File.join(__dir__, '../../samples/syntax-book/ch03.re')
    source = File.read(file_path)

    builder_html = @converter.convert_with_builder(source)
    renderer_html = @converter.convert_with_renderer(source)

    diff = ReVIEW::AST::HtmlDiff.new(builder_html, renderer_html)

    unless diff.same_hash?
      puts 'ch03.re differences found:'
      puts "Builder HTML: #{builder_html}"
      puts "Renderer HTML: #{renderer_html}"
      puts diff.pretty_diff
    end

    assert diff.same_hash?, 'ch03.re should produce equivalent HTML'
  end

  def test_syntax_book_pre01
    pend('pre01.re has unknown list references that cause errors')
    file_path = File.join(__dir__, '../../samples/syntax-book/pre01.re')
    source = File.read(file_path)

    builder_html = @converter.convert_with_builder(source)
    renderer_html = @converter.convert_with_renderer(source)

    diff = ReVIEW::AST::HtmlDiff.new(builder_html, renderer_html)

    unless diff.same_hash?
      puts 'pre01.re differences found:'
      puts "Builder HTML length: #{builder_html.length}"
      puts "Renderer HTML length: #{renderer_html.length}"
      puts diff.pretty_diff
    end

    assert diff.same_hash?, 'pre01.re should produce equivalent HTML'
  end

  def test_syntax_book_appA
    pend('appA.re has unknown list references that cause errors')
    file_path = File.join(__dir__, '../../samples/syntax-book/appA.re')
    source = File.read(file_path)

    builder_html = @converter.convert_with_builder(source)
    renderer_html = @converter.convert_with_renderer(source)

    diff = ReVIEW::AST::HtmlDiff.new(builder_html, renderer_html)

    unless diff.same_hash?
      puts 'appA.re differences found:'
      puts "Builder HTML length: #{builder_html.length}"
      puts "Renderer HTML length: #{renderer_html.length}"
      puts diff.pretty_diff
    end

    assert diff.same_hash?, 'appA.re should produce equivalent HTML'
  end

  def test_syntax_book_part2
    file_path = File.join(__dir__, '../../samples/syntax-book/part2.re')
    source = File.read(file_path)

    builder_html = @converter.convert_with_builder(source)
    renderer_html = @converter.convert_with_renderer(source)

    diff = ReVIEW::AST::HtmlDiff.new(builder_html, renderer_html)

    unless diff.same_hash?
      puts 'part2.re differences found:'
      puts "Builder HTML length: #{builder_html.length}"
      puts "Renderer HTML length: #{renderer_html.length}"
      puts diff.pretty_diff
    end

    assert diff.same_hash?, 'part2.re should produce equivalent HTML'
  end

  def test_syntax_book_bib
    pend('bib.re requires missing bib.re file')
    file_path = File.join(__dir__, '../../samples/syntax-book/bib.re')
    source = File.read(file_path)

    builder_html = @converter.convert_with_builder(source)
    renderer_html = @converter.convert_with_renderer(source)

    diff = ReVIEW::AST::HtmlDiff.new(builder_html, renderer_html)

    unless diff.same_hash?
      puts 'bib.re differences found:'
      puts "Builder HTML length: #{builder_html.length}"
      puts "Renderer HTML length: #{renderer_html.length}"
      puts diff.pretty_diff
    end

    assert diff.same_hash?, 'bib.re should produce equivalent HTML'
  end
end
