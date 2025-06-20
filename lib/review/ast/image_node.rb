# frozen_string_literal: true

require 'review/ast/node'

module ReVIEW
  module AST
    class ImageNode < Node
      attr_accessor :caption, :metric

      def initialize(location: nil, id: nil, caption: nil, metric: nil, **kwargs)
        super(location: location, id: id, **kwargs)
        @caption = caption || [] # caption is now an array of nodes
        @metric = metric
      end

      # Override to_h to exclude children array for ImageNode
      def to_h
        result = super
        result.merge!(
          caption: caption.is_a?(Array) ? caption.map(&:to_h) : caption,
          metric: metric
        )
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
          hash[:location] = location_to_h
        end

        # Call node-specific serialization
        serialize_properties(hash, options)

        # ImageNode is a leaf node - do not include children array
        hash
      end

      protected

      def serialize_properties(hash, options)
        hash[:id] = id if id && !id.empty?
        hash[:caption] = caption.is_a?(Array) ? caption.map { |child| child.serialize_to_hash(options) } : caption
        hash[:metric] = metric
        hash
      end

      private

      def location_to_h
        return nil unless location

        {
          filename: location.filename,
          lineno: location.lineno
        }
      end
    end
  end
end
