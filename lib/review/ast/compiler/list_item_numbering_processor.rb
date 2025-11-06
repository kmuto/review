# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/ast/node'
require 'review/ast/list_node'
require_relative 'post_processor'

module ReVIEW
  module AST
    class Compiler
      # ListItemNumberingProcessor - Assigns item numbers to ordered list items
      #
      # This processor traverses the AST and assigns absolute item numbers to each
      # ListItemNode in ordered lists (ol). The item number is calculated based on
      # the list's start_number (default: 1) and the item's position in the list.
      #
      # Usage:
      #   ListItemNumberingProcessor.process(ast_root)
      class ListItemNumberingProcessor < PostProcessor
        private

        def process_node(node)
          if ordered_list_node?(node)
            assign_item_numbers(node)
          end

          node.children.each { |child| process(child) }
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
end
