# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require_relative 'text_node'
require_relative 'resolved_data'

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
        # Display resolved_data's item_id if resolved, otherwise display original reference ID
        # This content is used for debugging/display purposes in the AST
        content = if resolved_data
                    resolved_data.item_id || ref_id
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

      # Override to_h to include ReferenceNode-specific attributes
      def to_h
        result = {
          type: self.class.name.split('::').last,
          location: location_to_h
        }
        result[:content] = content if content
        result[:ref_id] = @ref_id
        result[:context_id] = @context_id if @context_id
        if @resolved_data
          # Pass default options to serialize_to_hash
          options = ReVIEW::AST::JSONSerializer::Options.new
          result[:resolved_data] = @resolved_data.serialize_to_hash(options)
        end
        result
      end

      # Override serialize_to_hash to include ReferenceNode-specific attributes
      def serialize_to_hash(options = nil)
        options ||= ReVIEW::AST::JSONSerializer::Options.new

        # Start with type
        hash = {
          type: self.class.name.split('::').last
        }

        # Include location information
        if options.include_location
          hash[:location] = location_to_h
        end

        # Add TextNode's content (inherited from TextNode)
        hash[:content] = content if content

        # Add ReferenceNode-specific attributes
        hash[:ref_id] = @ref_id
        hash[:context_id] = @context_id if @context_id
        if @resolved_data
          hash[:resolved_data] = @resolved_data.serialize_to_hash
        end

        hash
      end

      def self.deserialize_from_hash(hash)
        resolved_data = if hash['resolved_data']
                          ReVIEW::AST::ResolvedData.deserialize_from_hash(hash['resolved_data'])
                        end
        new(
          hash['ref_id'],
          hash['context_id'],
          location: ReVIEW::AST::JSONSerializer.restore_location(hash),
          resolved_data: resolved_data
        )
      end

      private

      def location_to_h
        return nil unless location

        {
          filename: location.filename,
          lineno: location.lineno
        }
      end
    end
  end
end
