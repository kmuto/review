# frozen_string_literal: true

require_relative '../test_helper'
require 'review/ast'
require 'review/ast/compiler'
require 'review/configure'
require 'review/book'
require 'review/book/chapter'

class TestASTLists < Test::Unit::TestCase
  def setup
    @config = ReVIEW::Configure.values
    @config['secnolevel'] = 2
    @config['language'] = 'ja'
    @book = ReVIEW::Book::Base.new(config: @config)
    @log_io = StringIO.new
    ReVIEW.logger = ReVIEW::Logger.new(@log_io)
    ReVIEW::I18n.setup(@config['language'])
  end

  def test_unordered_list_ast_processing
    content = <<~EOB
      = Chapter Title

      Before list.

       * First item
       * Second item with @<b>{bold}
       ** Nested item
       * Third item

      After list.
    EOB

    ast_root = compile_to_ast(content)
    list_node = ast_root.children.find { |n| n.is_a?(ReVIEW::AST::ListNode) }
    assert_not_nil(list_node, 'Should have list node')
    assert_equal :ul, list_node.list_type

    assert_equal 3, list_node.children.size

    first_item = list_node.children[0]
    assert_equal 1, first_item.level

    second_item = list_node.children[1]
    assert_equal 1, second_item.level
    bold_node = second_item.children.find { |n| n.is_a?(ReVIEW::AST::InlineNode) && n.inline_type == :b }
    assert_not_nil(bold_node)

    nested_list = second_item.children.find { |n| n.is_a?(ReVIEW::AST::ListNode) }
    assert_not_nil(nested_list, 'Second item should have nested list')
    assert_equal :ul, nested_list.list_type
    assert_equal 1, nested_list.children.size

    nested_item = nested_list.children[0]
    assert_equal 2, nested_item.level

    third_item = list_node.children[2]
    assert_equal 1, third_item.level
  end

  def test_ordered_list_ast_processing
    content = <<~EOB
      Numbered list:

       1. First item
       2. Second item
       3. Third item with @<code>{code}

      End of list.
    EOB

    ast_root = compile_to_ast(content)
    list_node = ast_root.children.find { |n| n.is_a?(ReVIEW::AST::ListNode) }
    assert_not_nil(list_node)
    assert_equal :ol, list_node.list_type
    assert_equal 3, list_node.children.size

    first_item = list_node.children[0]
    assert_equal 1, first_item.number

    third_item = list_node.children[2]
    assert_equal 3, third_item.number
    code_node = third_item.children.find { |n| n.is_a?(ReVIEW::AST::InlineNode) && n.inline_type == :code }
    assert_not_nil(code_node)
  end

  def test_definition_list_ast_processing
    content = <<~EOB
      Definition list:

       : Alpha
          DEC の作っていた RISC CPU。
          浮動小数点数演算が速い。
       : POWER
          IBM とモトローラが共同製作した RISC CPU。
          派生として POWER PC がある。

      After definitions.
    EOB

    ast_root = compile_to_ast(content)
    list_node = ast_root.children.find { |n| n.is_a?(ReVIEW::AST::ListNode) }
    assert_not_nil(list_node)
    assert_equal :dl, list_node.list_type
    assert_equal 2, list_node.children.size

    first_def = list_node.children[0]
    assert_equal 1, first_def.level
    assert(first_def.children.any?)

    second_def = list_node.children[1]
    assert_equal 1, second_def.level
    assert(second_def.children.any?)
  end

  def test_list_output_compatibility
    content = <<~EOB
      Lists test:

       * Unordered item 1
       * Unordered item with @<b>{bold} text

       1. Ordered item 1
       2. Ordered item 2

       : Term
          Definition

      End.
    EOB

    ast_root = compile_to_ast(content)
    paragraph_nodes = ast_root.children.select { |n| n.is_a?(ReVIEW::AST::ParagraphNode) }
    list_nodes = ast_root.children.select { |n| n.is_a?(ReVIEW::AST::ListNode) }

    assert_equal 2, paragraph_nodes.size
    assert_equal 3, list_nodes.size

    ul_node = list_nodes.find { |n| n.list_type == :ul }
    ol_node = list_nodes.find { |n| n.list_type == :ol }
    dl_node = list_nodes.find { |n| n.list_type == :dl }

    assert_not_nil(ul_node)
    assert_not_nil(ol_node)
    assert_not_nil(dl_node)

    bold_item = ul_node.children.find do |item|
      item.children.any? { |child| child.is_a?(ReVIEW::AST::InlineNode) && child.inline_type == :b }
    end
    assert_not_nil(bold_item)
  end

  def test_deep_nested_list_ast_processing
    content = <<~EOB
      = Deep Nesting Test

       * Level 1 Item A
       ** Level 2 Item A1
       *** Level 3 Item A1a
       *** Level 3 Item A1b
       ** Level 2 Item A2
       * Level 1 Item B
       ** Level 2 Item B1
       *** Level 3 Item B1a
       **** Level 4 Item B1a-i
       **** Level 4 Item B1a-ii
       *** Level 3 Item B1b
       ** Level 2 Item B2
       * Level 1 Item C
    EOB

    ast_root = compile_to_ast(content)
    main_list = ast_root.children.find { |n| n.is_a?(ReVIEW::AST::ListNode) }
    assert_not_nil(main_list, 'Should have main list node')
    assert_equal :ul, main_list.list_type
    assert_equal 3, main_list.children.size

    item_a = main_list.children[0]
    assert_equal 1, item_a.level
    nested_list_a = item_a.children.find { |n| n.is_a?(ReVIEW::AST::ListNode) }
    assert_not_nil(nested_list_a, 'Item A should have nested list')
    assert_equal 2, nested_list_a.children.size

    item_a1 = nested_list_a.children[0]
    assert_equal 2, item_a1.level
    nested_list_a1 = item_a1.children.find { |n| n.is_a?(ReVIEW::AST::ListNode) }
    assert_not_nil(nested_list_a1, 'Item A1 should have nested list')
    assert_equal 2, nested_list_a1.children.size

    item_a1a = nested_list_a1.children[0]
    item_a1b = nested_list_a1.children[1]
    assert_equal 3, item_a1a.level
    assert_equal 3, item_a1b.level

    item_b = main_list.children[1]
    assert_equal 1, item_b.level
    nested_list_b = item_b.children.find { |n| n.is_a?(ReVIEW::AST::ListNode) }
    assert_not_nil(nested_list_b, 'Item B should have nested list')

    item_b1 = nested_list_b.children[0]
    nested_list_b1 = item_b1.children.find { |n| n.is_a?(ReVIEW::AST::ListNode) }
    assert_not_nil(nested_list_b1)
    item_b1a = nested_list_b1.children[0]
    nested_list_b1a = item_b1a.children.find { |n| n.is_a?(ReVIEW::AST::ListNode) }
    assert_not_nil(nested_list_b1a, 'Should have Level 4 nesting')
    assert_equal 2, nested_list_b1a.children.size

    item_b1a_i = nested_list_b1a.children[0]
    item_b1a_ii = nested_list_b1a.children[1]
    assert_equal 4, item_b1a_i.level
    assert_equal 4, item_b1a_ii.level
  end

  def test_mixed_nested_ordered_unordered_lists
    content = <<~EOB
      = Mixed List Types

       1. Ordered Item 1
       2. Ordered Item 2

       * Unordered Item 1
       ** Nested unordered
       *** Deep unordered
       * Unordered Item 2
       ** Another nested
    EOB

    ast_root = compile_to_ast(content)
    list_nodes = ast_root.children.select { |n| n.is_a?(ReVIEW::AST::ListNode) }
    assert_operator(list_nodes.size, :>=, 2, 'Should have multiple lists for different types')

    ol_nodes = list_nodes.select { |n| n.list_type == :ol }
    ul_nodes = list_nodes.select { |n| n.list_type == :ul }

    assert_equal(1, ol_nodes.size, 'Should have one ordered list')
    assert_equal(1, ul_nodes.size, 'Should have one unordered list')

    first_ol = ol_nodes[0]
    assert_equal(2, first_ol.children.size, 'Ordered list should have 2 items')

    first_ul = ul_nodes[0]
    assert_equal(2, first_ul.children.size, 'Unordered list should have 2 top-level items')

    first_ul_item = first_ul.children[0]
    nested_ul = first_ul_item.children.find { |child| child.is_a?(ReVIEW::AST::ListNode) }
    assert_not_nil(nested_ul, 'First unordered item should have nested list')

    nested_item = nested_ul.children[0]
    deep_nested = nested_item.children.find { |child| child.is_a?(ReVIEW::AST::ListNode) }
    assert_not_nil(deep_nested, 'Should have 3-level nesting')
    assert_equal(3, deep_nested.children[0].level)
  end

  private

  def compile_to_ast(content)
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = content

    @book.generate_indexes
    chapter.generate_indexes

    ast_compiler = ReVIEW::AST::Compiler.new
    ast_compiler.compile_to_ast(chapter)
  end
end
