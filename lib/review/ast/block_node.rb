# frozen_string_literal: true

require 'review/ast/node'
require 'review/ast/caption_node'

module ReVIEW
  module AST
    # BlockNode - Generic block container node
    # Used for various block-level constructs like quote, read, etc.
    class BlockNode < Node
      attr_accessor :caption_node
      attr_reader :block_type, :args, :caption, :lines

      def initialize(location: nil, block_type: nil, args: nil, caption: nil, caption_node: nil, lines: nil, **kwargs)
        super(location: location, **kwargs)
        @block_type = block_type # :quote, :read, etc.
        @args = args || []
        @caption_node = caption_node
        @caption = caption
        @lines = lines # Optional: original lines for blocks like box, insn
      end

      def to_h
        result = super.merge(
          block_type: block_type
        )
        result[:args] = args if args
        result[:caption] = caption if caption
        result[:caption_node] = caption_node&.to_h if caption_node
        result
      end

      private

      def serialize_properties(hash, options)
        hash[:block_type] = block_type
        hash[:args] = args if args
        hash[:caption_node] = caption_node&.serialize_to_hash(options) if caption_node
        if options.include_empty_arrays || children.any?
          hash[:children] = children.map { |child| child.serialize_to_hash(options) }
        end
        hash
      end
    end
  end
end
