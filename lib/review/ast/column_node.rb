# frozen_string_literal: true

require 'review/ast/node'
require 'review/ast/caption_node'

module ReVIEW
  module AST
    class ColumnNode < Node
      attr_reader :level, :label, :caption, :column_type

      def initialize(location: nil, level: nil, label: nil, caption: nil, column_type: 'column', inline_processor: nil, **kwargs)
        super(location: location, **kwargs)
        @level = level
        @label = label
        @caption = if caption.is_a?(CaptionNode)
                     caption
                   else
                     CaptionNode.parse(caption, location: location, inline_processor: inline_processor)
                   end
        @column_type = column_type
      end

      def to_h
        super.merge(
          level: level,
          label: label,
          caption: caption&.to_h,
          column_type: column_type
        )
      end

      private

      def serialize_properties(hash, options)
        hash[:children] = children.map { |child| child.serialize_to_hash(options) }
        hash[:level] = level
        hash[:label] = label
        hash[:caption] = caption&.serialize_to_hash(options)
        hash[:column_type] = column_type
        hash
      end
    end
  end
end
