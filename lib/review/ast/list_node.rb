# frozen_string_literal: true

require 'review/ast/node'

module ReVIEW
  module AST
    class ListNode < Node
      attr_accessor :list_type, :items

      def initialize(location: nil, list_type: nil, items: [], **kwargs)
        super(location: location, **kwargs)
        @list_type = list_type # :ul, :ol, :dl
        @items = items
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

      def initialize(location: nil, content: nil, level: 1, number: nil, **kwargs)
        super(location: location, content: content, **kwargs)
        @content = content
        @level = level
        @number = number
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
