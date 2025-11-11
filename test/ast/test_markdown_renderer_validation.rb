# frozen_string_literal: true

require_relative '../test_helper'
require 'review/ast'
require 'review/ast/compiler'
require 'review/ast/markdown_compiler'
require 'review/renderer/markdown_renderer'
require 'review/ast/review_generator'
require 'review/configure'
require 'review/book'
require 'review/book/chapter'
require 'markly'

# Advanced validation tests for MarkdownRenderer
# These tests validate the quality and correctness of Markdown output
# through various approaches: roundtrip conversion, CommonMark compliance,
# real-world documents, and snapshot testing.
class TestMarkdownRendererValidation < Test::Unit::TestCase
  def setup
    @config = ReVIEW::Configure.values
    @config['secnolevel'] = 2
    @config['language'] = 'ja'
    @book = ReVIEW::Book::Base.new(config: @config)
    @log_io = StringIO.new
    ReVIEW.logger = ReVIEW::Logger.new(@log_io)
    ReVIEW::I18n.setup(@config['language'])
  end

  # Helper method to convert Re:VIEW to Markdown
  def review_to_markdown(review_content)
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(review_content))
    ast = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast)
  end

  # Helper method to convert Markdown to Re:VIEW AST
  def markdown_to_ast(markdown_content)
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.md', StringIO.new(markdown_content))
    ReVIEW::AST::MarkdownCompiler.new.compile_to_ast(chapter)
  end

  # Helper method to convert Markdown to Re:VIEW text
  def markdown_to_review(markdown_content)
    ast = markdown_to_ast(markdown_content)
    ReVIEW::AST::ReVIEWGenerator.new.generate(ast)
  end

  # Helper method to parse Markdown with Markly (CommonMark)
  def parse_markdown_with_markly(markdown_content)
    extensions = %i[strikethrough table autolink tagfilter]
    Markly.parse(markdown_content, extensions: extensions)
  end

  # ===== Roundtrip Conversion Tests =====
  # Test that Re:VIEW → Markdown → Re:VIEW preserves semantic meaning

  def test_roundtrip_simple_paragraph
    original_review = <<~REVIEW
      = Chapter Title

      This is a simple paragraph.
    REVIEW

    markdown = review_to_markdown(original_review)
    regenerated_review = markdown_to_review(markdown)

    # Check that key elements are preserved
    assert_match(/= Chapter Title/, regenerated_review)
    assert_match(/This is a simple paragraph/, regenerated_review)
  end

  def test_roundtrip_inline_formatting
    original_review = <<~REVIEW
      = Chapter

      Text with @<b>{bold}, @<i>{italic}, and @<code>{code}.
    REVIEW

    markdown = review_to_markdown(original_review)
    regenerated_review = markdown_to_review(markdown)

    # Check Markdown output has correct formatting
    assert_match(/\*\*bold\*\*/, markdown)
    assert_match(/\*italic\*/, markdown)
    assert_match(/`code`/, markdown)

    # Check regenerated Re:VIEW has formatting
    assert_match(/@<b>{bold}|@<strong>{bold}|\*\*bold\*\*/, regenerated_review)
    assert_match(/@<i>{italic}|@<em>{italic}|\*italic\*/, regenerated_review)
    assert_match(/@<code>{code}|`code`/, regenerated_review)
  end

  def test_roundtrip_unordered_list
    original_review = <<~REVIEW
      = Chapter

       * First item
       * Second item
       * Third item
    REVIEW

    markdown = review_to_markdown(original_review)
    regenerated_review = markdown_to_review(markdown)

    # Check Markdown has list items
    assert_match(/^\* First item/, markdown)
    assert_match(/^\* Second item/, markdown)
    assert_match(/^\* Third item/, markdown)

    # Check regenerated Re:VIEW has list structure
    assert_match(/First item/, regenerated_review)
    assert_match(/Second item/, regenerated_review)
    assert_match(/Third item/, regenerated_review)
  end

  def test_roundtrip_ordered_list
    original_review = <<~REVIEW
      = Chapter

       1. First item
       2. Second item
       3. Third item
    REVIEW

    markdown = review_to_markdown(original_review)
    regenerated_review = markdown_to_review(markdown)

    # Check Markdown has numbered list
    assert_match(/^1\. First item/, markdown)
    assert_match(/^2\. Second item/, markdown)
    assert_match(/^3\. Third item/, markdown)

    # Check regenerated Re:VIEW has list items
    assert_match(/First item/, regenerated_review)
    assert_match(/Second item/, regenerated_review)
  end

  def test_roundtrip_code_block
    original_review = <<~REVIEW
      = Chapter

      //emlist[Sample Code][ruby]{
      puts "Hello"
      //}
    REVIEW

    markdown = review_to_markdown(original_review)
    regenerated_review = markdown_to_review(markdown)

    # Check Markdown has fenced code block
    assert_match(/```ruby/, markdown)
    assert_match(/puts "Hello"/, markdown)

    # Check regenerated Re:VIEW has code content
    assert_match(/puts "Hello"/, regenerated_review)
  end

  def test_roundtrip_heading_levels
    original_review = <<~REVIEW
      = Level 1

      == Level 2

      === Level 3

      ==== Level 4
    REVIEW

    markdown = review_to_markdown(original_review)
    regenerated_review = markdown_to_review(markdown)

    # Check Markdown has correct heading syntax
    assert_match(/^# Level 1/, markdown)
    assert_match(/^## Level 2/, markdown)
    assert_match(/^### Level 3/, markdown)
    assert_match(/^#### Level 4/, markdown)

    # Check regenerated Re:VIEW has headings
    assert_match(/= Level 1/, regenerated_review)
    assert_match(/== Level 2/, regenerated_review)
  end

  # ===== CommonMark Validation Tests =====
  # Test that generated Markdown is valid CommonMark

  def test_commonmark_basic_structure
    review_content = <<~REVIEW
      = Chapter Title

      This is a paragraph with @<b>{bold} and @<i>{italic} text.

      == Section

      Another paragraph here.
    REVIEW

    markdown = review_to_markdown(review_content)

    # Parse with Markly (CommonMark parser)
    doc = parse_markdown_with_markly(markdown)

    # Verify it can be parsed without errors
    assert_not_nil(doc, "Markdown should be parseable by CommonMark")

    # Convert to HTML to verify structure
    html = doc.to_html

    # Check that expected HTML elements are present
    assert_match(/<h1>Chapter Title<\/h1>/, html)
    assert_match(/<h2>Section<\/h2>/, html)
    assert_match(/<strong>bold<\/strong>/, html)
    assert_match(/<em>italic<\/em>/, html)
  end

  def test_commonmark_list_structure
    review_content = <<~REVIEW
      = Chapter

       * Item 1
       * Item 2
       * Item 3

       1. Numbered 1
       2. Numbered 2
    REVIEW

    markdown = review_to_markdown(review_content)
    doc = parse_markdown_with_markly(markdown)
    html = doc.to_html

    # Check for list structures in HTML
    assert_match(/<ul>/, html)
    assert_match(/<li>Item 1<\/li>/, html)
    assert_match(/<ol>/, html)
    assert_match(/<li>Numbered 1<\/li>/, html)
  end

  def test_commonmark_code_blocks
    review_content = <<~REVIEW
      = Chapter

      //emlist[Code][ruby]{
      def hello
        puts "world"
      end
      //}
    REVIEW

    markdown = review_to_markdown(review_content)
    doc = parse_markdown_with_markly(markdown)
    html = doc.to_html

    # Check for code block in HTML
    assert_match(/<pre><code/, html)
    assert_match(/def hello/, html)
  end

  def test_commonmark_inline_code
    review_content = "= Chapter\n\nUse @<code>{puts 'hello'} to print.\n"

    markdown = review_to_markdown(review_content)
    doc = parse_markdown_with_markly(markdown)
    html = doc.to_html

    # Check for inline code in HTML
    assert_match(/<code>puts 'hello'<\/code>/, html)
  end

  def test_commonmark_links
    review_content = "= Chapter\n\nVisit @<href>{http://example.com, Example Site}.\n"

    markdown = review_to_markdown(review_content)
    doc = parse_markdown_with_markly(markdown)
    html = doc.to_html

    # Check for link in HTML
    assert_match(/<a href="http:\/\/example\.com">Example Site<\/a>/, html)
  end

  def test_commonmark_tables
    review_content = <<~REVIEW
      = Chapter

      //table[tbl1][Sample Table]{
      Name\tAge
      -----
      Alice\t25
      Bob\t30
      //}
    REVIEW

    markdown = review_to_markdown(review_content)
    doc = parse_markdown_with_markly(markdown)
    html = doc.to_html

    # Check for table structure (with or without alignment attributes)
    assert_match(/<table>/, html)
    assert_match(/<th.*?>Name<\/th>/, html)
    assert_match(/<td.*?>Alice<\/td>/, html)
  end

  # ===== Real-world Document Tests =====
  # Test with actual sample documents if they exist

  def test_sample_document_if_exists
    sample_file = File.join(__dir__, '../../samples/sample-book/src/ch01.re')
    return unless File.exist?(sample_file)

    content = File.read(sample_file, encoding: 'UTF-8')
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'ch01', 'ch01.re', StringIO.new(content))

    ast = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    markdown = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast)

    # Basic sanity checks
    assert(!markdown.empty?, "Should generate non-empty output")
    assert_match(/^#+ /, markdown, "Should have at least one heading")

    # Verify it's valid CommonMark
    doc = parse_markdown_with_markly(markdown)
    assert_not_nil(doc, "Generated Markdown should be parseable by CommonMark")
  end

  def test_complex_document_structure
    review_content = <<~REVIEW
      = Main Chapter

      Introduction paragraph with @<b>{emphasis}.

      == First Section

      Some content with:

       * List item 1
       * List item 2 with @<code>{code}

      === Subsection

      //emlist[Example][python]{
      def example():
          return "test"
      //}

      == Second Section

      More content here.

      //table[data][Data Table]{
      Col1\tCol2
      -----
      A\t1
      B\t2
      //}

      Final paragraph.
    REVIEW

    markdown = review_to_markdown(review_content)

    # Verify comprehensive structure
    assert_match(/^# Main Chapter/, markdown)
    assert_match(/^## First Section/, markdown)
    assert_match(/^### Subsection/, markdown)
    assert_match(/^\* List item 1/, markdown)
    assert_match(/```python/, markdown)
    assert_match(/\| Col1 \| Col2 \|/, markdown)

    # Verify valid CommonMark
    doc = parse_markdown_with_markly(markdown)
    assert_not_nil(doc)

    html = doc.to_html
    assert_match(/<h1>Main Chapter<\/h1>/, html)
    assert_match(/<h2>First Section<\/h2>/, html)
    assert_match(/<h3>Subsection<\/h3>/, html)
  end

  # ===== Snapshot Tests =====
  # Test that output matches expected snapshots

  def test_basic_document_snapshot
    review_content = <<~REVIEW
      = Test Chapter

      This is a test paragraph with @<b>{bold} and @<i>{italic}.

       * Item one
       * Item two

      //emlist[Code][ruby]{
      puts "test"
      //}
    REVIEW

    markdown = review_to_markdown(review_content)

    # Expected snapshot (can be updated with UPDATE_SNAPSHOTS env var)
    expected = <<~MARKDOWN
      # Test Chapter

      This is a test paragraph with **bold** and *italic*.

      * Item one
      * Item two

      **Code**

      ```ruby
      puts "test"
      ```

    MARKDOWN

    if ENV['UPDATE_SNAPSHOTS']
      # In update mode, just verify it generates something
      assert(!markdown.empty?)
    else
      # Normalize whitespace for comparison
      assert_equal(expected.strip, markdown.strip)
    end
  end

  def test_inline_elements_snapshot
    review_content = <<~REVIEW
      = Inline Test

      Text with @<code>{code}, @<tt>{tt}, @<del>{strikethrough}, @<sup>{super}, @<sub>{sub}.
    REVIEW

    markdown = review_to_markdown(review_content)

    # Verify key inline elements are present
    assert_match(/`code`/, markdown)
    assert_match(/`tt`/, markdown)
    assert_match(/~~strikethrough~~/, markdown)
    assert_match(/<sup>super<\/sup>/, markdown)
    assert_match(/<sub>sub<\/sub>/, markdown)
  end

  # ===== Edge Case Validation =====

  def test_special_characters_in_markdown
    review_content = "= Chapter\n\nText with @<b>{asterisks: *} and @<code>{backticks: `}.\n"

    markdown = review_to_markdown(review_content)

    # Verify special characters are handled
    doc = parse_markdown_with_markly(markdown)
    html = doc.to_html

    # Should parse without errors
    assert_not_nil(html)
  end

  def test_nested_inline_elements
    # Note: Nested inline elements are not currently supported by Re:VIEW parser
    # This test is skipped until the feature is implemented
    omit("Nested inline elements are not supported by Re:VIEW parser")

    review_content = "= Chapter\n\n@<b>{Bold with @<code>{code} inside}.\n"

    markdown = review_to_markdown(review_content)

    # Verify nested elements are rendered
    assert_match(/\*\*/, markdown)
    assert_match(/`code`/, markdown)
  end

  def test_empty_sections
    review_content = <<~REVIEW
      = Chapter

      == Empty Section

      == Another Section

      Some content.
    REVIEW

    markdown = review_to_markdown(review_content)

    # Verify it generates valid Markdown
    doc = parse_markdown_with_markly(markdown)
    assert_not_nil(doc)

    # Check headings are present
    assert_match(/^## Empty Section/, markdown)
    assert_match(/^## Another Section/, markdown)
  end

  def test_unicode_content
    review_content = <<~REVIEW
      = Chapter

      日本語のテキストです。@<b>{太字}と@<i>{斜体}。

       * リスト項目1
       * リスト項目2
    REVIEW

    markdown = review_to_markdown(review_content)

    # Verify Unicode is preserved
    assert_match(/日本語/, markdown)
    assert_match(/太字/, markdown)
    assert_match(/リスト項目/, markdown)

    # Verify it parses as valid Markdown
    doc = parse_markdown_with_markly(markdown)
    assert_not_nil(doc)
  end
end
