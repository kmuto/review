# frozen_string_literal: true

require 'review/ast/leaf_node'

module ReVIEW
  module AST
    # EmbedNode is a leaf node that contains embedded content that should be
    # passed through to specific builders. It cannot have children.
    #
    # Attributes:
    # - content: The processed content ready for rendering.
    #            Renderers should use this attribute.
    # - embed_type: :block for //embed{}, :raw for //raw{}, :inline for @<embed>{}/@<raw>{}
    # - target_builders: Array of builder names (e.g., ["html", "latex"]), or nil for all builders
    class EmbedNode < LeafNode
      attr_reader :embed_type, :target_builders

      def initialize(location:, embed_type: :block, target_builders: nil, content: nil, **kwargs)
        super(location: location, content: content, **kwargs)
        @embed_type = embed_type # :block, :inline, or :raw
        @target_builders = target_builders # Array of builder names, nil means all builders
      end

      # Check if this embed is targeted for a specific builder
      def targeted_for?(builder_name)
        return true if @target_builders.nil? # No specification means all builders

        @target_builders.include?(builder_name.to_s)
      end

      # Override to_h to exclude children array for EmbedNode
      def to_h
        result = super
        result.merge!(
          embed_type: embed_type,
          target_builders: target_builders,
          content: content
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

      private

      def serialize_properties(hash, _options)
        hash[:embed_type] = embed_type
        hash[:target_builders] = target_builders if target_builders
        hash[:content] = content if content
        hash
      end
    end
  end
end
