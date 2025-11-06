# frozen_string_literal: true

require 'review/ast/node'
require 'review/ast/caption_node'

module ReVIEW
  module AST
    # BlockNode - Generic block container node
    # Used for various block-level constructs like quote, read, etc.
    class BlockNode < Node
      attr_accessor :caption_node
      attr_reader :block_type, :args

      def initialize(location:, block_type:, args: nil, caption_node: nil, **kwargs)
        super(location: location, **kwargs)
        @block_type = block_type # :quote, :read, etc.
        @args = args || []
        @caption_node = caption_node
      end

      # Get caption text from caption_node
      def caption_text
        caption_node&.to_text || ''
      end

      # Check if this block has a caption
      def caption?
        !caption_node.nil?
      end

      def to_h
        result = super.merge(
          block_type: block_type
        )
        result[:args] = args if args
        result[:caption_node] = caption_node&.to_h if caption_node
        result
      end

      private

      def serialize_properties(hash, options)
        hash[:block_type] = block_type
        hash[:args] = args if args
        hash[:caption_node] = caption_node&.serialize_to_hash(options) if caption_node
        if children.any?
          hash[:children] = children.map { |child| child.serialize_to_hash(options) }
        end
        hash
      end
    end
  end
end
