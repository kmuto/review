# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require_relative '../test_helper'
require 'review/latex_converter'
require 'review/latex_comparator'

class TestLatexRendererBuilderComparison < Test::Unit::TestCase
  include ReVIEW

  def setup
    @converter = LATEXConverter.new
    @comparator = LATEXComparator.new
  end

  def test_simple_paragraph_comparison
    source = 'This is a simple paragraph.'

    builder_latex = @converter.convert_with_builder(source)
    renderer_latex = @converter.convert_with_renderer(source)

    result = @comparator.compare(builder_latex, renderer_latex)

    if result.different?
      puts "Builder LaTeX: #{builder_latex.inspect}"
      puts "Renderer LaTeX: #{renderer_latex.inspect}"
      puts "Differences: #{result.differences.inspect}"
    end

    assert result.equal?, 'Simple paragraph should produce equivalent LaTeX'
  end

  def test_headline_comparison
    source = '= Chapter Title'

    builder_latex = @converter.convert_with_builder(source)
    renderer_latex = @converter.convert_with_renderer(source)

    result = @comparator.compare(builder_latex, renderer_latex)

    if result.different?
      puts "Builder LaTeX: #{builder_latex.inspect}"
      puts "Renderer LaTeX: #{renderer_latex.inspect}"
      puts "Differences: #{result.differences.inspect}"
    end

    assert result.equal?, 'Headline should produce equivalent LaTeX'
  end

  def test_inline_formatting_comparison
    source = 'This has @<b>{bold} and @<i>{italic} and @<code>{code} text.'

    builder_latex = @converter.convert_with_builder(source)
    renderer_latex = @converter.convert_with_renderer(source)

    result = @comparator.compare(builder_latex, renderer_latex)

    if result.different?
      puts "Builder LaTeX: #{builder_latex.inspect}"
      puts "Renderer LaTeX: #{renderer_latex.inspect}"
      puts "Differences: #{result.differences.inspect}"
    end

    assert result.equal?
  end

  def test_code_block_comparison
    source = <<~RE
      //list[example][Code Example]{
      def hello
        puts "Hello World"
      end
      //}
    RE

    builder_latex = @converter.convert_with_builder(source)
    renderer_latex = @converter.convert_with_renderer(source)

    result = @comparator.compare(builder_latex, renderer_latex)

    if result.different?
      puts "Builder LaTeX: #{builder_latex.inspect}"
      puts "Renderer LaTeX: #{renderer_latex.inspect}"
      puts "Differences: #{result.differences.inspect}"
    end

    assert result.equal?
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

    builder_latex = @converter.convert_with_builder(source)
    renderer_latex = @converter.convert_with_renderer(source)

    result = @comparator.compare(builder_latex, renderer_latex)

    if result.different?
      puts "Builder LaTeX: #{builder_latex.inspect}"
      puts "Renderer LaTeX: #{renderer_latex.inspect}"
      puts "Differences: #{result.differences.inspect}"
    end

    assert result.equal?
  end

  def test_list_comparison
    source = <<~RE
      * First item
      * Second item
      * Third item
    RE

    builder_latex = @converter.convert_with_builder(source)
    renderer_latex = @converter.convert_with_renderer(source)

    result = @comparator.compare(builder_latex, renderer_latex)

    if result.different?
      puts "Builder LaTeX: #{builder_latex.inspect}"
      puts "Renderer LaTeX: #{renderer_latex.inspect}"
      puts "Differences: #{result.differences.inspect}"
    end

    assert result.equal?
  end

  def test_note_block_comparison
    source = <<~RE
      //note[Note Title]{
      This is a note block.
      //}
    RE

    builder_latex = @converter.convert_with_builder(source)
    renderer_latex = @converter.convert_with_renderer(source)

    result = @comparator.compare(builder_latex, renderer_latex)

    if result.different?
      puts "Builder LaTeX: #{builder_latex.inspect}"
      puts "Renderer LaTeX: #{renderer_latex.inspect}"
      puts "Differences: #{result.differences.inspect}"
    end

    assert result.equal?
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
      ---------------------
      A	1
      B	2
      //}
    RE

    builder_latex = @converter.convert_with_builder(source)
    renderer_latex = @converter.convert_with_renderer(source)

    result = @comparator.compare(builder_latex, renderer_latex)

    if result.different?
      puts 'Complex document differences found:'
      puts "Builder LaTeX length: #{builder_latex.length}"
      puts "Renderer LaTeX length: #{renderer_latex.length}"
      puts "Number of differences: #{result.differences.length}"

      # Show first few differences
      result.differences.first(3).each_with_index do |diff, i|
        puts "Difference #{i + 1}: #{diff[:description]}"
      end
    end

    assert result.equal?
  end

  def test_comparator_options
    latex1 = '\\chapter{Test}\\label{chap:test}'
    latex2 = '\\chapter{Test} \\label{chap:test}'

    # Whitespace sensitive comparison
    whitespace_sensitive_comparator = LATEXComparator.new(ignore_whitespace: false)
    result1 = whitespace_sensitive_comparator.compare(latex1, latex2)

    # Whitespace insensitive comparison
    whitespace_insensitive_comparator = LATEXComparator.new(ignore_whitespace: true)
    result2 = whitespace_insensitive_comparator.compare(latex1, latex2)

    assert result1.different?, 'Whitespace sensitive comparison should detect differences'
    assert result2.equal?, 'Whitespace insensitive comparison should ignore whitespace'
  end

  def test_mathematical_expressions
    source = 'This is a formula: @<m>{x^2 + y^2 = z^2}.'

    builder_latex = @converter.convert_with_builder(source)
    renderer_latex = @converter.convert_with_renderer(source)

    result = @comparator.compare(builder_latex, renderer_latex)

    if result.different?
      puts "Builder LaTeX: #{builder_latex.inspect}"
      puts "Renderer LaTeX: #{renderer_latex.inspect}"
      puts "Differences: #{result.differences.inspect}"
    end

    assert result.equal?
  end
end
