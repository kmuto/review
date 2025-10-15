# frozen_string_literal: true

require 'review/ast/node'

module ReVIEW
  module AST
    # BlockNode - Generic block container node
    # Used for various block-level constructs like quote, read, etc.
    class BlockNode < Node
      attr_accessor :block_type, :args, :caption

      def initialize(location: nil, block_type: nil, args: nil, caption: nil, **kwargs)
        super(location: location, **kwargs)
        @block_type = block_type # :quote, :read, etc.
        @args = args
        @caption = caption
      end

      def to_h
        result = super.merge(
          block_type: block_type
        )
        result[:args] = args if args
        result[:caption] = caption if caption
        result
      end

      private

      def serialize_properties(hash, options)
        hash[:block_type] = block_type
        hash[:args] = args if args
        hash[:caption] = caption if caption
        if options.include_empty_arrays || children.any?
          hash[:children] = children.map { |child| child.serialize_to_hash(options) }
        end
        hash
      end
    end
  end
end
