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

      # Get caption text for legacy Builder compatibility
      def caption_markup_text
        @caption&.to_text || ''
      end

      def to_h
        super.merge(
          level: level,
          label: label,
          caption: if caption.is_a?(Array)
                     caption.map(&:to_h)
                   elsif caption.respond_to?(:to_h)
                     caption.to_h
                   else
                     caption
                   end
        )
      end

      protected

      def serialize_properties(hash, options)
        hash[:level] = level
        hash[:label] = label
        hash[:caption] = if caption.is_a?(Array)
                           caption.map { |child| child.serialize_to_hash(options) }
                         elsif caption.respond_to?(:serialize_to_hash)
                           caption.serialize_to_hash(options)
                         else
                           caption
                         end
        hash
      end
    end
  end
end
