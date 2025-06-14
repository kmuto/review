# frozen_string_literal: true

require 'review/ast/node'

module ReVIEW
  module AST
    class TextNode < Node
      attr_accessor :content

      def initialize(location = nil)
        super
        @content = ''
      end

      def to_h
        super.merge(
          content: content
        )
      end

      protected

      def serialize_properties(hash, _options)
        hash[:children] = []
        hash[:content] = content
        hash
      end
    end
  end
end
