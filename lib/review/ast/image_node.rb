# frozen_string_literal: true

require 'review/ast/node'
require 'review/ast/caption_node'

module ReVIEW
  module AST
    class ImageNode < Node
      attr_accessor :caption, :metric

      def initialize(location: nil, id: nil, caption: nil, metric: nil, **kwargs)
        super(location: location, id: id, **kwargs)
        @caption = CaptionNode.parse(caption, location: location)
        @metric = metric
      end

      # Get caption text for legacy Builder compatibility
      def caption_markup_text
        @caption&.to_text || ''
      end

      # Override to_h to exclude children array for ImageNode
      def to_h
        result = super
        result[:caption] = caption&.to_h
        result[:metric] = metric
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

      protected

      def serialize_properties(hash, options)
        hash[:id] = id if id && !id.empty?
        # For backward compatibility, serialize caption as its children array
        hash[:caption] = @caption ? @caption.serialize_to_hash(options) : nil
        hash[:metric] = metric
        hash
      end
    end
  end
end
