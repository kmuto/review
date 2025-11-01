# frozen_string_literal: true

require 'review/ast/node'
require 'review/ast/caption_node'

module ReVIEW
  module AST
    class HeadlineNode < Node
      attr_accessor :caption_node, :auto_id
      attr_reader :level, :label, :tag

      def initialize(location:, level: nil, label: nil, caption_node: nil, tag: nil, auto_id: nil, **kwargs)
        super(location: location, **kwargs)
        @level = level
        @label = label
        @caption_node = caption_node
        @tag = tag
        @auto_id = auto_id
      end

      # Get caption text from caption_node
      def caption_text
        caption_node&.to_text || ''
      end

      # Check if this headline has a caption
      def caption?
        !caption_node.nil?
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
