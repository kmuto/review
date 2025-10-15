# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/ast/node'

module ReVIEW
  module AST
    # TableCellNode - Represents a cell in a table
    #
    # A table cell can contain text nodes and inline elements.
    # Cells are separated by tabs in the original Re:VIEW syntax.
    #
    # The cell_type attribute determines whether this cell should be
    # rendered as a header cell (<th>) or data cell (<td>).
    class TableCellNode < Node
      attr_reader :children, :cell_type

      def initialize(location:, cell_type: :td, **kwargs)
        super
        @children = []
        @cell_type = cell_type # :th or :td
      end

      def add_child(node)
        @children << node
      end

      def accept(visitor)
        visitor.visit_table_cell(self)
      end

      private

      def serialize_properties(hash, options)
        super
        hash[:cell_type] = @cell_type if @cell_type != :td
        hash
      end
    end
  end
end
