# frozen_string_literal: true

require_relative '../test_helper'
require 'review/ast/compiler'
require 'review/renderer/html_renderer'
require 'review/book'
require 'stringio'

# Test auto_id generation behavior for HeadlineNode and ColumnNode.
class TestAutoIdGeneration < Test::Unit::TestCase
  def setup
    @book = ReVIEW::Book::Base.new
    @book.config = ReVIEW::Configure.values
    @config = @book.config
    @compiler = ReVIEW::AST::Compiler.new

    ReVIEW::I18n.setup(@config['language'])
  end

  def test_nonum_headline_auto_id_generation
    content = <<~REVIEW
      = Chapter

      ===[nonum] First Unnumbered
      ===[nonum] Second Unnumbered
    REVIEW

    chapter = create_chapter(content)
    ast_root = @compiler.compile_to_ast(chapter)

    # Find nonum headlines
    headlines = find_all_nodes(ast_root, ReVIEW::AST::HeadlineNode)
    nonum_headlines = headlines.select(&:nonum?)

    assert_equal 2, nonum_headlines.size, 'Should have 2 nonum headlines'

    # Verify auto_id is generated for both
    assert_not_nil(nonum_headlines[0].auto_id, 'First nonum should have auto_id')
    assert_not_nil(nonum_headlines[1].auto_id, 'Second nonum should have auto_id')

    # Verify auto_id format: chapter_name_nonumN
    assert_match(/^test_nonum\d+$/, nonum_headlines[0].auto_id, 'First auto_id should match format')
    assert_match(/^test_nonum\d+$/, nonum_headlines[1].auto_id, 'Second auto_id should match format')

    # Verify auto_ids are different (sequential)
    assert_not_equal(nonum_headlines[0].auto_id, nonum_headlines[1].auto_id,
                     'Each nonum headline should have unique auto_id')
  end

  def test_notoc_headline_auto_id_generation
    content = <<~REVIEW
      = Chapter

      ===[notoc] First NotInTOC
      ===[notoc] Second NotInTOC
    REVIEW

    chapter = create_chapter(content)
    ast_root = @compiler.compile_to_ast(chapter)

    headlines = find_all_nodes(ast_root, ReVIEW::AST::HeadlineNode)
    notoc_headlines = headlines.select(&:notoc?)

    assert_equal 2, notoc_headlines.size
    assert_not_nil(notoc_headlines[0].auto_id)
    assert_not_nil(notoc_headlines[1].auto_id)
    assert_not_equal(notoc_headlines[0].auto_id, notoc_headlines[1].auto_id)
  end

  def test_nodisp_headline_auto_id_generation
    content = <<~REVIEW
      = Chapter

      ===[nodisp] Hidden Section
    REVIEW

    chapter = create_chapter(content)
    ast_root = @compiler.compile_to_ast(chapter)

    headlines = find_all_nodes(ast_root, ReVIEW::AST::HeadlineNode)
    nodisp_headline = headlines.find(&:nodisp?)

    assert_not_nil(nodisp_headline, 'Should find nodisp headline')
    assert_not_nil(nodisp_headline.auto_id, 'Nodisp headline should have auto_id')
    assert_match(/^test_nonum\d+$/, nodisp_headline.auto_id)
  end

  def test_headline_with_label_no_auto_id
    content = <<~REVIEW
      = Chapter

      ===[nonum]{custom-label} Labeled Headline
    REVIEW

    chapter = create_chapter(content)
    ast_root = @compiler.compile_to_ast(chapter)

    headlines = find_all_nodes(ast_root, ReVIEW::AST::HeadlineNode)
    labeled_headline = headlines.find { |h| h.label == 'custom-label' }

    assert_not_nil(labeled_headline, 'Should find labeled headline')
    # When label is provided, auto_id should still be nil (not needed)
    assert_nil(labeled_headline.auto_id, 'Labeled headline should not have auto_id')
  end

  def test_mixed_nonum_headlines_sequential_numbering
    content = <<~REVIEW
      = Chapter

      ===[nonum] First
      === Regular Section
      ===[nonum] Second
      ===[notoc] Third
    REVIEW

    chapter = create_chapter(content)
    ast_root = @compiler.compile_to_ast(chapter)

    headlines = find_all_nodes(ast_root, ReVIEW::AST::HeadlineNode)
    special_headlines = headlines.select { |h| h.nonum? || h.notoc? || h.nodisp? }

    # All special headlines should have auto_id
    assert_equal 3, special_headlines.size
    special_headlines.each do |h|
      assert_not_nil(h.auto_id, "Headline '#{h.caption}' should have auto_id")
    end

    # Extract numbers from auto_ids
    numbers = special_headlines.map { |h| h.auto_id.match(/\d+$/)[0].to_i }

    # Numbers should be sequential (1, 2, 3)
    assert_equal [1, 2, 3], numbers, 'Auto_id numbers should be sequential'
  end

  def test_column_auto_id_generation
    content = <<~REVIEW
      = Chapter

      ===[column] First Column

      Content

      ===[/column]

      ===[column] Second Column

      Content

      ===[/column]
    REVIEW

    chapter = create_chapter(content)
    ast_root = @compiler.compile_to_ast(chapter)

    columns = find_all_nodes(ast_root, ReVIEW::AST::ColumnNode)

    assert_equal 2, columns.size, 'Should have 2 columns'

    # Verify auto_id is generated for both
    assert_not_nil(columns[0].auto_id, 'First column should have auto_id')
    assert_not_nil(columns[1].auto_id, 'Second column should have auto_id')

    # Verify auto_id format: column-N
    assert_equal 'column-1', columns[0].auto_id, 'First column auto_id should be column-1'
    assert_equal 'column-2', columns[1].auto_id, 'Second column auto_id should be column-2'
  end

  def test_column_with_label_still_has_auto_id
    content = <<~REVIEW
      = Chapter

      ===[column]{custom-col} Labeled Column

      Content

      ===[/column]
    REVIEW

    chapter = create_chapter(content)
    ast_root = @compiler.compile_to_ast(chapter)

    columns = find_all_nodes(ast_root, ReVIEW::AST::ColumnNode)
    column = columns.first

    assert_not_nil(column, 'Should find column')
    assert_equal 'custom-col', column.label, 'Column should have label'
    # Columns ALWAYS get auto_id (used for anchor in HTML)
    assert_equal 'column-1', column.auto_id, 'Column should have auto_id even with label'
  end

  def test_html_renderer_uses_auto_id_for_nonum
    content = <<~REVIEW
      = Chapter

      ===[nonum] Unnumbered Section

      Content here.
    REVIEW

    chapter = create_chapter(content)
    chapter.generate_indexes
    @book.generate_indexes

    ast_root = @compiler.compile_to_ast(chapter)
    renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter)
    html = renderer.render_body(ast_root)

    # HTML should contain h3 with auto_id
    assert_match(/<h3 id="test_nonum1">/, html, 'Should use auto_id in HTML id attribute')
  end

  def test_html_renderer_uses_auto_id_for_column
    content = <<~REVIEW
      = Chapter

      ===[column] Test Column

      Column content.

      ===[/column]
    REVIEW

    chapter = create_chapter(content)
    chapter.generate_indexes
    @book.generate_indexes

    ast_root = @compiler.compile_to_ast(chapter)
    renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter)
    html = renderer.render_body(ast_root)

    # HTML should contain anchor with auto_id
    assert_match(/<a id="column-1">/, html, 'Should use auto_id in column anchor')
  end

  def test_html_renderer_multiple_nonum_unique_ids
    content = <<~REVIEW
      = Chapter

      ===[nonum] First

      ===[nonum] Second

      ===[nonum] Third
    REVIEW

    chapter = create_chapter(content)
    chapter.generate_indexes
    @book.generate_indexes

    ast_root = @compiler.compile_to_ast(chapter)
    renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter)
    html = renderer.render_body(ast_root)

    # Each should have unique ID
    assert_match(/<h3 id="test_nonum1">/, html)
    assert_match(/<h3 id="test_nonum2">/, html)
    assert_match(/<h3 id="test_nonum3">/, html)

    # Verify no duplicate IDs
    id_matches = html.scan(/id="test_nonum\d+"/)
    assert_equal 3, id_matches.size
    assert_equal 3, id_matches.uniq.size, 'All IDs should be unique'
  end

  private

  def create_chapter(content)
    ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
  end

  # Recursively find all nodes of a specific type in the AST
  def find_all_nodes(node, node_class, results = [])
    results << node if node.is_a?(node_class)
    node.children.each { |child| find_all_nodes(child, node_class, results) } if node.respond_to?(:children)
    results
  end
end
