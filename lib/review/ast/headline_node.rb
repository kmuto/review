# frozen_string_literal: true

require 'review/ast/node'

module ReVIEW
  module AST
    class HeadlineNode < Node
      attr_accessor :level, :label, :caption

      def initialize(location: nil, level: nil, label: nil, caption: nil, **kwargs)
        super(location: location, **kwargs)
        @level = level
        @label = label
        @caption = caption || [] # caption is now an array of nodes
      end

      def to_h
        super.merge(
          level: level,
          label: label,
          caption: caption.is_a?(Array) ? caption.map(&:to_h) : caption
        )
      end

      protected

      def serialize_properties(hash, options)
        hash[:level] = level
        hash[:label] = label
        hash[:caption] = caption.is_a?(Array) ? caption.map { |child| child.serialize_to_hash(options) } : caption
        hash
      end
    end
  end
end
