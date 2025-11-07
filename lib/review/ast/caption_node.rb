# frozen_string_literal: true

require_relative 'node'

module ReVIEW
  module AST
    # Represents a caption that can contain both text and inline elements
    class CaptionNode < Node
      # Convert caption to plain text format for legacy Builder compatibility
      def to_text
        return '' if children.empty?

        children.map { |child| render_node_as_text(child) }.join
      end

      # Check if caption contains any inline elements
      def contains_inline?
        children.any?(InlineNode)
      end

      # Check if caption is empty
      def empty?
        children.empty? || children.all? { |child| child.is_a?(LeafNode) && child.content.to_s.strip.empty? }
      end

      # Convert caption to hash representation
      def to_h
        {
          type: 'CaptionNode',
          location: location&.to_h,
          children: children.map(&:to_h)
        }
      end

      # Override serialize_to_hash to return CaptionNode structure
      def serialize_to_hash(options)
        if children.empty?
          ''
        else
          # Return full CaptionNode structure
          super
        end
      end

      private

      # Recursively render AST nodes as Re:VIEW markup text
      def render_node_as_text(node)
        case node
        when TextNode
          node.content
        when InlineNode
          # Convert back to Re:VIEW markup for Builder processing
          content = node.children.map { |child| render_node_as_text(child) }.join
          "@<#{node.inline_type}>{#{content}}"
        else
          node.leaf_node? ? node.content.to_s : ''
        end
      end
    end
  end
end
