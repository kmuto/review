# frozen_string_literal: true

require 'review/ast/node'

module ReVIEW
  module AST
    class EmbedNode < Node
      attr_accessor :lines, :arg, :embed_type

      def initialize(location: nil, lines: [], arg: nil, embed_type: :block, **kwargs)
        super(location: location, **kwargs)
        @lines = lines
        @arg = arg
        @embed_type = embed_type # :block or :inline
      end

      # Override to_h to exclude children array for EmbedNode
      def to_h
        result = super
        result.merge!(
          lines: lines,
          arg: arg,
          embed_type: embed_type
        )
        # EmbedNode is a leaf node - remove children array if present
        result.delete(:children)
        result
      end

      # Override serialize_to_hash to exclude children array for EmbedNode
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

        # EmbedNode is a leaf node - do not include children array
        hash
      end

      protected

      def serialize_properties(hash, _options)
        hash[:lines] = lines
        hash[:arg] = arg
        hash[:embed_type] = embed_type
        hash
      end
    end
  end
end
