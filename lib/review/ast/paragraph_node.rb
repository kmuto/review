# frozen_string_literal: true

require_relative 'node'

module ReVIEW
  module AST
    class ParagraphNode < Node
      # Deserialize from hash
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

      private

      def serialize_properties(hash, options)
        hash[:children] = children.map { |child| child.serialize_to_hash(options) }
        hash
      end
    end
  end
end
