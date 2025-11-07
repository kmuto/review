# frozen_string_literal: true

require_relative 'node'

module ReVIEW
  module AST
    class InlineNode < Node
      attr_reader :inline_type, :args, :target_chapter_id, :target_item_id

      def initialize(location:, inline_type: nil, args: nil,
                     target_chapter_id: nil, target_item_id: nil, **kwargs)
        super(location: location, **kwargs)
        @inline_type = inline_type
        @args = args || []
        @target_chapter_id = target_chapter_id
        @target_item_id = target_item_id
      end

      def to_h
        super.merge(
          inline_type: inline_type,
          args: args,
          target_chapter_id: target_chapter_id,
          target_item_id: target_item_id
        )
      end

      def cross_chapter_reference?
        !target_chapter_id.nil?
      end

      def self.deserialize_from_hash(hash)
        node = new(
          location: ReVIEW::AST::JSONSerializer.restore_location(hash),
          inline_type: hash['element'] || hash['inline_type'],
          args: hash['args'] || []
        )
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
        hash[:children] = children.map { |child| child.serialize_to_hash(options) }
        hash[:inline_type] = inline_type
        hash[:args] = args
        hash[:target_chapter_id] = target_chapter_id if target_chapter_id
        hash[:target_item_id] = target_item_id if target_item_id
        hash
      end
    end
  end
end
