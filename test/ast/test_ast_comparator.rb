# frozen_string_literal: true

require_relative '../test_helper'
require 'review/ast'
require 'review/ast/comparator'

class TestASTComparator < Test::Unit::TestCase
  def setup
    @comparator = ReVIEW::AST::Comparator.new
    @location = ReVIEW::SnapshotLocation.new('test.re', 1)
  end

  def test_compare_identical_text_nodes
    node1 = ReVIEW::AST::TextNode.new(location: @location, content: 'Hello')
    node2 = ReVIEW::AST::TextNode.new(location: @location, content: 'Hello')

    result = @comparator.compare(node1, node2)
    assert_true(result.equal?)
    assert_equal('AST nodes are equivalent', result.to_s)
  end

  def test_compare_different_text_nodes
    node1 = ReVIEW::AST::TextNode.new(location: @location, content: 'Hello')
    node2 = ReVIEW::AST::TextNode.new(location: @location, content: 'World')

    result = @comparator.compare(node1, node2)
    assert_false(result.equal?)
    assert_match(/text content mismatch/, result.to_s)
  end

  def test_compare_nil_nodes
    result = @comparator.compare(nil, nil)
    assert_true(result.equal?)
  end

  def test_compare_nil_vs_non_nil
    node1 = ReVIEW::AST::TextNode.new(location: @location, content: 'Hello')
    result = @comparator.compare(node1, nil)
    assert_false(result.equal?)
    assert_match(/node2 is nil/, result.to_s)
  end

  def test_compare_different_node_types
    node1 = ReVIEW::AST::TextNode.new(location: @location, content: 'Hello')
    node2 = ReVIEW::AST::ParagraphNode.new(location: @location)

    result = @comparator.compare(node1, node2)
    assert_false(result.equal?)
    assert_match(/node types differ/, result.to_s)
  end

  def test_compare_headlines_with_same_attributes
    caption1 = ReVIEW::AST::CaptionNode.new(location: @location)
    caption1.add_child(ReVIEW::AST::TextNode.new(location: @location, content: 'Title'))

    caption2 = ReVIEW::AST::CaptionNode.new(location: @location)
    caption2.add_child(ReVIEW::AST::TextNode.new(location: @location, content: 'Title'))

    node1 = ReVIEW::AST::HeadlineNode.new(location: @location, level: 2, label: 'intro', caption_node: caption1)
    node2 = ReVIEW::AST::HeadlineNode.new(location: @location, level: 2, label: 'intro', caption_node: caption2)

    result = @comparator.compare(node1, node2)
    assert_true(result.equal?)
  end

  def test_compare_headlines_with_different_levels
    caption1 = ReVIEW::AST::CaptionNode.new(location: @location)
    caption1.add_child(ReVIEW::AST::TextNode.new(location: @location, content: 'Title'))

    caption2 = ReVIEW::AST::CaptionNode.new(location: @location)
    caption2.add_child(ReVIEW::AST::TextNode.new(location: @location, content: 'Title'))

    node1 = ReVIEW::AST::HeadlineNode.new(location: @location, level: 2, label: 'intro', caption_node: caption1)
    node2 = ReVIEW::AST::HeadlineNode.new(location: @location, level: 3, label: 'intro', caption_node: caption2)

    result = @comparator.compare(node1, node2)
    assert_false(result.equal?)
    assert_match(/headline level mismatch/, result.to_s)
  end

  def test_compare_nodes_with_children
    para1 = ReVIEW::AST::ParagraphNode.new(location: @location)
    para1.add_child(ReVIEW::AST::TextNode.new(location: @location, content: 'Hello'))
    para1.add_child(ReVIEW::AST::TextNode.new(location: @location, content: 'World'))

    para2 = ReVIEW::AST::ParagraphNode.new(location: @location)
    para2.add_child(ReVIEW::AST::TextNode.new(location: @location, content: 'Hello'))
    para2.add_child(ReVIEW::AST::TextNode.new(location: @location, content: 'World'))

    result = @comparator.compare(para1, para2)
    assert_true(result.equal?)
  end

  def test_compare_nodes_with_different_child_count
    para1 = ReVIEW::AST::ParagraphNode.new(location: @location)
    para1.add_child(ReVIEW::AST::TextNode.new(location: @location, content: 'Hello'))

    para2 = ReVIEW::AST::ParagraphNode.new(location: @location)
    para2.add_child(ReVIEW::AST::TextNode.new(location: @location, content: 'Hello'))
    para2.add_child(ReVIEW::AST::TextNode.new(location: @location, content: 'World'))

    result = @comparator.compare(para1, para2)
    assert_false(result.equal?)
    assert_match(/children count mismatch/, result.to_s)
  end

  def test_compare_code_blocks_with_lang
    code1 = ReVIEW::AST::CodeBlockNode.new(location: @location, id: 'sample', lang: 'ruby')
    code2 = ReVIEW::AST::CodeBlockNode.new(location: @location, id: 'sample', lang: 'ruby')

    result = @comparator.compare(code1, code2)
    assert_true(result.equal?)
  end

  def test_compare_code_blocks_with_different_lang
    code1 = ReVIEW::AST::CodeBlockNode.new(location: @location, id: 'sample', lang: 'ruby')
    code2 = ReVIEW::AST::CodeBlockNode.new(location: @location, id: 'sample', lang: 'python')

    result = @comparator.compare(code1, code2)
    assert_false(result.equal?)
    assert_match(/code block lang mismatch/, result.to_s)
  end

  def test_compare_inline_nodes
    inline1 = ReVIEW::AST::InlineNode.new(location: @location, inline_type: 'b')
    inline2 = ReVIEW::AST::InlineNode.new(location: @location, inline_type: 'b')

    result = @comparator.compare(inline1, inline2)
    assert_true(result.equal?)
  end

  def test_compare_inline_nodes_different_type
    inline1 = ReVIEW::AST::InlineNode.new(location: @location, inline_type: 'b')
    inline2 = ReVIEW::AST::InlineNode.new(location: @location, inline_type: 'i')

    result = @comparator.compare(inline1, inline2)
    assert_false(result.equal?)
    assert_match(/inline type mismatch/, result.to_s)
  end

  def test_comparison_result_with_path
    node1 = ReVIEW::AST::TextNode.new(location: @location, content: 'Hello')
    node2 = ReVIEW::AST::TextNode.new(location: @location, content: 'World')

    result = @comparator.compare(node1, node2, 'custom.path')
    assert_false(result.equal?)
    assert_match(/custom\.path/, result.to_s)
  end

  def test_multiple_differences
    para1 = ReVIEW::AST::ParagraphNode.new(location: @location)
    para1.add_child(ReVIEW::AST::TextNode.new(location: @location, content: 'Hello'))
    para1.add_child(ReVIEW::AST::TextNode.new(location: @location, content: 'World'))

    para2 = ReVIEW::AST::ParagraphNode.new(location: @location)
    para2.add_child(ReVIEW::AST::TextNode.new(location: @location, content: 'Goodbye'))
    para2.add_child(ReVIEW::AST::TextNode.new(location: @location, content: 'Moon'))

    result = @comparator.compare(para1, para2)
    assert_false(result.equal?)
    # Should have 2 differences (one for each child)
    assert_equal(2, result.differences.size)
  end
end
