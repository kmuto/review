# frozen_string_literal: true

require_relative '../../test_helper'
require 'review/ast/diff/markdown'

class TestMarkdownDiff < Test::Unit::TestCase
  def setup
    @differ = ReVIEW::AST::Diff::Markdown.new
  end

  def test_equal_identical_strings
    left = "# Heading\n\nParagraph"
    right = "# Heading\n\nParagraph"

    result = @differ.compare(left, right)
    assert(result.equal?)
    assert(result.same_hash?)
    assert(!result.different?)
  end

  def test_different_content
    left = "# Heading 1"
    right = "# Heading 2"

    result = @differ.compare(left, right)
    assert(!result.equal?)
    assert(result.different?)
  end

  def test_normalize_whitespace
    left = "# Heading\n\nParagraph text"
    right = "#  Heading  \n\n  Paragraph text  "

    result = @differ.compare(left, right)
    assert(result.equal?, "Should normalize whitespace differences")
  end

  def test_normalize_blank_lines
    left = "# Heading\n\nParagraph"
    right = "# Heading\n\n\n\nParagraph"

    result = @differ.compare(left, right)
    assert(result.equal?, "Should normalize multiple blank lines")
  end

  def test_normalize_list_markers
    left = "* Item 1\n* Item 2"
    right = "- Item 1\n+ Item 2"

    result = @differ.compare(left, right)
    assert(result.equal?, "Should normalize list markers to *")
  end

  def test_normalize_heading_spacing
    left = "# Heading"
    right = "#Heading"

    result = @differ.compare(left, right)
    assert(result.equal?, "Should normalize heading spacing")
  end

  def test_normalize_heading_trailing_hashes
    left = "# Heading"
    right = "# Heading #"

    result = @differ.compare(left, right)
    assert(result.equal?, "Should remove trailing # from headings")
  end

  def test_pretty_diff_output
    left = "# Heading 1\n\nParagraph"
    right = "# Heading 2\n\nParagraph"

    result = @differ.compare(left, right)
    diff_output = result.pretty_diff

    assert_match(/Heading 1/, diff_output)
    assert_match(/Heading 2/, diff_output)
  end

  def test_quick_equality_check
    left = "# Heading"
    right = "#  Heading  "

    assert(@differ.equal?(left, right), "Should have quick equality check")
  end

  def test_diff_method
    left = "Line 1"
    right = "Line 2"

    diff_output = @differ.diff(left, right)
    assert(!diff_output.empty?, "Should return diff output")
  end

  def test_empty_strings
    left = ""
    right = ""

    result = @differ.compare(left, right)
    assert(result.equal?)
  end

  def test_nil_handling
    left = nil
    right = ""

    result = @differ.compare(left, right)
    assert(result.equal?, "nil and empty string should be equivalent")
  end

  def test_complex_markdown_document
    left = <<~MD
      # Main Heading

      This is a paragraph with **bold** and *italic*.

      * List item 1
      * List item 2

      ## Section

      Another paragraph.
    MD

    right = <<~MD
      #  Main Heading

        This is a paragraph with **bold** and *italic*.

      - List item 1
      + List item 2

      ##Section

        Another paragraph.
    MD

    result = @differ.compare(left, right)
    assert(result.equal?, "Should handle complex documents with normalization")
  end

  def test_code_blocks_preserved
    left = <<~MD
      ```ruby
      def hello
        puts "world"
      end
      ```
    MD

    right = <<~MD
      ```ruby
      def hello
        puts "world"
      end
      ```
    MD

    result = @differ.compare(left, right)
    assert(result.equal?)
  end

  def test_disable_normalization_options
    differ = ReVIEW::AST::Diff::Markdown.new(
      ignore_whitespace: false,
      ignore_blank_lines: false,
      normalize_headings: false,
      normalize_lists: false
    )

    left = "# Heading"
    right = "#Heading"

    result = differ.compare(left, right)
    assert(!result.equal?, "Should not normalize when options disabled")
  end
end
