# frozen_string_literal: true

require 'review/ast/node'
require 'review/ast/caption_node'

module ReVIEW
  module AST
    class ColumnNode < Node
      attr_accessor :caption_node, :auto_id, :column_number
      attr_reader :level, :label, :column_type

      def initialize(location:, level: nil, label: nil, caption_node: nil, column_type: :column, auto_id: nil, column_number: nil, **kwargs)
        super(location: location, **kwargs)
        @level = level
        @label = label
        @caption_node = caption_node
        @column_type = column_type
        @auto_id = auto_id
        @column_number = column_number
      end

      # Get caption text from caption_node
      def caption_text
        caption_node&.to_text || ''
      end

      # Check if this column has a caption
      def caption?
        !caption_node.nil?
      end

      def to_h
        result = super.merge(
          level: level,
          label: label, caption_node: caption_node&.to_h,
          column_type: column_type
        )
        result[:auto_id] = auto_id if auto_id
        result[:column_number] = column_number if column_number
        result
      end

      private

      def serialize_properties(hash, options)
        hash[:children] = children.map { |child| child.serialize_to_hash(options) }
        hash[:level] = level
        hash[:label] = label
        hash[:caption_node] = caption_node&.serialize_to_hash(options) if caption_node
        hash[:column_type] = column_type
        hash[:auto_id] = auto_id if auto_id
        hash[:column_number] = column_number if column_number
        hash
      end
    end
  end
end
