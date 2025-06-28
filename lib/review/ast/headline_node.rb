# frozen_string_literal: true

require 'review/ast/node'
require 'review/ast/caption_node'

module ReVIEW
  module AST
    class HeadlineNode < Node
      attr_accessor :level, :label, :caption, :tag

      def initialize(location: nil, level: nil, label: nil, caption: nil, tag: nil, **kwargs)
        super(location: location, **kwargs)
        @level = level
        @label = label
        @caption = CaptionNode.parse(caption, location: location)
        @tag = tag
      end

      # Get caption text for legacy Builder compatibility
      def caption_markup_text
        @caption&.to_text || ''
      end

      # Check if headline has specific tag option
      def tag?(tag_name)
        @tag == tag_name
      end

      # Check for specific headline options
      def nonum?
        tag?('nonum')
      end

      def notoc?
        tag?('notoc')
      end

      def nodisp?
        tag?('nodisp')
      end

      def to_h
        super.merge(
          level: level,
          label: label,
          caption: caption&.to_h,
          tag: tag
        )
      end

      protected

      def serialize_properties(hash, options)
        hash[:level] = level
        hash[:label] = label
        hash[:caption] = caption&.serialize_to_hash(options)
        hash[:tag] = tag if tag
        hash
      end
    end
  end
end
