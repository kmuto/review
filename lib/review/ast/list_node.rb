# frozen_string_literal: true

require_relative 'node'
require_relative 'list_item_node'

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

module ReVIEW
  module AST
    class ListNode < Node
      attr_reader :list_type
      attr_accessor :start_number, :olnum_start

      def initialize(location:, list_type: nil, start_number: nil, olnum_start: nil, **kwargs)
        super(location: location, **kwargs)
        @list_type = list_type # :ul, :ol, :dl
        @start_number = start_number
        @olnum_start = olnum_start # InDesign's olnum starting value (for IDGXML)
      end

      # Convenience methods for type checking
      def ol?
        list_type == :ol
      end

      def ul?
        list_type == :ul
      end

      def dl?
        list_type == :dl
      end

      def to_h
        result = super.merge(
          list_type: list_type
        )
        result[:start_number] = start_number if start_number && start_number != 1
        result
      end

      def self.deserialize_from_hash(hash)
        node = new(location: ReVIEW::AST::JSONSerializer.restore_location(hash), list_type: hash['list_type'].to_sym)

        # Process children (should be ListItemNode objects)
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
        hash[:list_type] = list_type
        hash[:start_number] = start_number if start_number && start_number != 1
        if children.any?
          hash[:children] = children.map { |child| child.serialize_to_hash(options) }
        end
        hash
      end
    end
  end
end
