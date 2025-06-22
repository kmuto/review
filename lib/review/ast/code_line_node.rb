# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/ast/node'

module ReVIEW
  module AST
    # CodeLineNode - Represents a line in a code block
    #
    # A code line can contain text nodes and inline elements.
    # Line numbers are tracked for numbered code blocks (listnum, emlistnum).
    class CodeLineNode < Node
      def initialize(location:, line_number: nil, **kwargs)
        super(location: location, **kwargs)
        @line_number = line_number
        @children = []
      end

      attr_accessor :line_number
      attr_reader :children

      def add_child(node)
        @children << node
      end

      def accept(visitor)
        visitor.visit_code_line_node(self)
      end
    end
  end
end
