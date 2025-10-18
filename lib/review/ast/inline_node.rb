# frozen_string_literal: true

require 'review/ast/node'

module ReVIEW
  module AST
    class InlineNode < Node
      attr_reader :inline_type, :args

      def initialize(location: nil, inline_type: nil, args: nil, **kwargs)
        super(location: location, **kwargs)
        @inline_type = inline_type
        @args = args || []
      end

      def to_h
        super.merge(
          inline_type: inline_type,
          args: args
        )
      end

      # Returns the reference ID in the format expected by extract_chapter_id
      # For cross-chapter references (args.length >= 2), joins all elements with '|'
      # For simple references, returns the first arg
      # Falls back to nil if args is empty, allowing proper error handling in reference resolution
      #
      # @return [String, nil] The reference ID or nil
      def reference_id
        if args.length >= 2
          args.join('|')
        else
          args.first
        end
      end

      private

      def serialize_properties(hash, options)
        hash[:children] = children.map { |child| child.serialize_to_hash(options) }
        hash[:inline_type] = inline_type
        hash[:args] = args
        hash
      end
    end
  end
end
