# frozen_string_literal: true

require_relative '../test_helper'
require 'review/ast/list_processor'
require 'review/ast/list_parser'
require 'review/ast/list_node'
require 'review/ast/text_node'
require 'review/ast/paragraph_node'
require 'review/ast/compiler'
require 'review/ast/inline_processor'
require 'review/htmlbuilder'
require 'review/location'

class TestNestedListAssembler < Test::Unit::TestCase
  def setup
    # Set up real compiler and inline processor for more realistic testing
    config = ReVIEW::Configure.values
    config['secnolevel'] = 2
    config['language'] = 'ja'
    book = ReVIEW::Book::Base.new(config: config)
    ReVIEW::I18n.setup(config['language'])

    compiler = ReVIEW::AST::Compiler.new
    inline_processor = compiler.inline_processor

    @assembler = ReVIEW::AST::ListProcessor::NestedListAssembler.new(compiler, inline_processor)
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

  def test_build_empty_lists
    %i[ul ol dl].each do |list_type|
      list_node = @assembler.build_nested_structure([], list_type)
      assert_instance_of(ReVIEW::AST::ListNode, list_node)
      assert_equal list_type, list_node.list_type
      assert_equal [], list_node.children
    end
  end

  def test_build_simple_unordered_list
    items = [
      create_list_item_data(:ul, 1, 'First item'),
      create_list_item_data(:ul, 1, 'Second item'),
      create_list_item_data(:ul, 1, 'Third item')
    ]

    list_node = @assembler.build_unordered_list(items)

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

    list_node = @assembler.build_unordered_list(items)

    assert_equal :ul, list_node.list_type
    assert_equal 2, list_node.children.size # Two top-level items

    # First item should have nested structure
    first_item = list_node.children[0]
    assert_equal 1, first_item.level

    # Check for nested list
    nested_list = first_item.children.find { |child| child.is_a?(ReVIEW::AST::ListNode) }
    assert_equal :ul, nested_list.list_type
    assert_equal 1, nested_list.children.size

    # Check second level item
    second_item = nested_list.children[0]
    assert_equal 2, second_item.level

    # Check for deeper nesting
    deeper_nested = second_item.children.find { |child| child.is_a?(ReVIEW::AST::ListNode) }
    third_item = deeper_nested.children[0]
    assert_equal 3, third_item.level
  end

  def test_build_simple_ordered_list
    items = [
      create_list_item_data(:ol, 1, 'First', [], { number: 1, number_string: '1' }),
      create_list_item_data(:ol, 1, 'Second', [], { number: 2, number_string: '2' })
    ]

    list_node = @assembler.build_ordered_list(items)

    assert_equal :ol, list_node.list_type
    assert_equal 2, list_node.children.size

    first_item = list_node.children[0]
    assert_equal 1, first_item.number
    # Verify content through children
    first_text = first_item.children.find { |c| c.is_a?(ReVIEW::AST::TextNode) }
    assert_equal 'First', first_text.content
  end

  def test_build_nested_ordered_list
    items = [
      create_list_item_data(:ol, 1, 'First', [], { number: 1, number_string: '1' }),
      create_list_item_data(:ol, 2, 'Nested', [], { number: 11, number_string: '11' }),
      create_list_item_data(:ol, 1, 'Second', [], { number: 2, number_string: '2' })
    ]

    list_node = @assembler.build_ordered_list(items)

    assert_equal 2, list_node.children.size # Two top-level items

    # Check nested structure
    first_item = list_node.children[0]
    nested_list = first_item.children.find { |child| child.is_a?(ReVIEW::AST::ListNode) }
    assert_equal :ol, nested_list.list_type

    nested_item = nested_list.children[0]
    assert_equal 2, nested_item.level
    assert_equal 11, nested_item.number
    # Verify content through children
    nested_text = nested_item.children.find { |c| c.is_a?(ReVIEW::AST::TextNode) }
    assert_equal 'Nested', nested_text.content
  end

  def test_build_definition_list
    items = [
      create_list_item_data(:dl, 1, 'Term 1', ['Definition 1']),
      create_list_item_data(:dl, 1, 'Term 2', ['Definition 2'])
    ]

    list_node = @assembler.build_definition_list(items)

    assert_equal :dl, list_node.list_type
    assert_equal 2, list_node.children.size

    # Test first item in detail
    first_item = list_node.children[0]
    assert_equal 1, first_item.level

    # Verify term is stored in term_children (plain text)
    assert_equal 1, first_item.term_children.size
    term_text = first_item.term_children.find { |c| c.is_a?(ReVIEW::AST::TextNode) }
    assert_equal 'Term 1', term_text.content

    # Verify definition content is added as children
    assert_equal 1, first_item.children.size
    definition_text = first_item.children.find { |c| c.is_a?(ReVIEW::AST::TextNode) }
    assert_equal 'Definition 1', definition_text.content
  end

  def test_build_definition_list_with_inline_elements
    # Test that inline elements in both term and definition are properly processed
    items = [
      create_list_item_data(:dl, 1, 'Term with @<b>{bold}', ['Definition with @<code>{some code}'])
    ]

    list_node = @assembler.build_definition_list(items)

    item = list_node.children[0]

    # Find the inline bold element in term
    bold_in_term = item.term_children.find { |c| c.is_a?(ReVIEW::AST::InlineNode) && c.inline_type == :b }
    assert_equal 'bold', bold_in_term.children.first.content

    # Verify definition children has processed inline elements
    # Definition with inline elements should be wrapped in ParagraphNode
    assert_equal 1, item.children.size
    definition_para = item.children.first
    assert_instance_of(ReVIEW::AST::ParagraphNode, definition_para)

    # The paragraph should contain inline code element
    code_in_def = definition_para.children.find { |c| c.is_a?(ReVIEW::AST::InlineNode) && c.inline_type == :code }
    assert_equal 'some code', code_in_def.children.first.content
  end

  def test_build_definition_list_with_multiline_definitions
    items = [
      create_list_item_data(:dl, 1, 'Complex Term', [
                              'First definition line',
                              'Second definition line'
                            ])
    ]

    list_node = @assembler.build_definition_list(items)

    assert_equal 1, list_node.children.size
    item = list_node.children[0]

    # Should have multiple children for the definition content
    assert_operator(item.children.size, :>=, 2)
  end

  def test_build_with_continuation_lines
    items = [
      create_list_item_data(:ul, 1, 'Main content', [
                              'Continuation line 1',
                              'Continuation line 2'
                            ])
    ]

    list_node = @assembler.build_unordered_list(items)

    item = list_node.children[0]
    # Should have multiple children for main content + continuation lines
    assert_operator(item.children.size, :>=, 1)
  end

  # Test error handling and edge cases
  def test_build_with_invalid_nesting
    # Test items with inconsistent nesting levels - should log error and adjust level
    items = [
      create_list_item_data(:ul, 3, 'Deep item without parent'),
      create_list_item_data(:ul, 1, 'Normal item')
    ]

    # Should log error but continue processing (HTMLBuilder behavior)
    # Level 3 will be adjusted to level 1
    list_node = @assembler.build_unordered_list(items)

    # Should successfully create list with adjusted levels
    assert_instance_of(ReVIEW::AST::ListNode, list_node)
    assert_equal :ul, list_node.list_type
    assert_equal 2, list_node.children.size
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

    list_node = @assembler.build_unordered_list(items)

    # Should create proper nested structure
    assert_equal :ul, list_node.list_type
    assert_equal 2, list_node.children.size # Two top-level items

    # Verify nested structure exists
    first_item = list_node.children[0]
    nested_list = first_item.children.find { |child| child.is_a?(ReVIEW::AST::ListNode) }
    assert_equal 'Level 2a', nested_list.children[0].children[0].content
    assert_equal 'Level 2b', nested_list.children[1].children[0].content
    assert_equal 'Level 3', nested_list.children[1].children[1].children[0].children[0].content

    # Second top-level item should also have nesting
    second_item = list_node.children[1]
    second_nested = second_item.children.find { |child| child.is_a?(ReVIEW::AST::ListNode) }
    assert_equal 'Level 2c', second_nested.children[0].children[0].content
  end

  def test_build_extremely_deep_nesting
    # Test 6-level deep nesting to verify robustness
    items = [
      create_list_item_data(:ul, 1, 'Level 1'),
      create_list_item_data(:ul, 2, 'Level 2'),
      create_list_item_data(:ul, 3, 'Level 3'),
      create_list_item_data(:ul, 4, 'Level 4'),
      create_list_item_data(:ul, 5, 'Level 5'),
      create_list_item_data(:ul, 6, 'Level 6'),
      create_list_item_data(:ul, 1, 'Back to Level 1')
    ]

    list_node = @assembler.build_unordered_list(items)

    assert_equal :ul, list_node.list_type
    assert_equal 2, list_node.children.size # Two top-level items

    # Navigate through all nesting levels
    current_item = list_node.children[0]
    current_level = 1

    while current_level < 6
      assert_equal current_level, current_item.level
      nested_list = current_item.children.find { |child| child.is_a?(ReVIEW::AST::ListNode) }
      next unless current_level < 6

      current_item = nested_list.children[0]
      current_level += 1
    end

    # Verify the deepest level
    assert_equal 6, current_item.level
  end

  def test_build_irregular_nesting_pattern
    # Test jumping nesting levels (1->3) - should log error and adjust level
    items = [
      create_list_item_data(:ul, 1, 'Level 1'),
      create_list_item_data(:ul, 3, 'Jump to Level 3') # Invalid jump -> adjusted to level 2
    ]

    # Should log error but continue processing (HTMLBuilder behavior)
    # Level 3 will be adjusted to level 2 (previous_level + 1)
    list_node = @assembler.build_unordered_list(items)

    # Should successfully create list with adjusted levels
    assert_instance_of(ReVIEW::AST::ListNode, list_node)
    assert_equal :ul, list_node.list_type
    assert_equal 1, list_node.children.size # One top-level item

    # First item should have nested list with adjusted level
    first_item = list_node.children[0]
    nested_list = first_item.children.find { |child| child.is_a?(ReVIEW::AST::ListNode) }
    assert_not_nil(nested_list, 'First item should have nested list')
    assert_equal 1, nested_list.children.size

    # Nested item should be at level 2 (adjusted from 3)
    nested_item = nested_list.children[0]
    assert_equal 2, nested_item.level
  end
end
