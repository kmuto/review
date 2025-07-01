# frozen_string_literal: true

require File.expand_path('test_helper', __dir__)
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

    # Resolve
    node.resolve!('図1.1　サンプル図')

    # After resolution
    assert_true(node.resolved?)
    assert_equal '図1.1　サンプル図', node.content
  end

  def test_reference_node_resolution_with_nil
    node = ReVIEW::AST::ReferenceNode.new('missing')

    # Resolve with nil (reference not found) - should use ref_id as fallback
    node.resolve!(nil)

    # Should be marked as resolved with ref_id as content
    assert_true(node.resolved?)
    assert_equal 'missing', node.content
  end

  def test_reference_node_to_s
    node = ReVIEW::AST::ReferenceNode.new('figure1')
    assert_include(node.to_s, 'ReferenceNode')
    assert_include(node.to_s, '{figure1}')
    assert_include(node.to_s, 'unresolved')

    node.resolve!('図1.1')
    assert_include(node.to_s, 'resolved: 図1.1')
  end

  def test_reference_node_with_context_to_s
    node = ReVIEW::AST::ReferenceNode.new('Introduction', 'chapter1')
    assert_include(node.to_s, '{chapter1|Introduction}')
  end

  def test_reference_node_reset
    node = ReVIEW::AST::ReferenceNode.new('figure1')

    # Resolve first
    node.resolve!('図1.1')
    assert_true(node.resolved?)
    assert_equal '図1.1', node.content

    # Reset
    node.reset!
    assert_false(node.resolved?)
    assert_equal 'figure1', node.content
  end
end
