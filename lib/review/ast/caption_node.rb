# frozen_string_literal: true

require_relative 'node'

module ReVIEW
  module AST
    # Represents a caption that can contain both text and inline elements
    class CaptionNode < Node
      # Convert caption to inline text representation (with markup removed).
      # This method extracts plain text from the caption by recursively processing
      # all child nodes (text and inline elements) and joining their text content.
      #
      # @return [String] The plain text content without markup
      def to_inline_text
        children.map(&:to_inline_text).join
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

      def self.deserialize_from_hash(hash)
        node = new(location: ReVIEW::AST::JSONSerializer.restore_location(hash))
        if hash['children']
          hash['children'].each do |child_hash|
            child = ReVIEW::AST::JSONSerializer.deserialize_from_hash(child_hash)
            if child.is_a?(ReVIEW::AST::Node)
              node.add_child(child)
            elsif child.is_a?(String)
              # Convert plain string to TextNode
              node.add_child(ReVIEW::AST::TextNode.new(location: ReVIEW::AST::JSONSerializer.restore_location(hash), content: child))
            end
          end
        end
        node
      end
    end
  end
end
