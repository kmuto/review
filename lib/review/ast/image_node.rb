# frozen_string_literal: true

require 'review/ast/node'
require 'review/ast/caption_node'

module ReVIEW
  module AST
    class ImageNode < Node
      attr_accessor :caption_node
      attr_reader :caption, :metric, :image_type

      def initialize(location: nil, id: nil, caption: nil, caption_node: nil, metric: nil, image_type: :image, **kwargs)
        super(location: location, id: id, **kwargs)
        @caption_node = caption_node
        @caption = caption
        @metric = metric
        @image_type = image_type
      end

      # Get caption text for legacy Builder compatibility
      def caption_markup_text
        return '' if caption.nil? && caption_node.nil?

        caption || caption_node&.to_text || ''
      end

      # Override to_h to exclude children array for ImageNode
      def to_h
        result = super
        result[:caption] = caption if caption
        result[:caption_node] = caption_node&.to_h if caption_node
        result[:metric] = metric
        result[:image_type] = image_type
        # ImageNode is a leaf node - remove children array if present
        result.delete(:children)
        result
      end

      # Override serialize_to_hash to exclude children array for ImageNode
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

        # ImageNode is a leaf node - do not include children array
        hash
      end

      private

      def serialize_properties(hash, options)
        hash[:id] = id if id && !id.empty?
        hash[:caption] = caption if caption
        # For backward compatibility, provide structured caption node
        hash[:caption_node] = caption_node&.serialize_to_hash(options) if caption_node
        hash[:metric] = metric
        hash[:image_type] = image_type
        hash
      end
    end
  end
end
