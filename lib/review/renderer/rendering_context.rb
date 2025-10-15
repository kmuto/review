# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/renderer/footnote_collector'

module ReVIEW
  module Renderer
    # RenderingContext - Manages rendering state and context for AST renderers
    #
    # This class provides automatic scope management for rendering contexts,
    # replacing the manual @doc_status flag management with a cleaner,
    # context-aware approach.
    #
    # Key responsibilities:
    # - Track current rendering context (table, caption, minicolumn, etc.)
    # - Manage parent-child context relationships for nested structures
    # - Determine when footnotes require special handling (footnotetext vs footnote)
    # - Collect and process footnotes within problematic contexts
    # - Provide automatic cleanup when contexts end
    class RenderingContext
      attr_reader :context_type, :parent_context, :footnote_collector

      # Context types that require footnotetext instead of direct footnote
      FOOTNOTETEXT_REQUIRED_CONTEXTS = %i[table caption minicolumn column dt].freeze

      def initialize(context_type, parent_context = nil)
        @context_type = context_type
        @parent_context = parent_context
        @footnote_collector = FootnoteCollector.new
      end

      # Determines if footnotes in this context require footnotetext handling
      # @return [Boolean] true if footnotetext is required
      def requires_footnotetext?
        footnotetext_context? || parent_requires_footnotetext?
      end

      # Check if this specific context requires footnotetext
      # @return [Boolean] true if this context type requires footnotetext
      def footnotetext_context?
        FOOTNOTETEXT_REQUIRED_CONTEXTS.include?(@context_type)
      end

      # Create and yield a child context, ensuring proper cleanup
      # @param child_type [Symbol] the type of child context
      # @yield [RenderingContext] the child context
      # @return [Object] the result of the block
      def with_child_context(child_type)
        child_context = RenderingContext.new(child_type, self)
        result = yield(child_context)

        # Process any collected footnotes when the context ends
        if child_context.footnotes?
          process_collected_footnotes(child_context)
        end

        result
      end

      # Add a footnote to this context's collector
      # @param footnote_node [AST::FootnoteNode] the footnote node
      # @param footnote_number [Integer] the footnote number
      def collect_footnote(footnote_node, footnote_number)
        @footnote_collector.add(footnote_node, footnote_number)
      end

      # Check if any footnotes have been collected in this context
      # @return [Boolean] true if footnotes were collected
      def footnotes?
        @footnote_collector.any?
      end

      # Get the root context (top-level ancestor)
      # @return [RenderingContext] the root context
      def root_context
        current = self
        current = current.parent_context while current.parent_context
        current
      end

      # Get the depth of this context (0 for root)
      # @return [Integer] context depth
      def depth
        current = self
        depth = 0
        while current.parent_context
          depth += 1
          current = current.parent_context
        end
        depth
      end

      # Check if this context is nested within a specific context type
      # @param target_type [Symbol] the context type to check for
      # @return [Boolean] true if nested within the target type
      def nested_in?(target_type)
        current = @parent_context
        while current
          return true if current.context_type == target_type

          current = current.parent_context
        end
        false
      end

      # Get a string representation for debugging
      # @return [String] string representation
      def to_s
        context_chain = ancestors.map(&:context_type)
        "RenderingContext[#{context_chain.join(' > ')}]"
      end

      # Get all ancestors (including self) in order from root to current
      # @return [Array<RenderingContext>] array of contexts
      def ancestors
        Enumerator.produce(self, &:parent_context).take_while(&:itself).reverse
      end

      private

      # Check if parent context requires footnotetext
      # @return [Boolean] true if any parent requires footnotetext
      def parent_requires_footnotetext?
        @parent_context&.requires_footnotetext? || false
      end

      # Process collected footnotes when a context ends
      # @param context [RenderingContext] the context that ended
      def process_collected_footnotes(context)
        # This method will be called by renderers to output collected footnotes
        # The actual processing is renderer-specific and will be handled by
        # the renderer that created this context
        #
        # For now, this is a hook that renderers can override or respond to
        # by checking has_collected_footnotes? after with_child_context returns
      end
    end
  end
end
