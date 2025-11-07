# frozen_string_literal: true

require_relative 'node'
require_relative 'caption_node'
require_relative 'captionable'

module ReVIEW
  module AST
    class HeadlineNode < Node
      include Captionable

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

      def self.deserialize_from_hash(hash)
        new(
          location: ReVIEW::AST::JSONSerializer.restore_location(hash),
          level: hash['level'],
          label: hash['label'],
          caption_node: deserialize_caption_from_hash(hash)
        )
      end

      private

      def serialize_properties(hash, options)
        hash[:level] = level
        hash[:label] = label
        serialize_caption_to_hash(hash, options)
        hash[:tag] = tag if tag
        hash[:auto_id] = auto_id if auto_id
        hash
      end
    end
  end
end
