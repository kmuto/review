# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
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

        yield(child_context)
      end

      # Add a footnote to this context's collector
      # @param footnote_node [AST::FootnoteNode] the footnote node
      # @param footnote_number [Integer] the footnote number
      def collect_footnote(footnote_node, footnote_number)
        @footnote_collector.add(footnote_node, footnote_number)
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
    end
  end
end
