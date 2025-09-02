# frozen_string_literal: true

require_relative '../test_helper'
require 'review/ast/markdown_compiler'
require 'review/ast/markdown_html_node'
require 'review/renderer/html_renderer'
require 'review/renderer/latex_renderer'
require 'review/book'
require 'review/book/chapter'

class TestMarkdownColumn < Test::Unit::TestCase
  include ReVIEW

  def setup
    @config = ReVIEW::Configure.values
    @config['language'] = 'ja'
    @book = ReVIEW::Book::Base.new('.')
    @book.config = @config

    # Initialize I18n for proper rendering
    ReVIEW::I18n.setup('ja')

    @compiler = ReVIEW::AST::MarkdownCompiler.new
  end

  def test_column_detection_basic
    content = <<~MARKDOWN
      # Chapter

      <!-- column: Test Column -->
      Column content
      <!-- /column -->
    MARKDOWN

    chapter = create_chapter(content)
    ast_root = @compiler.compile_to_ast(chapter)

    columns = find_columns(ast_root)
    assert_equal 1, columns.length
    assert_equal 'Test Column', extract_column_title(columns.first)
  end

  def test_column_detection_no_title
    content = <<~MARKDOWN
      # Chapter

      <!-- column -->
      Column content
      <!-- /column -->
    MARKDOWN

    chapter = create_chapter(content)
    ast_root = @compiler.compile_to_ast(chapter)

    columns = find_columns(ast_root)
    assert_equal 1, columns.length
    assert_nil(extract_column_title(columns.first))
  end

  def test_column_with_markdown_content
    content = <<~MARKDOWN
      # Chapter

      <!-- column: Rich Column -->

      This is **bold** and *italic* text.

      - List item 1
      - List item 2

      ```python
      def example():
          print("Hello")
      ```

      <!-- /column -->
    MARKDOWN

    chapter = create_chapter(content)
    ast_root = @compiler.compile_to_ast(chapter)

    columns = find_columns(ast_root)
    assert_equal 1, columns.length

    column = columns.first
    assert_equal 3, column.children.length # paragraph, list, code block

    # Check that inline formatting is preserved
    paragraph = column.children.first
    assert_instance_of(AST::ParagraphNode, paragraph)
  end

  def test_multiple_columns
    content = <<~MARKDOWN
      # Chapter

      <!-- column: First Column -->
      First content
      <!-- /column -->

      Normal paragraph

      <!-- column: Second Column -->
      Second content
      <!-- /column -->
    MARKDOWN

    chapter = create_chapter(content)
    ast_root = @compiler.compile_to_ast(chapter)

    columns = find_columns(ast_root)
    assert_equal 2, columns.length
    assert_equal 'First Column', extract_column_title(columns.first)
    assert_equal 'Second Column', extract_column_title(columns.last)
  end

  def test_html_rendering
    content = <<~MARKDOWN
      # Chapter

      <!-- column: HTML Test -->
      Column **content**
      <!-- /column -->
    MARKDOWN

    chapter = create_chapter(content)
    ast_root = @compiler.compile_to_ast(chapter)
    renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter)
    html_output = renderer.render(ast_root)

    assert_match(/<div class="column">/, html_output)
    assert_match(%r{<div class="column-header">HTML Test</div>}, html_output)
    assert_match(/Column.*content/, html_output)
  end

  def test_latex_rendering
    content = <<~MARKDOWN
      # Chapter

      <!-- column: LaTeX Test -->
      Column content
      <!-- /column -->
    MARKDOWN

    chapter = create_chapter(content)
    ast_root = @compiler.compile_to_ast(chapter)
    renderer = ReVIEW::Renderer::LatexRenderer.new(chapter)
    latex_output = renderer.render(ast_root)

    assert_match(/\\begin\{reviewcolumn\}\[LaTeX Test/, latex_output)
    assert_match(/\\end\{reviewcolumn\}/, latex_output)
    assert_match(/Column content/, latex_output)
  end

  def test_markdown_html_node_column_detection
    # Test MarkdownHtmlNode utility methods
    start_node = AST::MarkdownHtmlNode.new(
      location: nil,
      html_content: '<!-- column: Test Title -->',
      html_type: :comment
    )

    assert_true(start_node.column_start?)
    assert_false(start_node.column_end?)
    assert_equal 'Test Title', start_node.column_title

    end_node = AST::MarkdownHtmlNode.new(
      location: nil,
      html_content: '<!-- /column -->',
      html_type: :comment
    )

    assert_false(end_node.column_start?)
    assert_true(end_node.column_end?)
    assert_nil(end_node.column_title)
  end

  def test_mixed_syntax_heading_start
    content = <<~MARKDOWN
      # Chapter

      ### [column] Test Column
      Column content
      <!-- /column -->
    MARKDOWN

    chapter = create_chapter(content)
    ast_root = @compiler.compile_to_ast(chapter)

    columns = find_columns(ast_root)
    assert_equal 1, columns.length
    assert_equal 'Test Column', extract_column_title(columns.first)
  end

  def test_mixed_syntax_heading_no_title
    content = <<~MARKDOWN
      # Chapter

      ### [column]
      Column content
      <!-- /column -->
    MARKDOWN

    chapter = create_chapter(content)
    ast_root = @compiler.compile_to_ast(chapter)

    columns = find_columns(ast_root)
    assert_equal 1, columns.length
    assert_nil(extract_column_title(columns.first))
  end

  def test_mixed_syntax_with_markdown_content
    content = <<~MARKDOWN
      # Chapter

      ### [column] Rich Mixed Column

      This is **bold** and *italic* text.

      - List item 1
      - List item 2

      ```python
      def example():
          print("Hello")
      ```

      <!-- /column -->
    MARKDOWN

    chapter = create_chapter(content)
    ast_root = @compiler.compile_to_ast(chapter)

    columns = find_columns(ast_root)
    assert_equal 1, columns.length

    column = columns.first
    assert_equal 'Rich Mixed Column', extract_column_title(column)
    assert_equal 3, column.children.length # paragraph, list, code block
  end

  def test_regular_headings_not_columns
    content = <<~MARKDOWN
      # Chapter

      ### Regular Heading
      Regular content

      #### Another Heading
      More content
    MARKDOWN

    chapter = create_chapter(content)
    ast_root = @compiler.compile_to_ast(chapter)

    columns = find_columns(ast_root)
    assert_equal 0, columns.length
  end

  def test_code_spans_in_columns
    content = <<~MARKDOWN
      # Chapter

      ### [column] Code Test
      This column has `inline code` and more `code spans`.
      <!-- /column -->
    MARKDOWN

    chapter = create_chapter(content)
    ast_root = @compiler.compile_to_ast(chapter)

    # Test HTML rendering
    html_renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter)
    html_output = html_renderer.render(ast_root)
    assert_match(%r{<code[^>]*>inline code</code>}, html_output)
    assert_match(%r{<code[^>]*>code spans</code>}, html_output)

    # Test LaTeX rendering
    latex_renderer = ReVIEW::Renderer::LatexRenderer.new(chapter)
    latex_output = latex_renderer.render(ast_root)
    assert_match(/\\reviewcode\{inline code\}/, latex_output)
    assert_match(/\\reviewcode\{code spans\}/, latex_output)
  end

  def test_standalone_images
    content = <<~MARKDOWN
      # Chapter

      ![Sample Image](sample1)

      Regular paragraph with text.

      ![Another Image](sample2)
    MARKDOWN

    chapter = create_chapter(content)
    ast_root = @compiler.compile_to_ast(chapter)

    # Find ImageNodes
    images = find_images(ast_root)
    assert_equal 2, images.length

    # Check first image
    first_image = images.first
    assert_equal 'sample1', first_image.id
    assert_not_nil(first_image.caption)
    assert_equal 'Sample Image', extract_image_caption(first_image)

    # Check second image
    second_image = images.last
    assert_equal 'sample2', second_image.id
    assert_not_nil(second_image.caption)
    assert_equal 'Another Image', extract_image_caption(second_image)

    # Test LaTeX rendering
    latex_renderer = ReVIEW::Renderer::LatexRenderer.new(chapter)
    latex_output = latex_renderer.render(ast_root)
    assert_match(/\\reviewimagecaption\{Sample Image\}/, latex_output)
    assert_match(/\\reviewimagecaption\{Another Image\}/, latex_output)
  end

  def test_unmatched_column_end
    content = <<~MARKDOWN
      # Chapter

      Normal content
      <!-- /column -->
    MARKDOWN

    chapter = create_chapter(content)
    # Should not raise an error, just ignore unmatched end
    assert_nothing_raised do
      @compiler.compile_to_ast(chapter)
    end
  end

  private

  def create_chapter(content)
    ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.md', StringIO.new(content))
  end

  def find_columns(node)
    columns = []
    if node.is_a?(AST::ColumnNode)
      columns << node
    end

    if node.respond_to?(:children) && node.children
      node.children.each { |child| columns.concat(find_columns(child)) }
    end

    columns
  end

  def extract_column_title(column_node)
    return nil unless column_node.caption

    first_child = column_node.caption.children.first
    first_child&.content
  end

  def find_images(node)
    images = []
    if node.is_a?(AST::ImageNode)
      images << node
    end

    if node.respond_to?(:children) && node.children
      node.children.each { |child| images.concat(find_images(child)) }
    end

    images
  end

  def extract_image_caption(image_node)
    return nil unless image_node.caption

    first_child = image_node.caption.children.first
    first_child&.content
  end
end
