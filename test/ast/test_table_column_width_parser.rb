# frozen_string_literal: true

require_relative '../test_helper'
require 'review/ast/table_column_width_parser'

# Test TableColumnWidthParser
class TestTableColumnWidthParser < Test::Unit::TestCase
  def test_default_spec
    parser = ReVIEW::AST::TableColumnWidthParser.new(nil, 3)
    result = parser.parse
    assert_equal '|l|l|l|', result.col_spec
    assert_equal ['l', 'l', 'l'], result.cellwidth
  end

  def test_empty_spec
    parser = ReVIEW::AST::TableColumnWidthParser.new('', 3)
    result = parser.parse
    assert_equal '|l|l|l|', result.col_spec
    assert_equal ['l', 'l', 'l'], result.cellwidth
  end

  def test_simple_format
    parser = ReVIEW::AST::TableColumnWidthParser.new('10,18,50', 3)
    result = parser.parse
    assert_equal '|p{10mm}|p{18mm}|p{50mm}|', result.col_spec
    assert_equal ['p{10mm}', 'p{18mm}', 'p{50mm}'], result.cellwidth
  end

  def test_complex_format
    parser = ReVIEW::AST::TableColumnWidthParser.new('p{10mm}p{18mm}|p{50mm}', 3)
    result = parser.parse
    assert_equal 'p{10mm}p{18mm}|p{50mm}', result.col_spec
    assert_equal ['p{10mm}', 'p{18mm}', 'p{50mm}'], result.cellwidth
  end

  def test_complex_format_with_lcr
    parser = ReVIEW::AST::TableColumnWidthParser.new('|l|c|r|', 3)
    result = parser.parse
    assert_equal '|l|c|r|', result.col_spec
    assert_equal ['l', 'c', 'r'], result.cellwidth
  end

  def test_invalid_col_count_zero
    assert_raise(ArgumentError) do
      ReVIEW::AST::TableColumnWidthParser.new('10,20', 0)
    end
  end

  def test_invalid_col_count_negative
    assert_raise(ArgumentError) do
      ReVIEW::AST::TableColumnWidthParser.new('10,20', -1)
    end
  end

  def test_invalid_col_count_nil
    assert_raise(ArgumentError) do
      ReVIEW::AST::TableColumnWidthParser.new('10,20', nil)
    end
  end

  def test_simple_format_with_spaces
    parser = ReVIEW::AST::TableColumnWidthParser.new('10, 18, 50', 3)
    result = parser.parse
    assert_equal '|p{10mm}|p{18mm}|p{50mm}|', result.col_spec
    assert_equal ['p{10mm}', 'p{18mm}', 'p{50mm}'], result.cellwidth
  end

  def test_complex_with_mixed_alignment
    parser = ReVIEW::AST::TableColumnWidthParser.new('lcr', 3)
    result = parser.parse
    assert_equal 'lcr', result.col_spec
    assert_equal ['l', 'c', 'r'], result.cellwidth
  end

  def test_complex_with_pipes_and_braces
    parser = ReVIEW::AST::TableColumnWidthParser.new('|p{10mm}|p{18mm}|p{50mm}|', 3)
    result = parser.parse
    assert_equal '|p{10mm}|p{18mm}|p{50mm}|', result.col_spec
    assert_equal ['p{10mm}', 'p{18mm}', 'p{50mm}'], result.cellwidth
  end

  def test_parse_returns_struct
    parser = ReVIEW::AST::TableColumnWidthParser.new('10,20', 2)
    result = parser.parse
    assert_instance_of(ReVIEW::AST::TableColumnWidthParser::Result, result)
    assert result.respond_to?(:col_spec)
    assert result.respond_to?(:cellwidth)
  end

  def test_parse_can_be_called_multiple_times
    parser = ReVIEW::AST::TableColumnWidthParser.new('10,20', 2)
    result1 = parser.parse
    result2 = parser.parse
    assert_equal result1, result2
  end
end
