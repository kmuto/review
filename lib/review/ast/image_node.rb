# frozen_string_literal: true

require_relative 'leaf_node'
require_relative 'caption_node'

module ReVIEW
  module AST
    class ImageNode < LeafNode
      attr_accessor :caption_node
      attr_reader :metric, :image_type

      def initialize(location:, id: nil, caption_node: nil, metric: nil, image_type: :image, content: '', **kwargs)
        super(location: location, id: id, content: content, **kwargs)
        @caption_node = caption_node
        @metric = metric
        @image_type = image_type
      end

      # Get caption text from caption_node
      def caption_text
        caption_node&.to_text || ''
      end

      # Check if this image has a caption
      def caption?
        !caption_node.nil?
      end

      # Check if this image has an ID
      def id?
        !@id.nil? && !@id.empty?
      end

      # Override to_h to include ImageNode-specific attributes
      def to_h
        result = super
        result[:id] = id if id?
        result[:caption_node] = caption_node&.to_h if caption_node
        result[:metric] = metric if metric
        result[:image_type] = image_type
        result
      end

      # Override serialize_to_hash to include ImageNode-specific attributes
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
          metric: hash['metric'],
          image_type: hash['image_type']&.to_sym || :image,
          content: hash['content'] || ''
        )
      end

      private

      def serialize_properties(hash, options)
        hash[:id] = id if id?
        hash[:caption_node] = caption_node&.serialize_to_hash(options) if caption_node
        hash[:metric] = metric if metric
        hash[:image_type] = image_type
        hash[:content] = content if content && !content.empty?
        hash
      end
    end
  end
end
