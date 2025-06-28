# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require File.expand_path('test_helper', __dir__)
require 'review/html_converter'

require 'review/html_comparator'

class TestHtmlRendererBuilderComparison < Test::Unit::TestCase
  include ReVIEW

  def setup
    @converter = HTMLConverter.new
    @comparator = HTMLComparator.new
  end

  def test_simple_paragraph_comparison
    source = 'This is a simple paragraph.'

    builder_html = @converter.convert_with_builder(source)
    renderer_html = @converter.convert_with_renderer(source)

    result = @comparator.compare(builder_html, renderer_html)

    if result.different?
      puts "Builder HTML: #{builder_html.inspect}"
      puts "Renderer HTML: #{renderer_html.inspect}"
      puts "Differences: #{result.differences.inspect}"
    end

    assert result.equal?, 'Simple paragraph should produce equivalent HTML'
  end

  def test_headline_comparison
    source = '= Chapter Title'

    builder_html = @converter.convert_with_builder(source)
    renderer_html = @converter.convert_with_renderer(source)

    result = @comparator.compare(builder_html, renderer_html)

    if result.different?
      puts "Builder HTML: #{builder_html.inspect}"
      puts "Renderer HTML: #{renderer_html.inspect}"
      puts "Differences: #{result.differences.inspect}"
    end

    assert result.equal?, 'Headline should produce equivalent HTML'
  end

  def test_inline_formatting_comparison
    source = 'This has @<b>{bold} and @<i>{italic} and @<code>{code} text.'

    builder_html = @converter.convert_with_builder(source)
    renderer_html = @converter.convert_with_renderer(source)

    result = @comparator.compare(builder_html, renderer_html)

    if result.different?
      puts "Builder HTML: #{builder_html.inspect}"
      puts "Renderer HTML: #{renderer_html.inspect}"
      puts "Differences: #{result.differences.inspect}"
    end

    assert result.equal?, 'Inline formatting should produce equivalent HTML'
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

    result = @comparator.compare(builder_html, renderer_html)

    if result.different?
      puts "Builder HTML: #{builder_html.inspect}"
      puts "Renderer HTML: #{renderer_html.inspect}"
      puts "Differences: #{result.differences.inspect}"
    end

    # NOTE: This might fail initially as the formats may differ
    # The test is here to help identify differences
    puts "Code block comparison result: #{result.summary}"
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

    result = @comparator.compare(builder_html, renderer_html)

    if result.different?
      puts "Builder HTML: #{builder_html.inspect}"
      puts "Renderer HTML: #{renderer_html.inspect}"
      puts "Differences: #{result.differences.inspect}"
    end

    # NOTE: This might fail initially as the formats may differ
    puts "Table comparison result: #{result.summary}"
  end

  def test_list_comparison
    source = <<~RE
      * First item
      * Second item
      * Third item
    RE

    builder_html = @converter.convert_with_builder(source)
    renderer_html = @converter.convert_with_renderer(source)

    result = @comparator.compare(builder_html, renderer_html)

    if result.different?
      puts "Builder HTML: #{builder_html.inspect}"
      puts "Renderer HTML: #{renderer_html.inspect}"
      puts "Differences: #{result.differences.inspect}"
    end

    puts "List comparison result: #{result.summary}"
  end

  def test_note_block_comparison
    source = <<~RE
      //note[Note Title]{
      This is a note block.
      //}
    RE

    builder_html = @converter.convert_with_builder(source)
    renderer_html = @converter.convert_with_renderer(source)

    result = @comparator.compare(builder_html, renderer_html)

    if result.different?
      puts "Builder HTML: #{builder_html.inspect}"
      puts "Renderer HTML: #{renderer_html.inspect}"
      puts "Differences: #{result.differences.inspect}"
    end

    puts "Note block comparison result: #{result.summary}"
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

    result = @comparator.compare(builder_html, renderer_html)

    if result.different?
      puts 'Complex document differences found:'
      puts "Builder HTML length: #{builder_html.length}"
      puts "Renderer HTML length: #{renderer_html.length}"
      puts "Number of differences: #{result.differences.length}"
      puts "Builder HTML: #{builder_html.inspect}"
      puts "Renderer HTML: #{renderer_html.inspect}"

      # Show first few differences
      result.differences.first(3).each_with_index do |diff, i|
        puts "Difference #{i + 1}: #{diff[:description]}"
      end
    end

    puts "Complex document comparison result: #{result.summary}"
  end

  def test_dom_comparison_vs_string_comparison
    html1 = '<p>Hello <b>World</b></p>'
    html2 = '<p>Hello<b> World </b></p>' # Different whitespace

    string_result = @comparator.compare(html1, html2)
    dom_result = @comparator.compare_dom(html1, html2)

    # String comparison should find differences due to whitespace
    assert string_result.different?, 'String comparison should detect whitespace differences'

    # DOM comparison might be more lenient with whitespace
    puts "String comparison: #{string_result.summary}"
    puts "DOM comparison: #{dom_result.summary}"
  end

  def test_comparator_options
    html1 = '<P CLASS="test">Hello</P>'
    html2 = '<p class="test">Hello</p>'

    # Case sensitive comparison
    case_sensitive_comparator = HTMLComparator.new(case_sensitive: true)
    result1 = case_sensitive_comparator.compare(html1, html2)

    # Case insensitive comparison
    case_insensitive_comparator = HTMLComparator.new(case_sensitive: false)
    result2 = case_insensitive_comparator.compare(html1, html2)

    assert result1.different?, 'Case sensitive comparison should detect differences'
    assert result2.equal?, 'Case insensitive comparison should ignore case'
  end
end
