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
        super.merge(
          content: content
        )
      end
    end
  end
end
