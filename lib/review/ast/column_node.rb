# frozen_string_literal: true

require 'review/ast/node'
require 'review/ast/caption_node'

module ReVIEW
  module AST
    class ColumnNode < Node
      attr_accessor :caption_node
      attr_reader :level, :label, :caption, :column_type

      def initialize(location: nil, level: nil, label: nil, caption: nil, caption_node: nil, column_type: 'column', **kwargs)
        super(location: location, **kwargs)
        @level = level
        @label = label
        @caption_node = caption_node
        @caption = caption
        @column_type = column_type
      end

      def to_h
        super.merge(
          level: level,
          label: label,
          caption: caption,
          caption_node: caption_node&.to_h,
          column_type: column_type
        )
      end

      private

      def serialize_properties(hash, options)
        hash[:children] = children.map { |child| child.serialize_to_hash(options) }
        hash[:level] = level
        hash[:label] = label
        hash[:caption_node] = caption_node&.serialize_to_hash(options) if caption_node
        hash[:column_type] = column_type
        hash
      end
    end
  end
end
