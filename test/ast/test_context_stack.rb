# frozen_string_literal: true

require_relative '../test_helper'
require 'review/ast/markdown_adapter'

class TestContextStack < Test::Unit::TestCase
  # Mock node class for testing
  class MockNode
    attr_reader :children

    def initialize(name)
      @name = name
      @children = []
    end

    def add_child(child)
      @children << child
    end

    def to_s
      @name
    end
  end

  def setup
    @root = MockNode.new('root')
    @stack = ReVIEW::AST::MarkdownAdapter::ContextStack.new(@root)
  end

  def test_initialize
    assert_equal @root, @stack.current
    assert_true(@stack.empty?)
  end

  def test_push_and_pop
    child = MockNode.new('child')

    @stack.push(child)
    assert_equal child, @stack.current
    assert_false(@stack.empty?)
    assert_equal 2, @stack.depth

    @stack.pop
    assert_equal @root, @stack.current
    assert_true(@stack.empty?)
    assert_equal 1, @stack.depth
  end

  def test_with_context
    child = MockNode.new('child')
    result = nil

    @stack.with_context(child) do
      result = @stack.current
    end

    # Context should be restored after block
    assert_equal child, result
    assert_equal @root, @stack.current
  end

  def test_with_context_exception_safety
    child = MockNode.new('child')

    begin
      @stack.with_context(child) do
        raise 'Test error'
      end
    rescue StandardError
      # Exception caught
    end

    # Context should still be restored despite exception
    assert_equal @root, @stack.current
    assert_true(@stack.empty?)
  end

  def test_nested_contexts
    child1 = MockNode.new('child1')
    child2 = MockNode.new('child2')
    child3 = MockNode.new('child3')

    @stack.with_context(child1) do
      assert_equal child1, @stack.current
      assert_equal 2, @stack.depth

      @stack.with_context(child2) do
        assert_equal child2, @stack.current
        assert_equal 3, @stack.depth

        @stack.with_context(child3) do
          assert_equal child3, @stack.current
          assert_equal 4, @stack.depth
        end

        assert_equal child2, @stack.current
      end

      assert_equal child1, @stack.current
    end

    assert_equal @root, @stack.current
    assert_true(@stack.empty?)
  end

  def test_pop_from_empty_raises_error
    assert_raise(ReVIEW::CompileError) do
      @stack.pop
    end
  end

  def test_validate_success
    assert_nothing_raised do
      @stack.validate!
    end
  end

  def test_validate_nil_in_stack
    child = MockNode.new('child')
    @stack.push(child)

    # Manually corrupt the internal stack
    internal_stack = @stack.instance_variable_get(:@stack)
    internal_stack << nil

    assert_raise_message(/Context corruption: nil found in stack/) do
      @stack.validate!
    end
  end

  def test_depth
    assert_equal 1, @stack.depth

    child1 = MockNode.new('child1')
    @stack.push(child1)
    assert_equal 2, @stack.depth

    child2 = MockNode.new('child2')
    @stack.push(child2)
    assert_equal 3, @stack.depth

    @stack.pop
    assert_equal 2, @stack.depth

    @stack.pop
    assert_equal 1, @stack.depth
  end

  def test_empty
    assert_true(@stack.empty?)

    child = MockNode.new('child')
    @stack.push(child)
    assert_false(@stack.empty?)

    @stack.pop
    assert_true(@stack.empty?)
  end
end
