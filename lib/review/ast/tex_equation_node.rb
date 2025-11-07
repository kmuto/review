# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require_relative 'leaf_node'
require_relative 'caption_node'

module ReVIEW
  module AST
    # TexEquationNode - LaTeX mathematical equation block
    #
    # Represents LaTeX equation blocks like:
    # //texequation{
    # \int_{-\infty}^{\infty} e^{-x^2} dx = \sqrt{\pi}
    # //}
    #
    # //texequation[eq1][Caption]{
    # E = mc^2
    # //}
    class TexEquationNode < LeafNode
      attr_accessor :caption_node

      def initialize(location:, content:, id: nil, caption_node: nil)
        super(location: location, id: id, content: content)
        @caption_node = caption_node
      end

      def caption_text
        caption_node&.to_text || ''
      end

      def id?
        !@id.nil? && !@id.empty?
      end

      def caption?
        !caption_node.nil?
      end

      def to_s
        "TexEquationNode(id: #{@id.inspect}, caption_node: #{@caption_node.inspect})"
      end

      # Override to_h to include TexEquationNode-specific attributes
      def to_h
        result = super
        result[:id] = id if id?
        result[:caption_node] = caption_node&.to_h if caption_node
        result
      end

      # Override serialize_to_hash to include TexEquationNode-specific attributes
      def serialize_to_hash(options = nil)
        options ||= ReVIEW::AST::JSONSerializer::Options.new

        # Start with type
        hash = {
          type: self.class.name.split('::').last
        }

        # Include location information
        if options.include_location
          hash[:location] = location&.to_h
        end

        # Call node-specific serialization
        serialize_properties(hash, options)

        # LeafNode automatically excludes children
        hash
      end

      def self.deserialize_from_hash(hash)
        _, caption_node = ReVIEW::AST::JSONSerializer.deserialize_caption_fields(hash)
        new(
          location: ReVIEW::AST::JSONSerializer.restore_location(hash),
          id: hash['id'],
          caption_node: caption_node,
          content: hash['content'] || ''
        )
      end

      private

      def serialize_properties(hash, options)
        hash[:id] = id if id?
        hash[:caption_node] = caption_node&.serialize_to_hash(options) if caption_node
        hash[:content] = content if content && !content.empty?
        hash
      end
    end
  end
end
