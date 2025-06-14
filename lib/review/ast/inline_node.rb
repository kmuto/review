# frozen_string_literal: true

require 'review/ast/node'

module ReVIEW
  module AST
    class InlineNode < Node
      attr_accessor :inline_type, :args

      def initialize(location = nil)
        super
        @inline_type = nil
        @args = nil
      end

      def to_h
        super.merge(
          inline_type: inline_type,
          args: args
        )
      end

      protected

      def serialize_properties(hash, options)
        hash[:children] = children.map { |child| child.serialize_to_hash(options) }
        hash[:inline_type] = inline_type
        hash[:args] = args
        hash
      end
    end
  end
end
