# frozen_string_literal: true

require_relative 'node'
require_relative 'caption_node'

module ReVIEW
  module AST
    # MinicolumnNode - Represents minicolumn blocks (note, memo, tip, etc.)
    class MinicolumnNode < Node
      attr_accessor :caption_node
      attr_reader :minicolumn_type

      def initialize(location:, minicolumn_type: nil, caption_node: nil, **kwargs)
        super(location: location, **kwargs)
        @minicolumn_type = minicolumn_type # :note, :memo, :tip, :info, :warning, :important, :caution, :notice
        @caption_node = caption_node
      end

      # Get caption text from caption_node
      def caption_text
        caption_node&.to_text || ''
      end

      # Check if this minicolumn has a caption
      def caption?
        !caption_node.nil?
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
        _, caption_node = ReVIEW::AST::JSONSerializer.deserialize_caption_fields(hash)
        node = new(
          location: ReVIEW::AST::JSONSerializer.restore_location(hash),
          minicolumn_type: hash['minicolumn_type'] || hash['column_type'],
          caption_node: caption_node
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
        hash[:caption_node] = caption_node&.serialize_to_hash(options) if caption_node
        if children.any?
          hash[:children] = children.map { |child| child.serialize_to_hash(options) }
        end
        hash
      end
    end
  end
end
