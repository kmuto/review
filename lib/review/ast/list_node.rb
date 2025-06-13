# frozen_string_literal: true

require 'review/ast/node'

module ReVIEW
  module AST
    class ListNode < Node
      attr_accessor :list_type, :items

      def initialize(location = nil)
        super
        @list_type = nil # :ul, :ol, :dl
        @items = []
      end

      def to_h
        super.merge(
          list_type: list_type,
          items: items&.map(&:to_h)
        )
      end
    end

    class ListItemNode < Node
      attr_accessor :content, :level

      def initialize(location = nil)
        super
        @content = nil
        @level = 1
      end

      def to_h
        super.merge(
          content: content,
          level: level
        )
      end
    end
  end
end
