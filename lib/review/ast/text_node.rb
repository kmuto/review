# frozen_string_literal: true

require_relative 'leaf_node'

module ReVIEW
  module AST
    class TextNode < LeafNode
      # Override to_h to exclude children array for TextNode
      def to_h
        result = {
          type: self.class.name.split('::').last,
          location: location_to_h
        }
        result[:content] = @content if @content && !@content.empty?
        # TextNode is a leaf node - do not include children array
        result
      end

      # Override serialize_to_hash to exclude children array for TextNode
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

        # Call node-specific serialization (adds content)
        serialize_properties(hash, options)

        # TextNode is a leaf node - do not include children array
        hash
      end

      private

      def serialize_properties(hash, _options)
        # Add content property explicitly for TextNode
        hash[:content] = content if content
        hash
      end

      def location_to_h
        return nil unless location

        {
          filename: location.filename,
          lineno: location.lineno
        }
      end

      # Deserialize from hash
      def self.deserialize_from_hash(hash)
        new(
          location: ReVIEW::AST::JSONSerializer.restore_location(hash),
          content: hash['content'] || ''
        )
      end
    end
  end
end
