# frozen_string_literal: true

require_relative '../test_helper'
require 'stringio'
require 'ostruct'
require 'review/ast/compiler'
require 'review/ast/list_structure_normalizer'
require 'review/book'
require 'review/configure'

class ListStructureNormalizerTest < Test::Unit::TestCase
  include ReVIEW

  def setup
    @config = ReVIEW::Configure.values
    @book = Book::Base.new
    @book.config = @config
    @chapter = Book::Chapter.new(@book, 1, '-', nil, StringIO.new)
    @compiler = ReVIEW::AST::Compiler.for_chapter(@chapter)
  end

  def compile_ast(src)
    @chapter.content = src
    # compile_to_ast includes ListStructureNormalizer processing
    @compiler.compile_to_ast(@chapter, reference_resolution: false)
  end

  def find_nodes_by_type(node, type)
    result = []
    result << node if node.is_a?(type)
    node.children.each do |child|
      result.concat(find_nodes_by_type(child, type))
    end
    result
  end

  def find_block_nodes_by_type(node, block_type)
    result = []
    if node.is_a?(ReVIEW::AST::BlockNode) && node.block_type == block_type
      result << node
    end
    node.children.each do |child|
      result.concat(find_block_nodes_by_type(child, block_type))
    end
    result
  end

  def test_beginchild_nested_lists
    src = <<~REVIEW
       * UL1

      //beginchild

       1. UL1-OL1
       2. UL1-OL2

       * UL1-UL1
       * UL1-UL2

       : UL1-DL1
      \tUL1-DD1
       : UL1-DL2
      \tUL1-DD2

      //endchild

       * UL2

      //beginchild

      UL2-PARA

      //endchild
    REVIEW

    ast = compile_ast(src)

    # After normalization (done in compile_to_ast), beginchild/endchild blocks should be removed
    beginchild_blocks = find_block_nodes_by_type(ast, :beginchild)
    assert_equal 0, beginchild_blocks.size, 'beginchild blocks should be removed after normalization'

    endchild_blocks = find_block_nodes_by_type(ast, :endchild)
    assert_equal 0, endchild_blocks.size, 'endchild blocks should be removed after normalization'

    # Find the main UL list
    document = ast.children.first
    assert_instance_of(ReVIEW::AST::ListNode, document)
    assert_equal :ul, document.list_type

    first_item = document.children.first
    assert_equal 'UL1', first_item.children.first.content

    # Check nested lists inside first item
    nested_lists = first_item.children.select { |child| child.is_a?(ReVIEW::AST::ListNode) }
    assert_equal 3, nested_lists.size

    ordered = nested_lists.find { |child| child.list_type == :ol }
    assert_not_nil(ordered)
    assert_equal(%w[UL1-OL1 UL1-OL2], ordered.children.map { |item| item.children.first.content })

    unordered = nested_lists.find { |child| child.list_type == :ul }
    assert_not_nil(unordered)
    assert_equal(%w[UL1-UL1 UL1-UL2], unordered.children.map { |item| item.children.first.content })

    definition = nested_lists.find { |child| child.list_type == :dl }
    assert_not_nil(definition)
    assert_equal(%w[UL1-DL1 UL1-DL2], definition.children.map { |item| item.term_children.first.content })
    assert_equal(%w[UL1-DD1 UL1-DD2], definition.children.map { |item| item.children.first.content.strip })

    second_item = document.children.last
    assert_equal 'UL2', second_item.children.first.content
    paragraph = second_item.children.last
    assert_instance_of(ReVIEW::AST::ParagraphNode, paragraph)
    assert_equal 'UL2-PARA', paragraph.children.first.content
  end

  def test_definition_list_paragraphs_split
    src = <<~REVIEW
      : Term1
      \tFirst definition

      : Term2
      \tSecond line
      \tThird line
    REVIEW

    ast = compile_ast(src)

    definition = ast.children.first
    assert_instance_of(ReVIEW::AST::ListNode, definition)
    assert_equal :dl, definition.list_type

    items = definition.children
    assert_equal 2, items.size

    term1 = items.first
    assert_equal 'Term1', term1.term_children.first.content
    assert_equal 'First definition', term1.children.first.content.strip

    term2 = items.last
    assert_equal 'Term2', term2.term_children.first.content
    assert_equal(['Second line', 'Third line'], term2.children.map { |child| child.content.strip })
  end

  def test_missing_endchild_raises
    src = <<~REVIEW
       * UL1

      //beginchild

       * UL1-UL1
    REVIEW

    assert_raise(ReVIEW::ApplicationError) do
      compile_ast(src)
    end
  end

  def test_consecutive_lists_merged
    # Test that consecutive lists created by beginchild/endchild are merged
    src = <<~REVIEW
       1. Item1
       2. Item2

      //beginchild

       * Nested

      //endchild

       3. Item3
    REVIEW

    ast = compile_ast(src)

    # The outer ordered list should contain all items (Item1, Item2, Item3)
    # even though beginchild/endchild appeared in the middle
    lists = ast.children.select { |child| child.is_a?(ReVIEW::AST::ListNode) && child.list_type == :ol }
    assert_equal 1, lists.size, 'Should have one merged ordered list'
    assert_equal 3, lists.first.children.size, 'Merged list should have 3 items'

    # Verify the nested structure
    second_item = lists.first.children[1]
    nested_ul = second_item.children.find { |c| c.is_a?(ReVIEW::AST::ListNode) && c.list_type == :ul }
    assert_not_nil(nested_ul, 'Second item should have nested ul')
  end

  def test_beginchild_without_previous_list_raises
    src = <<~REVIEW
      //beginchild

       * Item
      //endchild
    REVIEW

    assert_raise(ReVIEW::ApplicationError) do
      compile_ast(src)
    end
  end

  def test_endchild_without_beginchild_raises
    src = <<~REVIEW
       * Item

      //endchild
    REVIEW

    assert_raise(ReVIEW::ApplicationError) do
      compile_ast(src)
    end
  end

  def test_nested_beginchild_tracking
    src = <<~REVIEW
       1. OL1

      //beginchild

       1. OL1-OL1

      //beginchild

       * OL1-OL1-UL1

      //endchild

       2. OL1-OL2

      //endchild
    REVIEW

    ast = compile_ast(src)

    # Verify the nested structure
    root_list = ast.children.first
    assert_equal :ol, root_list.list_type

    first_item = root_list.children.first
    nested_ol = first_item.children.find { |c| c.is_a?(ReVIEW::AST::ListNode) && c.list_type == :ol }
    assert_not_nil(nested_ol)

    nested_first_item = nested_ol.children.first
    nested_ul = nested_first_item.children.find { |c| c.is_a?(ReVIEW::AST::ListNode) && c.list_type == :ul }
    assert_not_nil(nested_ul)
    assert_equal 'OL1-OL1-UL1', nested_ul.children.first.children.first.content
  end
end
