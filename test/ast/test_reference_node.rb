# frozen_string_literal: true

require_relative '../test_helper'
require 'review/ast/reference_node'

class TestReferenceNode < Test::Unit::TestCase
  def test_reference_node_basic_creation
    node = ReVIEW::AST::ReferenceNode.new('figure1')

    assert_equal 'figure1', node.ref_id
    assert_nil(node.context_id)
    assert_false(node.resolved?)
    assert_equal 'figure1', node.content # 初期状態ではref_idが表示される
  end

  def test_reference_node_with_context
    node = ReVIEW::AST::ReferenceNode.new('Introduction', 'chapter1')

    assert_equal 'Introduction', node.ref_id
    assert_equal 'chapter1', node.context_id
    assert_false(node.resolved?)
    assert_equal 'chapter1|Introduction', node.content # 初期状態ではcontext_id|ref_idが表示される
  end

  def test_reference_node_resolution
    node = ReVIEW::AST::ReferenceNode.new('figure1')

    # Before resolution
    assert_false(node.resolved?)
    assert_equal 'figure1', node.content

    # Resolve (creates new instance)
    resolved_node = node.with_resolved_content('図1.1　サンプル図')

    # Original node should remain unchanged
    assert_false(node.resolved?)
    assert_equal 'figure1', node.content

    # Resolved node should have new content
    assert_true(resolved_node.resolved?)
    assert_equal '図1.1　サンプル図', resolved_node.content
    assert_equal 'figure1', resolved_node.ref_id
  end

  def test_reference_node_resolution_with_nil
    node = ReVIEW::AST::ReferenceNode.new('missing')

    # Resolve with nil (reference not found) - should use ref_id as fallback
    resolved_node = node.with_resolved_content(nil)

    # Original node should remain unchanged
    assert_false(node.resolved?)

    # Resolved node should be marked as resolved with ref_id as content
    assert_true(resolved_node.resolved?)
    assert_equal 'missing', resolved_node.content
  end

  def test_reference_node_to_s
    node = ReVIEW::AST::ReferenceNode.new('figure1')
    assert_include(node.to_s, 'ReferenceNode')
    assert_include(node.to_s, '{figure1}')
    assert_include(node.to_s, 'unresolved')

    resolved_node = node.with_resolved_content('図1.1')
    assert_include(resolved_node.to_s, 'resolved: 図1.1')
  end

  def test_reference_node_with_context_to_s
    node = ReVIEW::AST::ReferenceNode.new('Introduction', 'chapter1')
    assert_include(node.to_s, '{chapter1|Introduction}')
  end

  def test_reference_node_immutability
    # Test that ReferenceNode is immutable
    node = ReVIEW::AST::ReferenceNode.new('figure1')
    resolved_node = node.with_resolved_content('図1.1')

    # Original node should be unchanged
    assert_false(node.resolved?)
    assert_equal 'figure1', node.content

    # Resolved node should be different instance
    refute_same(node, resolved_node)
    assert_true(resolved_node.resolved?)
    assert_equal '図1.1', resolved_node.content

    # Both should have same ref_id
    assert_equal node.ref_id, resolved_node.ref_id
  end
end
