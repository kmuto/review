# frozen_string_literal: true

require_relative '../test_helper'
require 'review/ast'
require 'review/ast/compiler'
require 'review/ast/review_generator'
require 'review/book'
require 'review/book/chapter'

class TestColumnSections < Test::Unit::TestCase
  def setup
    @config = ReVIEW::Configure.values
    @book = ReVIEW::Book::Base.new(config: @config)
    @chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test_chapter', 'test_chapter.re', StringIO.new)
  end

  def test_column_section
    source = <<~EOS
      = Chapter Title

      Regular paragraph content.

      ==[column] Column Title

      This is content inside a column.

      Another paragraph in the column.

      == Regular Section

      Back to regular content.
    EOS

    @chapter.content = source
    ast_compiler = ReVIEW::AST::Compiler.new
    ast_root = ast_compiler.compile_to_ast(@chapter)

    # Find column node
    column_node = find_node_by_type(ast_root, ReVIEW::AST::ColumnNode)
    assert_not_nil(column_node)
    assert_equal(2, column_node.level)
    assert_equal(:column, column_node.column_type)

    # Check caption
    assert_not_nil(column_node.caption_text)
    assert_equal('Column Title', column_node.caption_text)

    # Check that column has content as children
    assert(column_node.children.any?, 'Column should have content as children')

    # Test round-trip conversion
    generator = ReVIEW::AST::ReVIEWGenerator.new
    result = generator.generate(ast_root)
    assert_include(result, '==[column] Column Title')
    assert_include(result, 'This is content inside a column.')
    assert_include(result, 'Another paragraph in the column.')
  end

  def test_column_with_label
    source = <<~EOS
      = Chapter Title

      ==[column]{col1} Column with Label

      Content of labeled column.
    EOS

    @chapter.content = source
    ast_compiler = ReVIEW::AST::Compiler.new
    ast_root = ast_compiler.compile_to_ast(@chapter)

    # Find column node
    column_node = find_node_by_type(ast_root, ReVIEW::AST::ColumnNode)
    assert_not_nil(column_node)
    assert_equal('col1', column_node.label)
    assert_equal('Column with Label', column_node.caption_text)

    # Test round-trip conversion
    generator = ReVIEW::AST::ReVIEWGenerator.new
    result = generator.generate(ast_root)
    assert_include(result, '==[column] Column with Label')
  end

  def test_nested_column_levels
    source = <<~EOS
      = Chapter Title

      ==[column] Level 2 Column

      Content in level 2 column.

      ===[column] Level 3 Column

      Content in level 3 column.
    EOS

    @chapter.content = source
    ast_compiler = ReVIEW::AST::Compiler.new
    ast_root = ast_compiler.compile_to_ast(@chapter)

    # Find column nodes
    column_nodes = find_all_nodes_by_type(ast_root, ReVIEW::AST::ColumnNode)
    assert_equal(2, column_nodes.length)

    level2_column = column_nodes.find { |n| n.level == 2 }
    level3_column = column_nodes.find { |n| n.level == 3 }

    assert_not_nil(level2_column)
    assert_equal('Level 2 Column', level2_column.caption_text)

    assert_not_nil(level3_column)
    assert_equal('Level 3 Column', level3_column.caption_text)
  end

  def test_column_vs_regular_headline
    source = <<~EOS
      = Chapter Title

      == Regular Headline

      Regular content.

      ==[column] Column Headline

      Column content.

      == Another Regular Headline

      More regular content.
    EOS

    @chapter.content = source
    ast_compiler = ReVIEW::AST::Compiler.new
    ast_root = ast_compiler.compile_to_ast(@chapter)

    # Find different node types
    headline_nodes = find_all_nodes_by_type(ast_root, ReVIEW::AST::HeadlineNode)
    column_nodes = find_all_nodes_by_type(ast_root, ReVIEW::AST::ColumnNode)

    # Should have 3 headlines (including the chapter title) and 1 column
    assert_equal(3, headline_nodes.length)
    assert_equal(1, column_nodes.length)

    # Check that regular headlines are HeadlineNode
    regular_headlines = headline_nodes.select { |n| n.level == 2 }
    assert_equal(2, regular_headlines.length)

    # Check that column is ColumnNode
    column = column_nodes.first
    assert_equal(2, column.level)
    assert_equal('Column Headline', column.caption_text)
  end

  def test_column_with_inline_elements
    source = <<~EOS
      = Chapter Title

      ==[column] Column with @<b>{Bold} Text

      Content with @<i>{italic} and @<code>{code}.
    EOS

    @chapter.content = source
    ast_compiler = ReVIEW::AST::Compiler.new
    ast_root = ast_compiler.compile_to_ast(@chapter)

    # Find column node
    column_node = find_node_by_type(ast_root, ReVIEW::AST::ColumnNode)
    assert_not_nil(column_node)

    # Check that caption has inline elements processed
    caption_text = column_node.caption_text
    assert_include(caption_text, 'Bold')

    # Check that content has inline elements in children
    assert(column_node.children.any?, 'Column should have content as children')

    # Test round-trip conversion
    generator = ReVIEW::AST::ReVIEWGenerator.new
    result = generator.generate(ast_root)
    assert_include(result, '==[column]')
    assert_include(result, '@<i>{italic}')
    assert_include(result, '@<code>{code}')
  end

  private

  def find_node_by_type(node, node_type)
    return node if node.is_a?(node_type)

    if node.children
      node.children.each do |child|
        result = find_node_by_type(child, node_type)
        return result if result
      end
    end

    nil
  end

  def find_all_nodes_by_type(node, node_type)
    results = []

    results << node if node.is_a?(node_type)

    if node.children
      node.children.each do |child|
        results.concat(find_all_nodes_by_type(child, node_type))
      end
    end

    results
  end
end
