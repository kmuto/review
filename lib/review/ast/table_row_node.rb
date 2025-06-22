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
      def initialize(location:, **kwargs)
        super
        @children = []
      end

      attr_reader :children

      def add_child(node)
        @children << node
      end

      def accept(visitor)
        visitor.visit_table_row_node(self)
      end
    end
  end
end
