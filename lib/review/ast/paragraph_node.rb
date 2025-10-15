# frozen_string_literal: true

require 'review/ast/node'

module ReVIEW
  module AST
    class ParagraphNode < Node
      def initialize(location: nil, **kwargs)
        super
      end

      private

      def serialize_properties(hash, options)
        hash[:children] = children.map { |child| child.serialize_to_hash(options) }
        hash
      end
    end
  end
end
