# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/ast/text_node'
require 'review/ast/resolved_data'

module ReVIEW
  module AST
    # ReferenceNode - node that holds reference information (used as a child of InlineNode)
    #
    # Placed as a child node of reference-type InlineNode instead of traditional TextNode.
    # This node is immutable, and a new instance is created when resolving references.
    class ReferenceNode < TextNode
      attr_reader :ref_id, :context_id, :resolved_data

      # @param ref_id [String] reference ID (primary reference target)
      # @param context_id [String] context ID (chapter ID, etc., optional)
      # @param resolved_data [ResolvedData, nil] structured resolved data
      # @param location [SnapshotLocation, nil] location in source code
      def initialize(ref_id, context_id = nil, location:, resolved_data: nil)
        # Display resolved_data if resolved, otherwise display original reference ID
        content = if resolved_data
                    resolved_data.to_text
                  else
                    context_id ? "#{context_id}|#{ref_id}" : ref_id
                  end

        super(content: content, location: location)

        @ref_id = ref_id
        @context_id = context_id
        @resolved_data = resolved_data
      end

      def reference_node?
        true
      end

      # Check if the reference has been resolved
      # @return [Boolean] true if resolved
      def resolved?
        !!@resolved_data
      end

      # Check if this is a cross-chapter reference
      # @return [Boolean] true if referencing another chapter
      def cross_chapter?
        !@context_id.nil?
      end

      # Return the full reference ID (concatenated with context_id if present)
      # @return [String] full reference ID
      def full_ref_id
        @context_id ? "#{@context_id}|#{@ref_id}" : @ref_id
      end

      # Return a new ReferenceNode instance resolved with structured data
      # @param data [ResolvedData] structured resolved data
      # @return [ReferenceNode] new resolved instance
      def with_resolved_data(data)
        self.class.new(
          @ref_id,
          @context_id,
          resolved_data: data,
          location: @location
        )
      end

      # Node description string for debugging
      # @return [String] debug string representation
      def to_s
        status = resolved? ? "resolved: #{@content}" : 'unresolved'
        "#<ReferenceNode {#{full_ref_id}} #{status}>"
      end
    end
  end
end
