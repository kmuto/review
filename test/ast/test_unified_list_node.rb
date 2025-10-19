# frozen_string_literal: true

require_relative '../test_helper'
require 'review/ast/list_node'
require 'review/ast/text_node'
require 'review/snapshot_location'
require 'stringio'

class TestUnifiedListNode < Test::Unit::TestCase
  def setup
    @location = ReVIEW::SnapshotLocation.new('test', 1)
  end

  def test_list_node_initialization
    # Test basic initialization
    node = ReVIEW::AST::ListNode.new(location: @location, list_type: :ul)
    assert_equal :ul, node.list_type
    assert_nil(node.start_number)
    assert node.ul?
    assert_false(node.ol?)
    assert_false(node.dl?)
  end

  def test_ordered_list_with_start_number
    # Test ordered list with start number
    node = ReVIEW::AST::ListNode.new(
      location: @location,
      list_type: :ol,
      start_number: 5
    )
    assert_equal :ol, node.list_type
    assert_equal 5, node.start_number
    assert node.ol?
    assert_false(node.ul?)
    assert_false(node.dl?)
  end

  def test_definition_list
    # Test definition list
    node = ReVIEW::AST::ListNode.new(location: @location, list_type: :dl)
    assert_equal :dl, node.list_type
    assert_nil(node.start_number)
    assert node.dl?
    assert_false(node.ol?)
    assert_false(node.ul?)
  end

  def test_convenience_methods
    # Test all convenience methods
    ul = ReVIEW::AST::ListNode.new(location: @location, list_type: :ul)
    ol = ReVIEW::AST::ListNode.new(location: @location, list_type: :ol)
    dl = ReVIEW::AST::ListNode.new(location: @location, list_type: :dl)

    # Unordered list checks
    assert ul.ul?
    assert_false(ul.ol?)
    assert_false(ul.dl?)

    # Ordered list checks
    assert_false(ol.ul?)
    assert ol.ol?
    assert_false(ol.dl?)

    # Definition list checks
    assert_false(dl.ul?)
    assert_false(dl.ol?)
    assert dl.dl?
  end

  def test_to_h_serialization
    # Test serialization without start_number
    node = ReVIEW::AST::ListNode.new(location: @location, list_type: :ul)
    hash = node.to_h
    assert_equal :ul, hash[:list_type]
    assert_false(hash.key?(:start_number))

    # Test serialization with start_number = 1 (should not be included)
    node = ReVIEW::AST::ListNode.new(
      location: @location,
      list_type: :ol,
      start_number: 1
    )
    hash = node.to_h
    assert_equal :ol, hash[:list_type]
    assert_false(hash.key?(:start_number))

    # Test serialization with start_number != 1 (should be included)
    node = ReVIEW::AST::ListNode.new(
      location: @location,
      list_type: :ol,
      start_number: 5
    )
    hash = node.to_h
    assert_equal :ol, hash[:list_type]
    assert_equal 5, hash[:start_number]
  end

  def test_serialization_properties
    # Test serialize_properties method
    node = ReVIEW::AST::ListNode.new(
      location: @location,
      list_type: :ol,
      start_number: 3
    )

    options = ReVIEW::AST::JSONSerializer::Options.new
    hash = {}
    node.send(:serialize_properties, hash, options)

    assert_equal :ol, hash[:list_type]
    assert_equal 3, hash[:start_number]
  end

  def test_serialization_properties_default_start_number
    # Test serialize_properties with default start_number (should not be serialized)
    node = ReVIEW::AST::ListNode.new(
      location: @location,
      list_type: :ol,
      start_number: 1
    )

    options = ReVIEW::AST::JSONSerializer::Options.new
    hash = {}
    node.send(:serialize_properties, hash, options)

    assert_equal :ol, hash[:list_type]
    assert_false(hash.key?(:start_number))
  end

  def test_list_item_compatibility
    # Test that ListItemNode still works with unified ListNode
    list_node = ReVIEW::AST::ListNode.new(location: @location, list_type: :ul)
    item_node = ReVIEW::AST::ListItemNode.new(location: @location)
    text_node = ReVIEW::AST::TextNode.new(location: @location, content: 'Test item')
    item_node.add_child(text_node)

    list_node.add_child(item_node)

    assert_equal 1, list_node.children.size
    assert_kind_of(ReVIEW::AST::ListItemNode, list_node.children.first)
    text_child = list_node.children.first.children.find { |c| c.is_a?(ReVIEW::AST::TextNode) }
    assert_equal 'Test item', text_child.content
  end

  def test_backwards_compatibility_type_checking
    # Test that both old and new type checking methods work
    node = ReVIEW::AST::ListNode.new(location: @location, list_type: :ul)

    # New way (recommended)
    assert node.is_a?(ReVIEW::AST::ListNode)
    assert node.ul?

    # Type + attribute check
    assert node.is_a?(ReVIEW::AST::ListNode) && node.ul?
  end
end
