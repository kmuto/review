# frozen_string_literal: true

require_relative 'test_helper'
require 'review/ast/list_ast_processor'
require 'review/lineinput'
require 'stringio'

class TestListASTProcessor < Test::Unit::TestCase
  class MockASTCompiler
    attr_reader :added_nodes

    def initialize
      @added_nodes = []
      @current_location = nil
    end

    def add_child_to_current_node(node)
      @added_nodes << node
    end

    # NOTE: render_with_ast_renderer removed with hybrid mode elimination

    def inline_processor
      @inline_processor ||= MockInlineProcessor.new
    end

    def location
      @current_location
    end
  end

  class MockInlineProcessor
    def parse_inline_elements(content, parent_node)
      # Simple mock: just add content as text node
      text_node = ReVIEW::AST::TextNode.new(content: content)
      parent_node.add_child(text_node)
    end
  end

  def setup
    @mock_compiler = MockASTCompiler.new
    @processor = ReVIEW::AST::ListASTProcessor.new(@mock_compiler)
  end

  def create_line_input(content)
    ReVIEW::LineInput.from_string(content)
  end

  # Test unordered list processing
  def test_process_unordered_list_simple
    input = create_line_input(
      "   * First item\n" +
      "   * Second item\n" +
      "   * Third item\n"
    )

    @processor.process_unordered_list(input)

    assert_equal 1, @mock_compiler.added_nodes.size
    list_node = @mock_compiler.added_nodes[0]
    assert_instance_of(ReVIEW::AST::ListNode, list_node)
    assert_equal :ul, list_node.list_type
    assert_equal 3, list_node.children.size

    # NOTE: render call testing removed with hybrid mode elimination
  end

  def test_process_unordered_list_nested
    input = create_line_input(
      "   * First level\n" +
      "   ** Second level\n" +
      "   * Back to first\n"
    )

    @processor.process_unordered_list(input)

    list_node = @mock_compiler.added_nodes[0]
    assert_equal 2, list_node.children.size # Two top-level items

    # Check nested structure
    first_item = list_node.children[0]
    nested_list = first_item.children.find { |child| child.is_a?(ReVIEW::AST::ListNode) }
    assert_not_nil(nested_list)
    assert_equal :ul, nested_list.list_type
  end

  def test_process_unordered_list_empty
    input = create_line_input('')

    @processor.process_unordered_list(input)

    assert_equal 0, @mock_compiler.added_nodes.size
  end

  # Test ordered list processing
  def test_process_ordered_list_simple
    input = create_line_input(
      "   1. First item\n" +
      "   2. Second item\n" +
      "   3. Third item\n"
    )

    @processor.process_ordered_list(input)

    assert_equal 1, @mock_compiler.added_nodes.size
    list_node = @mock_compiler.added_nodes[0]
    assert_equal :ol, list_node.list_type
    assert_equal 3, list_node.children.size

    # Check that items have proper numbering
    items = list_node.children
    assert_equal '1', items[0].content
    assert_equal 1, items[0].number
    assert_equal '2', items[1].content
    assert_equal 2, items[1].number
  end

  def test_process_ordered_list_nested
    input = create_line_input(
      "   1. First level\n" +
      "   11. Second level\n" +
      "   2. Back to first\n"
    )

    @processor.process_ordered_list(input)

    list_node = @mock_compiler.added_nodes[0]
    assert_equal 2, list_node.children.size # Two top-level items

    # Check nested structure
    first_item = list_node.children[0]
    nested_list = first_item.children.find { |child| child.is_a?(ReVIEW::AST::ListNode) }
    assert_not_nil(nested_list)
    assert_equal :ol, nested_list.list_type

    nested_item = nested_list.children[0]
    assert_equal 2, nested_item.level
    assert_equal 11, nested_item.number
  end

  # Test definition list processing
  def test_process_definition_list
    input = create_line_input(
      "   : Term 1\n" +
      "     Definition 1\n" +
      "   : Term 2\n" +
      "     Definition 2\n"
    )

    @processor.process_definition_list(input)

    list_node = @mock_compiler.added_nodes[0]
    assert_equal :dl, list_node.list_type
    assert_equal 2, list_node.children.size

    first_item = list_node.children[0]
    assert_equal 'Term 1', first_item.content
  end

  def test_process_definition_list_multiline
    input = create_line_input(
      "   : Complex Term\n" +
      "     Definition line 1\n" +
      "     Definition line 2\n" +
      "     Definition line 3\n"
    )

    @processor.process_definition_list(input)

    list_node = @mock_compiler.added_nodes[0]
    item = list_node.children[0]
    assert_equal 'Complex Term', item.content
    # Should have multiple children for definition content
    assert_operator(item.children.size, :>=, 2)
  end

  # Test generic list processing
  def test_process_list_with_type_ul
    input = create_line_input(
      "   * Item 1\n" +
      "   * Item 2\n"
    )

    @processor.process_list(input, :ul)

    list_node = @mock_compiler.added_nodes[0]
    assert_equal :ul, list_node.list_type
  end

  def test_process_list_with_type_ol
    input = create_line_input(
      "   1. Item 1\n" +
      "   2. Item 2\n"
    )

    @processor.process_list(input, :ol)

    list_node = @mock_compiler.added_nodes[0]
    assert_equal :ol, list_node.list_type
  end

  def test_process_list_with_type_dl
    input = create_line_input(
      "   : Term\n" +
      "     Definition\n"
    )

    @processor.process_list(input, :dl)

    list_node = @mock_compiler.added_nodes[0]
    assert_equal :dl, list_node.list_type
  end

  def test_process_generic_list
    input = create_line_input(
      "   * Custom item 1\n" +
      "   * Custom item 2\n"
    )

    @processor.process_generic_list(input, :custom)

    list_node = @mock_compiler.added_nodes[0]
    assert_equal :custom, list_node.list_type
    assert_equal 2, list_node.children.size
  end

  # Test utility methods
  def test_build_list_from_items
    items = [
      ReVIEW::AST::ListParser::ListItemData.new(
        type: :ul,
        level: 1,
        content: 'Test item',
        continuation_lines: [],
        metadata: {}
      )
    ]

    list_node = @processor.build_list_from_items(items, :ul)

    assert_instance_of(ReVIEW::AST::ListNode, list_node)
    assert_equal :ul, list_node.list_type
    assert_equal 1, list_node.children.size
  end

  def test_parse_list_items_ul
    input = create_line_input(
      "   * Item 1\n" +
      "   * Item 2\n"
    )

    items = @processor.parse_list_items(input, :ul)

    assert_equal 2, items.size
    assert_equal :ul, items[0].type
    assert_equal 'Item 1', items[0].content
  end

  def test_parse_list_items_ol
    input = create_line_input(
      "   1. Item 1\n" +
      "   2. Item 2\n"
    )

    items = @processor.parse_list_items(input, :ol)

    assert_equal 2, items.size
    assert_equal :ol, items[0].type
    assert_equal 'Item 1', items[0].content
    assert_equal 1, items[0].metadata[:number]
  end

  def test_parse_list_items_dl
    input = create_line_input(
      "   : Term\n" +
      "     Definition\n"
    )

    items = @processor.parse_list_items(input, :dl)

    assert_equal 1, items.size
    assert_equal :dl, items[0].type
    assert_equal 'Term', items[0].content
    assert_equal ['Definition'], items[0].continuation_lines
  end

  def test_parse_list_items_unknown_type
    input = create_line_input(
      "   * Item 1\n" +
      "   * Item 2\n"
    )

    # Should fallback to unordered list parsing
    items = @processor.parse_list_items(input, :unknown)

    assert_equal 2, items.size
    assert_equal :ul, items[0].type
  end

  # Test access to internal components
  def test_parser_access
    assert_instance_of(ReVIEW::AST::ListParser, @processor.parser)
  end

  def test_builder_access
    assert_instance_of(ReVIEW::AST::NestedListBuilder, @processor.builder)
  end

  # Test complex scenarios
  def test_process_mixed_nesting_complexity
    input = create_line_input(
      "   * Level 1 item 1\n" +
      "   ** Level 2 item 1\n" +
      "   *** Level 3 item 1\n" +
      "   ** Level 2 item 2\n" +
      "   * Level 1 item 2\n" +
      "   ** Level 2 item 3\n"
    )

    @processor.process_unordered_list(input)

    list_node = @mock_compiler.added_nodes[0]
    assert_equal 2, list_node.children.size # Two top-level items

    # Verify complex nesting structure was created
    first_item = list_node.children[0]
    nested_list = first_item.children.find { |child| child.is_a?(ReVIEW::AST::ListNode) }
    assert_not_nil(nested_list)
    assert_equal 2, nested_list.children.size # Two level-2 items under first level-1

    # Check deeper nesting
    first_level2 = nested_list.children[0]
    deeper_nested = first_level2.children.find { |child| child.is_a?(ReVIEW::AST::ListNode) }
    assert_not_nil(deeper_nested)
    assert_equal 1, deeper_nested.children.size # One level-3 item
  end

  def test_process_with_continuation_lines
    input = create_line_input(
      "   * Main item content\n" +
      "     Continuation line 1\n" +
      "     Continuation line 2\n" +
      "   * Second item\n"
    )

    @processor.process_unordered_list(input)

    list_node = @mock_compiler.added_nodes[0]
    first_item = list_node.children[0]

    # Should have processed continuation lines as additional content
    assert_operator(first_item.children.size, :>=, 1)
  end
end
