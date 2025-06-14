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

      protected

      def serialize_properties(hash, options)
        hash[:list_type] = list_type
        if options.include_empty_arrays || (items && items.any?)
          hash[:items] = items&.map { |item| item.serialize_to_hash(options) } || []
        end
        hash
      end
    end

    class ListItemNode < Node
      attr_accessor :content, :level, :number

      def initialize(location = nil)
        super
        @content = nil
        @level = 1
        @number = nil
      end

      def to_h
        result = super.merge(
          content: content,
          level: level
        )
        result[:number] = number if number
        result
      end

      protected

      def serialize_properties(hash, _options)
        hash[:content] = content
        hash[:level] = level
        hash[:number] = number if number
        hash
      end
    end
  end
end
