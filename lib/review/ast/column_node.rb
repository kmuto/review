# frozen_string_literal: true

require 'review/ast/node'

module ReVIEW
  module AST
    class ColumnNode < Node
      attr_accessor :level, :label, :caption, :column_type

      def initialize(location = nil)
        super
        @level = nil
        @label = nil
        @caption = nil
        @column_type = 'column' # default column type
      end

      def to_h
        super.merge(
          level: level,
          label: label,
          caption: caption,
          column_type: column_type
        )
      end

      protected

      def serialize_properties(hash, options)
        hash[:children] = children.map { |child| child.serialize_to_hash(options) }
        hash[:level] = level
        hash[:label] = label
        hash[:caption] = caption
        hash[:column_type] = column_type
        hash
      end
    end
  end
end
