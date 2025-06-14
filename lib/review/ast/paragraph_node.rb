# frozen_string_literal: true

require 'review/ast/node'

module ReVIEW
  module AST
    class ParagraphNode < Node
      attr_accessor :content

      def initialize(location = nil)
        super
        @content = nil
      end

      def to_h
        # For paragraph nodes, we don't include the content field in the serialization
        # Only include the base Node fields (type, location, children)
        super
      end
    end
  end
end
