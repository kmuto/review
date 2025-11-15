# frozen_string_literal: true

require_relative '../test_helper'
require 'review/ast'
require 'review/ast/compiler'
require 'review/renderer/markdown_renderer'
require 'review/ast/diff/markdown'
require 'review/configure'
require 'review/book'
require 'review/book/chapter'

return unless Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('3.1.0')

# Fixture-based tests for MarkdownRenderer
#
# These tests compare the output of MarkdownRenderer with pre-generated
# Markdown fixtures from sample Re:VIEW documents.
#
# To regenerate fixtures:
#   bundle exec ruby test/fixtures/generate_markdown_fixtures.rb
class TestMarkdownRendererFixtures < Test::Unit::TestCase
  class ChapterNotInCatalogError < StandardError; end

  def setup
    @config = ReVIEW::Configure.values
    @config['secnolevel'] = 2
    @config['language'] = 'ja'
    @book = ReVIEW::Book::Base.new(config: @config)
    @log_io = StringIO.new
    ReVIEW.logger = ReVIEW::Logger.new(@log_io)
    ReVIEW::I18n.setup(@config['language'])

    @markdown_diff = ReVIEW::AST::Diff::Markdown.new(
      ignore_whitespace: true,
      ignore_blank_lines: true,
      ignore_paragraph_breaks: true,
      normalize_headings: true,
      normalize_lists: true
    )
  end

  # Helper method to render Re:VIEW file to Markdown
  # Loads the entire book to enable proper reference resolution
  def render_review_file(file_path)
    basename = File.basename(file_path, '.re')
    book_dir = File.dirname(file_path)

    # Load book structure from catalog.yml
    config = ReVIEW::Configure.values
    config['secnolevel'] = 2
    config['language'] = 'ja'
    ReVIEW::I18n.setup(config['language'])

    book = ReVIEW::Book::Base.load(book_dir)
    book.config = config
    book.generate_indexes

    # Find the chapter by basename (including parts)
    chapter = book.chapters.find { |ch| ch.id == basename }

    # If not found in chapters, look for part files
    unless chapter
      book.parts.each do |part|
        next unless part.id == basename

        # For part files, create a pseudo-chapter
        content = File.read(file_path, encoding: 'UTF-8')
        chapter = ReVIEW::Book::Chapter.new(book, part.number, basename, file_path, StringIO.new(content))
        break
      end
    end

    raise ChapterNotInCatalogError, "#{basename} not found in catalog.yml" unless chapter

    ast = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast)
  end

  # Helper method to compare rendered output with fixture
  def assert_markdown_matches_fixture(review_file, fixture_file, message = nil)
    # Render the Re:VIEW file
    begin
      actual = render_review_file(review_file)
    rescue ChapterNotInCatalogError => e
      omit(e.message)
    end

    # Read the expected fixture
    expected = File.read(fixture_file, encoding: 'UTF-8')

    # Compare using Markdown diff
    result = @markdown_diff.compare(expected, actual)

    # Build error message if different
    unless result.equal?
      diff_output = result.pretty_diff
      error_msg = message || "Markdown output does not match fixture for #{File.basename(review_file)}"
      error_msg += "\n\nDifferences:\n#{diff_output}"
      error_msg += "\n\nExpected fixture: #{fixture_file}"
      error_msg += "\n\nIf this is intentional, regenerate fixtures with:"
      error_msg += "\n  bundle exec ruby test/fixtures/generate_markdown_fixtures.rb"

      flunk(error_msg)
    end

    assert(result.equal?, 'Markdown output should match fixture')
  end

  # ===== syntax-book Tests =====

  def test_syntax_book_ch01
    review_file = File.join(__dir__, '../../samples/syntax-book/ch01.re')
    fixture_file = File.join(__dir__, '../fixtures/markdown/syntax-book/ch01.md')

    skip("Fixture not found: #{fixture_file}") unless File.exist?(fixture_file)
    skip("Review file not found: #{review_file}") unless File.exist?(review_file)

    assert_markdown_matches_fixture(review_file, fixture_file, 'ch01.re should match fixture')
  end

  def test_syntax_book_ch02
    review_file = File.join(__dir__, '../../samples/syntax-book/ch02.re')
    fixture_file = File.join(__dir__, '../fixtures/markdown/syntax-book/ch02.md')

    skip("Fixture not found: #{fixture_file}") unless File.exist?(fixture_file)
    skip("Review file not found: #{review_file}") unless File.exist?(review_file)

    assert_markdown_matches_fixture(review_file, fixture_file, 'ch02.re should match fixture')
  end

  def test_syntax_book_ch03
    review_file = File.join(__dir__, '../../samples/syntax-book/ch03.re')
    fixture_file = File.join(__dir__, '../fixtures/markdown/syntax-book/ch03.md')

    skip("Fixture not found: #{fixture_file}") unless File.exist?(fixture_file)
    skip("Review file not found: #{review_file}") unless File.exist?(review_file)

    assert_markdown_matches_fixture(review_file, fixture_file, 'ch03.re should match fixture')
  end

  def test_syntax_book_pre01
    review_file = File.join(__dir__, '../../samples/syntax-book/pre01.re')
    fixture_file = File.join(__dir__, '../fixtures/markdown/syntax-book/pre01.md')

    skip("Fixture not found: #{fixture_file}") unless File.exist?(fixture_file)
    skip("Review file not found: #{review_file}") unless File.exist?(review_file)

    assert_markdown_matches_fixture(review_file, fixture_file, 'pre01.re should match fixture')
  end

  def test_syntax_book_appA
    review_file = File.join(__dir__, '../../samples/syntax-book/appA.re')
    fixture_file = File.join(__dir__, '../fixtures/markdown/syntax-book/appA.md')

    skip("Fixture not found: #{fixture_file}") unless File.exist?(fixture_file)
    skip("Review file not found: #{review_file}") unless File.exist?(review_file)

    assert_markdown_matches_fixture(review_file, fixture_file, 'appA.re should match fixture')
  end

  def test_syntax_book_part2
    review_file = File.join(__dir__, '../../samples/syntax-book/part2.re')
    fixture_file = File.join(__dir__, '../fixtures/markdown/syntax-book/part2.md')

    skip("Fixture not found: #{fixture_file}") unless File.exist?(fixture_file)
    skip("Review file not found: #{review_file}") unless File.exist?(review_file)

    assert_markdown_matches_fixture(review_file, fixture_file, 'part2.re should match fixture')
  end

  def test_syntax_book_bib
    review_file = File.join(__dir__, '../../samples/syntax-book/bib.re')
    fixture_file = File.join(__dir__, '../fixtures/markdown/syntax-book/bib.md')

    skip("Fixture not found: #{fixture_file}") unless File.exist?(fixture_file)
    skip("Review file not found: #{review_file}") unless File.exist?(review_file)

    assert_markdown_matches_fixture(review_file, fixture_file, 'bib.re should match fixture')
  end

  # ===== debug-book Tests =====

  def test_debug_book_edge_cases
    review_file = File.join(__dir__, '../../samples/debug-book/edge_cases_test.re')
    fixture_file = File.join(__dir__, '../fixtures/markdown/debug-book/edge_cases_test.md')

    skip("Fixture not found: #{fixture_file}") unless File.exist?(fixture_file)
    skip("Review file not found: #{review_file}") unless File.exist?(review_file)

    assert_markdown_matches_fixture(review_file, fixture_file, 'edge_cases_test.re should match fixture')
  end

  def test_debug_book_comprehensive
    review_file = File.join(__dir__, '../../samples/debug-book/comprehensive.re')
    fixture_file = File.join(__dir__, '../fixtures/markdown/debug-book/comprehensive.md')

    skip("Fixture not found: #{fixture_file}") unless File.exist?(fixture_file)
    skip("Review file not found: #{review_file}") unless File.exist?(review_file)

    assert_markdown_matches_fixture(review_file, fixture_file, 'comprehensive.re should match fixture')
  end

  def test_debug_book_multicontent
    review_file = File.join(__dir__, '../../samples/debug-book/multicontent_test.re')
    fixture_file = File.join(__dir__, '../fixtures/markdown/debug-book/multicontent_test.md')

    skip("Fixture not found: #{fixture_file}") unless File.exist?(fixture_file)
    skip("Review file not found: #{review_file}") unless File.exist?(review_file)

    assert_markdown_matches_fixture(review_file, fixture_file, 'multicontent_test.re should match fixture')
  end

  def test_debug_book_advanced_features
    review_file = File.join(__dir__, '../../samples/debug-book/advanced_features.re')
    fixture_file = File.join(__dir__, '../fixtures/markdown/debug-book/advanced_features.md')

    skip("Fixture not found: #{fixture_file}") unless File.exist?(fixture_file)
    skip("Review file not found: #{review_file}") unless File.exist?(review_file)

    assert_markdown_matches_fixture(review_file, fixture_file, 'advanced_features.re should match fixture')
  end

  def test_debug_book_extreme_features
    review_file = File.join(__dir__, '../../samples/debug-book/extreme_features.re')
    fixture_file = File.join(__dir__, '../fixtures/markdown/debug-book/extreme_features.md')

    skip("Fixture not found: #{fixture_file}") unless File.exist?(fixture_file)
    skip("Review file not found: #{review_file}") unless File.exist?(review_file)

    assert_markdown_matches_fixture(review_file, fixture_file, 'extreme_features.re should match fixture')
  end

  # Test that the Markdown diff tool works correctly
  def test_markdown_diff_equal
    markdown1 = "# Heading\n\nParagraph text."
    markdown2 = "#  Heading  \n\n  Paragraph text.  "

    assert(@markdown_diff.equal?(markdown1, markdown2), 'Should normalize whitespace differences')
  end

  def test_markdown_diff_different
    markdown1 = "# Heading 1\n\nParagraph text."
    markdown2 = "# Heading 2\n\nParagraph text."

    assert(!@markdown_diff.equal?(markdown1, markdown2), 'Should detect content differences')
  end

  def test_markdown_diff_list_normalization
    markdown1 = "* Item 1\n* Item 2"
    markdown2 = "- Item 1\n+ Item 2"

    assert(@markdown_diff.equal?(markdown1, markdown2), 'Should normalize list markers')
  end

  def test_markdown_diff_heading_normalization
    markdown1 = '# Heading'
    markdown2 = '#Heading'

    assert(@markdown_diff.equal?(markdown1, markdown2), 'Should normalize heading spacing')
  end
end
