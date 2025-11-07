# frozen_string_literal: true

require_relative 'node'
require_relative 'caption_node'
require_relative 'captionable'

module ReVIEW
  module AST
    # MinicolumnNode - Represents minicolumn blocks (note, memo, tip, etc.)
    class MinicolumnNode < Node
      include Captionable

      attr_reader :caption_node
      attr_reader :minicolumn_type

      def initialize(location:, minicolumn_type: nil, caption_node: nil, **kwargs)
        super(location: location, **kwargs)
        @minicolumn_type = minicolumn_type # :note, :memo, :tip, :info, :warning, :important, :caution, :notice
        @caption_node = caption_node
      end

      def to_h
        result = super.merge(
          minicolumn_type: minicolumn_type
        )
        result[:caption_node] = caption_node&.to_h if caption_node
        result
      end

      # Deserialize from hash
      def self.deserialize_from_hash(hash)
        node = new(
          location: ReVIEW::AST::JSONSerializer.restore_location(hash),
          minicolumn_type: hash['minicolumn_type'] || hash['column_type'],
          caption_node: deserialize_caption_from_hash(hash)
        )
        if hash['children'] || hash['content']
          children = (hash['children'] || hash['content'] || []).map { |child| ReVIEW::AST::JSONSerializer.deserialize_from_hash(child) }
          children.each { |child| node.add_child(child) if child.is_a?(ReVIEW::AST::Node) }
        end
        node
      end

      private

      def serialize_properties(hash, options)
        hash[:minicolumn_type] = minicolumn_type
        serialize_caption_to_hash(hash, options)
        if children.any?
          hash[:children] = children.map { |child| child.serialize_to_hash(options) }
        end
        hash
      end
    end
  end
end
