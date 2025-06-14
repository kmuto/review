# frozen_string_literal: true

require 'review/ast/node'

module ReVIEW
  module AST
    class EmbedNode < Node
      attr_accessor :lines, :arg, :embed_type

      def initialize(location = nil)
        super
        @lines = []
        @arg = nil
        @embed_type = :block # :block or :inline
      end

      def to_h
        super.merge(
          lines: lines,
          arg: arg,
          embed_type: embed_type
        )
      end

      protected

      def serialize_properties(hash, _options)
        hash[:lines] = lines
        hash[:arg] = arg
        hash[:embed_type] = embed_type
        hash
      end
    end
  end
end
