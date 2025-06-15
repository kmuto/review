# frozen_string_literal: true

require_relative 'test_helper'
require 'review/ast'
require 'review/ast/renderer'
require 'review/compiler'
require 'review/htmlbuilder'
require 'review/book'
require 'review/book/chapter'

class TestASTLists < Test::Unit::TestCase
  def setup
    @config = ReVIEW::Configure.values
    @config['secnolevel'] = 2
    @config['language'] = 'ja'
    @book = ReVIEW::Book::Base.new
    @book.config = @config
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

    builder = ReVIEW::HTMLBuilder.new
    compiler = ReVIEW::Compiler.new(builder, ast_mode: true, ast_elements: %i[headline paragraph ulist])
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = content

    compiler.compile(chapter)
    ast_root = compiler.ast_result

    # Check that list node exists
    list_node = ast_root.children.find { |n| n.is_a?(ReVIEW::AST::ListNode) }
    assert_not_nil(list_node, 'Should have list node')
    assert_equal :ul, list_node.list_type

    # Check list items - proper nested structure
    assert_equal 3, list_node.children.size # 3 main items at level 1

    first_item = list_node.children[0]
    assert_equal 1, first_item.level

    second_item = list_node.children[1]
    assert_equal 1, second_item.level
    # Should have inline bold element
    bold_node = second_item.children.find { |n| n.is_a?(ReVIEW::AST::InlineNode) && n.inline_type == 'b' }
    assert_not_nil(bold_node)

    # Check for nested list under second item
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

    builder = ReVIEW::HTMLBuilder.new
    compiler = ReVIEW::Compiler.new(builder, ast_mode: true, ast_elements: %i[paragraph olist])
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = content

    compiler.compile(chapter)
    ast_root = compiler.ast_result

    list_node = ast_root.children.find { |n| n.is_a?(ReVIEW::AST::ListNode) }
    assert_not_nil(list_node)
    assert_equal :ol, list_node.list_type
    assert_equal 3, list_node.children.size

    # Check that numbers are preserved
    first_item = list_node.children[0]
    assert_equal '1', first_item.content

    third_item = list_node.children[2]
    assert_equal '3', third_item.content
    # Should have inline code element
    code_node = third_item.children.find { |n| n.is_a?(ReVIEW::AST::InlineNode) && n.inline_type == 'code' }
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

    builder = ReVIEW::HTMLBuilder.new
    compiler = ReVIEW::Compiler.new(builder, ast_mode: true, ast_elements: %i[paragraph dlist])
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = content

    compiler.compile(chapter)
    ast_root = compiler.ast_result

    list_node = ast_root.children.find { |n| n.is_a?(ReVIEW::AST::ListNode) }
    assert_not_nil(list_node)
    assert_equal :dl, list_node.list_type
    assert_equal 2, list_node.children.size

    # First definition item
    first_def = list_node.children[0]
    assert_equal 1, first_def.level
    # Should have dt (term) and dd (description) content
    assert(first_def.children.any?)

    # Second definition item
    second_def = list_node.children[1]
    assert_equal 1, second_def.level
    assert(second_def.children.any?)
  end

  def test_list_output_compatibility
    content = <<~EOB
      Lists test:

       * Unordered item 1
       * Unordered item 2

       1. Ordered item 1
       2. Ordered item 2

       : Term
          Definition

      End.
    EOB

    # Test with AST mode
    builder_ast = ReVIEW::HTMLBuilder.new
    compiler_ast = ReVIEW::Compiler.new(builder_ast, ast_mode: true, ast_elements: %i[paragraph ulist olist dlist])
    chapter_ast = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter_ast.content = content
    result_ast = compiler_ast.compile(chapter_ast)

    # Test with traditional mode
    builder_trad = ReVIEW::HTMLBuilder.new
    compiler_trad = ReVIEW::Compiler.new(builder_trad)
    chapter_trad = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter_trad.content = content
    result_trad = compiler_trad.compile(chapter_trad)

    # Both should produce similar list HTML
    assert(result_ast.include?('<ul>'), 'AST mode should produce unordered list')
    assert(result_ast.include?('<ol>'), 'AST mode should produce ordered list')
    assert(result_ast.include?('<dl>'), 'AST mode should produce definition list')

    assert(result_trad.include?('<ul>'), 'Traditional mode should produce unordered list')
    assert(result_trad.include?('<ol>'), 'Traditional mode should produce ordered list')
    assert(result_trad.include?('<dl>'), 'Traditional mode should produce definition list')
  end

  def test_mixed_content_with_lists
    content = <<~EOB
      = Chapter with Lists

      Introduction paragraph.

       * First bullet point
       * Second bullet with @<b>{emphasis}
       ** Nested point

      Middle paragraph.

       1. First numbered item
       2. Second numbered item

       : Term 1
          Definition 1
       : Term 2
          Definition 2

      Conclusion paragraph.
    EOB

    builder = ReVIEW::HTMLBuilder.new
    compiler = ReVIEW::Compiler.new(builder, ast_mode: true, ast_elements: %i[headline paragraph ulist olist dlist])
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = content

    compiler.compile(chapter)
    ast_root = compiler.ast_result

    # Check all components exist
    headline_node = ast_root.children.find { |n| n.is_a?(ReVIEW::AST::HeadlineNode) }
    paragraph_nodes = ast_root.children.select { |n| n.is_a?(ReVIEW::AST::ParagraphNode) }
    list_nodes = ast_root.children.select { |n| n.is_a?(ReVIEW::AST::ListNode) }

    assert_not_nil(headline_node)
    assert_equal 3, paragraph_nodes.size  # intro, middle, conclusion
    assert_equal 3, list_nodes.size       # ul, ol, dl

    # Check list types
    ul_node = list_nodes.find { |n| n.list_type == :ul }
    ol_node = list_nodes.find { |n| n.list_type == :ol }
    dl_node = list_nodes.find { |n| n.list_type == :dl }

    assert_not_nil(ul_node)
    assert_not_nil(ol_node)
    assert_not_nil(dl_node)

    # Check inline elements in ul
    bold_item = ul_node.children.find do |item|
      item.children.any? { |child| child.is_a?(ReVIEW::AST::InlineNode) && child.inline_type == 'b' }
    end
    assert_not_nil(bold_item)
  end
end
