# frozen_string_literal: true

require_relative 'node'

module ReVIEW
  module AST
    class DocumentNode < Node
      attr_reader :chapter

      def initialize(location:, chapter: nil, **kwargs)
        super(location: location, **kwargs)
        @chapter = chapter
      end

      def self.deserialize_from_hash(hash)
        node = new(location: ReVIEW::AST::JSONSerializer.restore_location(hash))
        if hash['children']
          hash['children'].each do |child_hash|
            child = ReVIEW::AST::JSONSerializer.deserialize_from_hash(child_hash)
            node.add_child(child) if child.is_a?(ReVIEW::AST::Node)
          end
        end
        node
      end

      private

      def serialize_properties(hash, options)
        hash[:children] = children.map { |child| child.serialize_to_hash(options) } if children.any?
        hash
      end
    end
  end
end
