# frozen_string_literal: true

module ReVIEW
  module AST
    # Provides common functionality for nodes that have a caption_node attribute
    #
    # Classes that include this module should:
    # - Have an attr_accessor :caption_node
    # - Call serialize_caption_to_hash in serialize_properties
    # - Call deserialize_caption_from_hash in deserialize_from_hash
    module Captionable
      def caption_node
        @caption_node
      end

      # Get caption text from caption_node
      # @return [String] caption text or empty string if no caption
      def caption_text
        caption_node&.to_inline_text || ''
      end

      # Check if this node has a caption
      # @return [Boolean] true if caption_node exists
      def caption?
        !caption_node.nil?
      end

      # Helper method to serialize caption_node to hash
      # @param hash [Hash] hash to add caption_node to
      # @param options [JSONSerializer::Options] serialization options
      # @return [Hash] the modified hash
      def serialize_caption_to_hash(hash, options)
        hash[:caption_node] = caption_node&.serialize_to_hash(options) if caption_node
        hash
      end

      module ClassMethods
        # Helper method to deserialize caption_node from hash
        # @param hash [Hash] hash containing caption data
        # @return [CaptionNode, nil] deserialized caption node or nil
        def deserialize_caption_from_hash(hash)
          _, caption_node = ReVIEW::AST::JSONSerializer.deserialize_caption_fields(hash)
          caption_node
        end
      end

      def self.included(base)
        base.extend(ClassMethods)
      end
    end
  end
end
