# frozen_string_literal: true

require 'review/ast/node'

module ReVIEW
  module AST
    class ParagraphNode < Node
      def initialize(location = nil)
        super
      end

      def to_h
        # ParagraphNode uses only children array for content storage
        # Text content is stored as TextNode children
        super
      end
    end
  end
end
