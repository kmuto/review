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
    class TableCellNode < Node
      def initialize(location:, **kwargs)
        super
        @children = []
      end

      attr_reader :children

      def add_child(node)
        @children << node
      end

      def accept(visitor)
        visitor.visit_table_cell_node(self)
      end
    end
  end
end
