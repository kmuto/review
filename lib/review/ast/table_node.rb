# frozen_string_literal: true

require 'review/ast/node'
require 'review/ast/caption_node'
require 'review/ast/json_serializer'

module ReVIEW
  module AST
    class TableNode < Node
      attr_accessor :caption_node, :col_spec, :cellwidth
      attr_reader :table_type, :metric

      def initialize(location:, id: nil, caption_node: nil, table_type: :table, metric: nil, col_spec: nil, cellwidth: nil, **kwargs)
        super(location: location, id: id, **kwargs)
        @caption_node = caption_node
        @table_type = table_type # :table, :emtable, :imgtable
        @metric = metric
        @col_spec = col_spec # Column specification string (e.g., "|l|c|r|")
        @cellwidth = cellwidth # Array of column width specifications
        @header_rows = []
        @body_rows = []
      end

      # Get caption text from caption_node
      def caption_text
        caption_node&.to_text || ''
      end

      # Check if this table has a caption
      def caption?
        !caption_node.nil?
      end

      def header_rows
        @children.find_all do |node|
          node.row_type == :header
        end
      end

      def body_rows
        @children.find_all do |node|
          node.row_type == :body
        end
      end

      def add_header_row(row_node)
        row_node.row_type = :header
        idx = @children.index { |child| child.row_type == :body }
        if idx
          insert_child(idx, row_node)
        else
          add_child(row_node)
        end
      end

      def add_body_row(row_node)
        row_node.row_type = :body
        add_child(row_node)
      end

      # Get column count from table rows
      def column_count
        all_rows = header_rows + body_rows
        all_rows.first&.children&.length || 1
      end

      # Get default column specification (left-aligned with borders)
      def default_col_spec
        '|' + ('l|' * column_count)
      end

      # Get default cellwidth array (all left-aligned)
      def default_cellwidth
        ['l'] * column_count
      end

      # Parse tsize value and set col_spec and cellwidth on this table
      # @param tsize_value [String] tsize specification
      def parse_and_set_tsize(tsize_value)
        require_relative('table_column_width_parser')
        parser = TableColumnWidthParser.new(tsize_value, column_count)
        result = parser.parse
        @col_spec = result.col_spec
        @cellwidth = result.cellwidth
      end

      def to_h
        result = super.merge(
          caption_node: caption_node&.to_h,
          table_type: table_type,
          header_rows: header_rows.map(&:to_h),
          body_rows: body_rows.map(&:to_h)
        )
        result[:metric] = metric if metric
        result[:col_spec] = col_spec if col_spec
        result[:cellwidth] = cellwidth if cellwidth
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
        hash[:caption_node] = caption_node&.serialize_to_hash(options) if caption_node
        hash[:header_rows] = header_rows.map { |row| row.serialize_to_hash(options) }
        hash[:body_rows] = body_rows.map { |row| row.serialize_to_hash(options) }
        hash[:metric] = metric if metric
        hash[:col_spec] = col_spec if col_spec
        hash[:cellwidth] = cellwidth if cellwidth

        hash
      end
    end
  end
end
