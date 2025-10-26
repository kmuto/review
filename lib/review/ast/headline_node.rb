# frozen_string_literal: true

require 'review/ast/node'
require 'review/ast/caption_node'

module ReVIEW
  module AST
    class HeadlineNode < Node
      attr_accessor :caption_node, :auto_id
      attr_reader :level, :label, :caption, :tag

      def initialize(location: nil, level: nil, label: nil, caption: nil, caption_node: nil, tag: nil, auto_id: nil, **kwargs)
        super(location: location, **kwargs)
        @level = level
        @label = label
        @caption_node = caption_node
        @caption = caption
        @tag = tag
        @auto_id = auto_id
      end

      # Get caption text for legacy Builder compatibility
      def caption_markup_text
        return '' if caption.nil? && caption_node.nil?

        caption || caption_node&.to_text || ''
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
        result = super.merge(
          level: level,
          label: label,
          caption: caption,
          caption_node: caption_node&.to_h,
          tag: tag
        )
        result[:auto_id] = auto_id if auto_id
        result
      end

      private

      def serialize_properties(hash, options)
        hash[:level] = level
        hash[:label] = label
        hash[:caption_node] = caption_node&.serialize_to_hash(options) if caption_node
        hash[:tag] = tag if tag
        hash[:auto_id] = auto_id if auto_id
        hash
      end
    end
  end
end
