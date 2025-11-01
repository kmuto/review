# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require_relative 'node'

module ReVIEW
  module AST
    # LeafNode - Base class for nodes that do not have children
    #
    # LeafNode is the base class for all AST nodes that represent terminal/leaf nodes
    # in the syntax tree. These nodes contain content but cannot have child nodes.
    #
    # Design principles:
    # - Leaf nodes have content (text, data, etc.)
    # - Leaf nodes cannot have children
    # - Attempting to add children raises an error
    #
    # Examples of leaf nodes:
    # - TextNode: contains plain text content
    # - EmbedNode: contains embedded content (raw commands, etc.)
    # - ReferenceNode: contains resolved reference text
    class LeafNode < Node
      attr_reader :content

      def initialize(location:, content: nil, **kwargs)
        super(location: location, **kwargs)
        @content = content
      end

      # LeafNode is a leaf node
      def leaf_node?
        true
      end

      # LeafNode always returns empty children array
      def children
        []
      end

      # Prevent adding children to leaf nodes
      def add_child(_child)
        raise ArgumentError, "Cannot add children to leaf node #{self.class}"
      end

      # Prevent removing children from leaf nodes (no-op since there are no children)
      def remove_child(_child)
        raise ArgumentError, "Cannot remove children from leaf node #{self.class}"
      end
    end
  end
end
