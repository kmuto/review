# frozen_string_literal: true

require_relative 'node'
require_relative 'caption_node'
require_relative 'captionable'

module ReVIEW
  module AST
    class ColumnNode < Node
      include Captionable

      attr_accessor :caption_node, :auto_id, :column_number
      attr_reader :level, :label, :column_type

      def initialize(location:, level: nil, label: nil, caption_node: nil, column_type: :column, auto_id: nil, column_number: nil, **kwargs)
        super(location: location, **kwargs)
        @level = level
        @label = label
        @caption_node = caption_node
        @column_type = column_type
        @auto_id = auto_id
        @column_number = column_number
      end

      def to_h
        result = super.merge(
          level: level,
          label: label, caption_node: caption_node&.to_h,
          column_type: column_type
        )
        result[:auto_id] = auto_id if auto_id
        result[:column_number] = column_number if column_number
        result
      end

      # Deserialize from hash
      def self.deserialize_from_hash(hash)
        node = new(
          location: ReVIEW::AST::JSONSerializer.restore_location(hash),
          level: hash['level'],
          label: hash['label'],
          caption_node: deserialize_caption_from_hash(hash),
          column_type: hash['column_type']&.to_sym
        )
        if hash['children']
          hash['children'].each do |child_hash|
            child = ReVIEW::AST::JSONSerializer.deserialize_from_hash(child_hash)
            node.add_child(child) if child.is_a?(ReVIEW::AST::Node)
          end
        end
        node
      end

      private

      def serialize_properties(hash, options)
        hash[:children] = children.map { |child| child.serialize_to_hash(options) }
        hash[:level] = level
        hash[:label] = label
        serialize_caption_to_hash(hash, options)
        hash[:column_type] = column_type.to_s if column_type
        hash[:auto_id] = auto_id if auto_id
        hash[:column_number] = column_number if column_number
        hash
      end
    end
  end
end
