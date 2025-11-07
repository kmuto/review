# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require_relative 'node'

module ReVIEW
  module AST
    # FootnoteNode represents a footnote definition in the AST
    #
    # This node corresponds to the //footnote command in Re:VIEW syntax.
    # It stores the footnote ID and the parsed content as children nodes.
    # The footnote content is available through the children attribute.
    class FootnoteNode < Node
      attr_reader :id, :footnote_type

      def initialize(location:, id:, footnote_type: :footnote)
        super(location: location)
        @id = id
        @footnote_type = footnote_type # :footnote or :endnote
      end

      # Convert footnote content to plain text
      # This extracts text from children nodes for indexing purposes
      def to_text
        return '' if children.empty?

        children.map { |child| render_node_as_text(child) }.join
      end

      private

      # Recursively render AST nodes as plain text
      def render_node_as_text(node)
        case node
        when TextNode
          node.content
        when InlineNode
          # Extract text content from inline elements
          node.children.map { |child| render_node_as_text(child) }.join
        else
          node.leaf_node? ? node.content.to_s : ''
        end
      end
    end
  end
end
