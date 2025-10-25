# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/ast/node'

module ReVIEW
  module AST
    # TableRowNode - Represents a row in a table
    #
    # A table row contains multiple table cells (TableCellNode).
    # Each cell can contain text and inline elements.
    class TableRowNode < Node
      ROW_TYPES = %i[header body]

      def initialize(location:, row_type: :body, **kwargs)
        super
        @children = []
        @row_type = row_type.to_sym

        validate_row_type
      end

      attr_reader :children, :row_type

      def row_type=(value)
        @row_type = value.to_sym
        validate_row_type
      end

      def accept(visitor)
        visitor.visit_table_row_node(self)
      end

      private

      def validate_row_type
        unless ROW_TYPES.include?(row_type)
          raise ArgumentError, "invalid row_type in TableRowNode: `#{row_type}`"
        end
      end
    end
  end
end
