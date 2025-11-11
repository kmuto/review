# frozen_string_literal: true

# Copyright (c) 2025 Masayoshi Takahashi, Kenshi Muto
# License: MIT License

module ReVIEW
  module AST
    # ContextStack manages hierarchical context for AST node construction.
    # It provides exception-safe context switching with automatic cleanup.
    #
    # Usage:
    #   stack = ContextStack.new(root_node)
    #   stack.with_context(child_node) do
    #     # Process child node
    #     # Context automatically restored even if exception occurs
    #   end
    class ContextStack
      attr_reader :current

      def initialize(initial_context)
        @stack = []
        @current = initial_context
      end

      def push(node)
        @stack.push(@current)
        @current = node
      end

      def pop
        raise 'Cannot pop from empty context stack' if @stack.empty?

        @current = @stack.pop
      end

      def with_context(node)
        push(node)
        yield
      ensure
        pop
      end

      # @return [Integer] Stack depth (includes current context)
      def depth
        @stack.length + 1
      end

      def validate!
        if @current.nil?
          raise 'Context corruption: current node is nil'
        end

        if @stack.any?(&:nil?)
          raise 'Context corruption: nil found in stack'
        end
      end

      def empty?
        @stack.empty?
      end
    end
  end
end
