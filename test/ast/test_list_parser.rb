# frozen_string_literal: true

require_relative '../test_helper'
require 'review/ast/list_parser'
require 'review/lineinput'
require 'stringio'

class TestListParser < Test::Unit::TestCase
  def setup
    @parser = ReVIEW::AST::ListParser.new
  end

  def create_line_input(content)
    ReVIEW::LineInput.from_string(content)
  end

  # Test unordered list parsing
  def test_parse_unordered_list_single_level
    input = create_line_input(
      "   * First item\n" +
      "   * Second item\n" +
      "   * Third item\n"
    )

    items = @parser.parse_unordered_list(input)

    assert_equal 3, items.size
    assert_equal :ul, items[0].type
    assert_equal 1, items[0].level
    assert_equal 'First item', items[0].content
    assert_equal [], items[0].continuation_lines
  end

  def test_parse_unordered_list_nested
    input = create_line_input(
      "   * First level item\n" +
      "   ** Second level item\n" +
      "   *** Third level item\n" +
      "   * Back to first level\n"
    )

    items = @parser.parse_unordered_list(input)

    assert_equal 4, items.size
    assert_equal 1, items[0].level
    assert_equal 'First level item', items[0].content
    assert_equal 2, items[1].level
    assert_equal 'Second level item', items[1].content
    assert_equal 3, items[2].level
    assert_equal 'Third level item', items[2].content
    assert_equal 1, items[3].level
    assert_equal 'Back to first level', items[3].content
  end

  def test_parse_unordered_list_with_continuation
    input = create_line_input(
      "   * First item\n" +
      "     continuation line 1\n" +
      "     continuation line 2\n" +
      "   * Second item\n"
    )

    items = @parser.parse_unordered_list(input)

    assert_equal 2, items.size
    assert_equal 'First item', items[0].content
    assert_equal ['continuation line 1', 'continuation line 2'], items[0].continuation_lines
    assert_equal 'Second item', items[1].content
    assert_equal [], items[1].continuation_lines
  end

  def test_parse_unordered_list_with_comments
    input = create_line_input(
      "   * First item\n" +
      "   #@# This is a comment\n" +
      "   * Second item\n"
    )

    items = @parser.parse_unordered_list(input)

    assert_equal 2, items.size
    assert_equal 'First item', items[0].content
    assert_equal 'Second item', items[1].content
  end

  # Test ordered list parsing
  def test_parse_ordered_list_single_level
    input = create_line_input(
      "   1. First item\n" +
      "   2. Second item\n" +
      "   3. Third item\n"
    )

    items = @parser.parse_ordered_list(input)

    assert_equal 3, items.size
    assert_equal :ol, items[0].type
    assert_equal 1, items[0].level
    assert_equal 'First item', items[0].content
    assert_equal 1, items[0].metadata[:number]
    assert_equal '1', items[0].metadata[:number_string]
  end

  def test_parse_ordered_list_nested_levels
    input = create_line_input(
      "   1. First level\n" +
      "   11. First level\n" +
      "   111. First level\n" +
      "   2. First level\n"
    )

    items = @parser.parse_ordered_list(input)

    assert_equal 4, items.size
    assert_equal 1, items[0].level
    assert_equal 1, items[1].level
    assert_equal 1, items[2].level
    assert_equal 1, items[3].level
    assert_equal 11, items[1].metadata[:number]
    assert_equal 111, items[2].metadata[:number]
  end

  def test_parse_ordered_list_with_continuation
    input = create_line_input(
      "   1. First item\n" +
      "      continuation line\n" +
      "   2. Second item\n"
    )

    items = @parser.parse_ordered_list(input)

    assert_equal 2, items.size
    assert_equal 'First item', items[0].content
    assert_equal ['continuation line'], items[0].continuation_lines
  end

  # Test definition list parsing
  def test_parse_definition_list
    input = create_line_input(
      "   : Term 1\n" +
      "     Definition 1\n" +
      "   : Term 2\n" +
      "     Definition 2 line 1\n" +
      "     Definition 2 line 2\n"
    )

    items = @parser.parse_definition_list(input)

    assert_equal 2, items.size
    assert_equal :dl, items[0].type
    assert_equal 1, items[0].level
    assert_equal 'Term 1', items[0].content
    assert_equal ['Definition 1'], items[0].continuation_lines
    assert_equal 'Term 2', items[1].content
    assert_equal ['Definition 2 line 1', 'Definition 2 line 2'], items[1].continuation_lines
  end

  def test_parse_definition_list_with_inline_markup
    input = create_line_input(
      "   : @<b>{Bold Term}\n" +
      "     Definition with @<code>{inline code}\n"
    )

    items = @parser.parse_definition_list(input)

    assert_equal 1, items.size
    assert_equal '@<b>{Bold Term}', items[0].content
    assert_equal ['Definition with @<code>{inline code}'], items[0].continuation_lines
  end

  # Test edge cases
  def test_parse_empty_input
    input = create_line_input('')

    ul_items = @parser.parse_unordered_list(input)
    assert_equal [], ul_items

    input = create_line_input('')
    ol_items = @parser.parse_ordered_list(input)
    assert_equal [], ol_items

    input = create_line_input('')
    dl_items = @parser.parse_definition_list(input)
    assert_equal [], dl_items
  end

  def test_parse_malformed_lines
    # Test unordered list with malformed lines
    input = create_line_input(
      "   * Valid item\n" +
      "   Invalid line without marker\n" +
      "   * Another valid item\n"
    )

    items = @parser.parse_unordered_list(input)
    assert_equal 2, items.size
    assert_equal 'Valid item', items[0].content
    assert_equal 'Another valid item', items[1].content
  end

  def test_list_item_data_structure
    input = create_line_input(' * Test item')
    items = @parser.parse_unordered_list(input)

    item = items[0]
    assert_instance_of(ReVIEW::AST::ListParser::ListItemData, item)
    assert_equal :ul, item.type
    assert_equal 1, item.level
    assert_equal 'Test item', item.content
    assert_equal [], item.continuation_lines
    assert_instance_of(Hash, item.metadata)
  end

  def test_metadata_preservation
    input = create_line_input(' ** Nested item')
    items = @parser.parse_unordered_list(input)

    item = items[0]
    assert_equal 2, item.metadata[:stars]
    assert_equal 1, item.metadata[:indent_spaces]
  end
end
