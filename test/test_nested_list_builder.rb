# frozen_string_literal: true

require_relative 'test_helper'
require 'review/ast/nested_list_builder'
require 'review/ast/list_parser'
require 'review/ast/list_node'
require 'review/ast/text_node'
require 'review/ast/paragraph_node'
require 'review/location'

class TestNestedListBuilder < Test::Unit::TestCase
  def setup
    # Create mock objects for location_provider and inline_processor
    @mock_location_provider = Object.new
    @mock_inline_processor = Object.new

    # Define location method for location_provider
    def @mock_location_provider.location
      ReVIEW::Location.new('test.re', 1)
    end

    # Define parse_inline_elements method for inline_processor
    def @mock_inline_processor.parse_inline_elements(content, parent_node)
      text_node = ReVIEW::AST::TextNode.new(
        location: ReVIEW::Location.new('test.re', 1),
        content: content
      )
      parent_node.add_child(text_node)
    end

    @builder = ReVIEW::AST::NestedListBuilder.new(@mock_location_provider, @mock_inline_processor)
  end

  def create_list_item_data(type, level, content, continuation_lines = [], metadata = {})
    ReVIEW::AST::ListParser::ListItemData.new(
      type: type,
      level: level,
      content: content,
      continuation_lines: continuation_lines,
      metadata: metadata
    )
  end

  # Test empty list building
  def test_build_empty_lists
    %i[ul ol dl].each do |list_type|
      list_node = @builder.build_nested_structure([], list_type)
      assert_instance_of(ReVIEW::AST::ListNode, list_node)
      assert_equal list_type, list_node.list_type
      assert_equal [], list_node.children
    end
  end

  # Test unordered list building
  def test_build_simple_unordered_list
    items = [
      create_list_item_data(:ul, 1, 'First item'),
      create_list_item_data(:ul, 1, 'Second item'),
      create_list_item_data(:ul, 1, 'Third item')
    ]

    list_node = @builder.build_unordered_list(items)

    assert_instance_of(ReVIEW::AST::ListNode, list_node)
    assert_equal :ul, list_node.list_type
    assert_equal 3, list_node.children.size

    list_node.children.each_with_index do |item, _i|
      assert_instance_of(ReVIEW::AST::ListItemNode, item)
      assert_equal 1, item.level
    end
  end

  def test_build_nested_unordered_list
    items = [
      create_list_item_data(:ul, 1, 'First level'),
      create_list_item_data(:ul, 2, 'Second level'),
      create_list_item_data(:ul, 3, 'Third level'),
      create_list_item_data(:ul, 1, 'Back to first')
    ]

    list_node = @builder.build_unordered_list(items)

    assert_equal :ul, list_node.list_type
    assert_equal 2, list_node.children.size # Two top-level items

    # First item should have nested structure
    first_item = list_node.children[0]
    assert_equal 1, first_item.level

    # Check for nested list
    nested_list = first_item.children.find { |child| child.is_a?(ReVIEW::AST::ListNode) }
    assert_not_nil(nested_list)
    assert_equal :ul, nested_list.list_type
    assert_equal 1, nested_list.children.size

    # Check second level item
    second_item = nested_list.children[0]
    assert_equal 2, second_item.level

    # Check for deeper nesting
    deeper_nested = second_item.children.find { |child| child.is_a?(ReVIEW::AST::ListNode) }
    assert_not_nil(deeper_nested)
    third_item = deeper_nested.children[0]
    assert_equal 3, third_item.level
  end

  # Test ordered list building
  def test_build_simple_ordered_list
    items = [
      create_list_item_data(:ol, 1, 'First', [], { number: 1, number_string: '1' }),
      create_list_item_data(:ol, 1, 'Second', [], { number: 2, number_string: '2' })
    ]

    list_node = @builder.build_ordered_list(items)

    assert_equal :ol, list_node.list_type
    assert_equal 2, list_node.children.size

    first_item = list_node.children[0]
    assert_equal '1', first_item.content
    assert_equal 1, first_item.number
  end

  def test_build_nested_ordered_list
    items = [
      create_list_item_data(:ol, 1, 'First', [], { number: 1, number_string: '1' }),
      create_list_item_data(:ol, 2, 'Nested', [], { number: 11, number_string: '11' }),
      create_list_item_data(:ol, 1, 'Second', [], { number: 2, number_string: '2' })
    ]

    list_node = @builder.build_ordered_list(items)

    assert_equal 2, list_node.children.size # Two top-level items

    # Check nested structure
    first_item = list_node.children[0]
    nested_list = first_item.children.find { |child| child.is_a?(ReVIEW::AST::ListNode) }
    assert_not_nil(nested_list)
    assert_equal :ol, nested_list.list_type

    nested_item = nested_list.children[0]
    assert_equal 2, nested_item.level
    assert_equal '11', nested_item.content
    assert_equal 11, nested_item.number
  end

  # Test definition list building
  def test_build_definition_list
    items = [
      create_list_item_data(:dl, 1, 'Term 1', ['Definition 1']),
      create_list_item_data(:dl, 1, 'Term 2', ['Definition 2'])
    ]

    list_node = @builder.build_definition_list(items)

    assert_equal :dl, list_node.list_type
    assert_equal 2, list_node.children.size

    first_item = list_node.children[0]
    assert_equal 1, first_item.level
    assert_equal 'Term 1', first_item.content

    # Check that definition content is added as children
    # Should have term content plus definition content
    assert_operator(first_item.children.size, :>=, 1)
  end

  def test_build_definition_list_with_multiline_definitions
    items = [
      create_list_item_data(:dl, 1, 'Complex Term', [
                              'First definition line',
                              'Second definition line'
                            ])
    ]

    list_node = @builder.build_definition_list(items)

    assert_equal 1, list_node.children.size
    item = list_node.children[0]

    # Should have multiple children for the definition content
    assert_operator(item.children.size, :>=, 2)
  end

  # Test generic list building
  def test_build_generic_list
    items = [
      create_list_item_data(:custom, 1, 'Custom item 1'),
      create_list_item_data(:custom, 1, 'Custom item 2')
    ]

    list_node = @builder.build_generic_list(items, :custom)

    assert_equal :custom, list_node.list_type
    assert_equal 2, list_node.children.size
  end

  # Test continuation lines handling
  def test_build_with_continuation_lines
    items = [
      create_list_item_data(:ul, 1, 'Main content', [
                              'Continuation line 1',
                              'Continuation line 2'
                            ])
    ]

    list_node = @builder.build_unordered_list(items)

    item = list_node.children[0]
    # Should have multiple children for main content + continuation lines
    assert_operator(item.children.size, :>=, 1)
  end

  # Test error handling and edge cases
  def test_build_with_invalid_nesting
    # Test items with inconsistent nesting levels
    items = [
      create_list_item_data(:ul, 3, 'Deep item without parent'),
      create_list_item_data(:ul, 1, 'Normal item')
    ]

    # Should not crash and should handle gracefully
    list_node = @builder.build_unordered_list(items)
    assert_instance_of(ReVIEW::AST::ListNode, list_node)
    assert_equal :ul, list_node.list_type
  end

  def test_build_mixed_level_complexity
    # Test complex nesting pattern
    items = [
      create_list_item_data(:ul, 1, 'Level 1'),
      create_list_item_data(:ul, 2, 'Level 2a'),
      create_list_item_data(:ul, 2, 'Level 2b'),
      create_list_item_data(:ul, 3, 'Level 3'),
      create_list_item_data(:ul, 1, 'Back to Level 1'),
      create_list_item_data(:ul, 2, 'Level 2c')
    ]

    list_node = @builder.build_unordered_list(items)

    # Should create proper nested structure
    assert_equal :ul, list_node.list_type
    assert_equal 2, list_node.children.size # Two top-level items

    # Verify nested structure exists
    first_item = list_node.children[0]
    nested_list = first_item.children.find { |child| child.is_a?(ReVIEW::AST::ListNode) }
    assert_not_nil(nested_list)

    # Second top-level item should also have nesting
    second_item = list_node.children[1]
    second_nested = second_item.children.find { |child| child.is_a?(ReVIEW::AST::ListNode) }
    assert_not_nil(second_nested)
  end

  # Test node creation methods
  def test_create_list_node
    node = @builder.send(:create_list_node, :test_type)
    assert_instance_of(ReVIEW::AST::ListNode, node)
    assert_equal :test_type, node.list_type
  end

  def test_create_list_item_node
    item_data = create_list_item_data(:ul, 2, 'Test content')
    node = @builder.send(:create_list_item_node, item_data)
    assert_instance_of(ReVIEW::AST::ListItemNode, node)
    assert_equal 2, node.level
  end

  def test_create_ordered_list_item_node
    item_data = create_list_item_data(:ol, 1, 'Test', [], { number: 5, number_string: '5' })
    node = @builder.send(:create_list_item_node, item_data)
    assert_equal '5', node.content
    assert_equal 5, node.number
  end

  def test_create_definition_list_item_node
    item_data = create_list_item_data(:dl, 1, 'Term content')
    node = @builder.send(:create_list_item_node, item_data)
    assert_equal 'Term content', node.content
  end
end
