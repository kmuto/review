# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require_relative 'node'
require_relative 'list_node'

module ReVIEW
  module AST
    # ListItemNumberingProcessor - Assigns item numbers to ordered list items
    #
    # This processor traverses the AST and assigns absolute item numbers to each
    # ListItemNode in ordered lists (ol). The item number is calculated based on
    # the list's start_number (default: 1) and the item's position in the list.
    #
    # This ensures that each list item has its correct number even after list
    # merging operations in renderers like ListStructureNormalizer.
    #
    # Usage:
    #   ListItemNumberingProcessor.process(ast_root)
    class ListItemNumberingProcessor
      def self.process(ast_root)
        new.process(ast_root)
      end

      # Process the AST to assign item numbers
      def process(ast_root)
        process_node(ast_root)
      end

      private

      def process_node(node)
        # Process ordered lists
        if ordered_list_node?(node)
          assign_item_numbers(node)
        end

        # Recursively process children
        if node.respond_to?(:children)
          node.children.each { |child| process_node(child) }
        end
      end

      def ordered_list_node?(node)
        node.is_a?(ListNode) && node.ol?
      end

      def assign_item_numbers(list_node)
        start_number = list_node.start_number || 1

        list_node.children.each_with_index do |item, index|
          next unless item.is_a?(ListItemNode)

          item.item_number = start_number + index
        end
      end
    end
  end
end
