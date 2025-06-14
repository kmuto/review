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
        @caption = caption
      end

      def to_h
        super.merge(
          level: level,
          label: label,
          caption: caption
        )
      end

      protected

      def serialize_properties(hash, _options)
        hash[:level] = level
        hash[:label] = label
        hash[:caption] = caption
        hash
      end
    end
  end
end
