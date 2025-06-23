# frozen_string_literal: true

require 'review/ast/node'
require 'review/ast/caption_node'
require 'review/ast/json_serializer'

module ReVIEW
  module AST
    class TableNode < Node
      attr_accessor :caption, :table_type, :metric

      def initialize(location: nil, id: nil, caption: nil, table_type: :table, metric: nil, **kwargs)
        super(location: location, id: id, **kwargs)
        @caption = caption
        @table_type = table_type # :table, :emtable, :imgtable
        @metric = metric
        @header_rows = []
        @body_rows = []
      end

      attr_reader :header_rows, :body_rows

      def add_header_row(row_node)
        @header_rows << row_node
      end

      def add_body_row(row_node)
        @body_rows << row_node
      end

      def children
        @header_rows + @body_rows
      end

      # Get caption text for legacy Builder compatibility
      def caption_markup_text
        @caption&.to_text || ''
      end

      def to_h
        result = super.merge(
          caption: caption&.to_h,
          table_type: table_type,
          header_rows: header_rows.map(&:to_h),
          body_rows: body_rows.map(&:to_h)
        )
        result[:metric] = metric if metric
        result
      end

      # Override serialize_to_hash to use header_rows/body_rows instead of children
      def serialize_to_hash(options = nil)
        options ||= JSONSerializer::Options.new
        hash = {
          type: self.class.name.split('::').last
        }

        # Include location information
        if options.include_location
          hash[:location] = location&.to_h
        end

        # Add TableNode-specific properties (no children field)
        hash[:id] = id if id && !id.empty?
        hash[:table_type] = table_type
        hash[:caption] = @caption ? @caption.serialize_to_hash(options) : nil
        hash[:header_rows] = header_rows.map { |row| row.serialize_to_hash(options) } if header_rows&.any?
        hash[:body_rows] = body_rows.map { |row| row.serialize_to_hash(options) } if body_rows&.any?
        hash[:metric] = metric if metric

        hash
      end
    end
  end
end
