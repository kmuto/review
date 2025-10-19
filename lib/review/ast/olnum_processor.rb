# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require_relative 'node'
require_relative 'block_node'
require_relative 'list_node'

module ReVIEW
  module AST
    # OlnumProcessor - Processes //olnum commands in AST
    #
    # This processor finds //olnum block commands and applies the starting number
    # to the next ordered list node. If no ordered list follows, the olnum is
    # removed. The //olnum block node itself is removed from the AST.
    #
    # Usage:
    #   processor = OlnumProcessor.new
    #   processor.process(ast_root)
    class OlnumProcessor
      def initialize
        # Track processing state if needed
      end

      # Process the AST to handle olnum commands
      def process(ast_root)
        return ast_root unless ast_root

        process_node(ast_root)
        ast_root
      end

      private

      def process_node(node)
        node.children.each_with_index do |child, idx|
          # Check if this is an olnum block command
          if olnum_block?(child)
            # Find the next ordered list for olnum attribute
            target_list = find_next_ordered_list(node.children, idx + 1)
            if target_list
              # Extract olnum value from args
              olnum_value = extract_olnum_value(child)
              target_list.add_attribute(:start_number, olnum_value)
            end

            # Remove the olnum block node from AST
            node.children.delete_at(idx)
            # Don't increment i since we removed an element
            next
          end

          # Recursively process child nodes
          process_node(child)
        end
      end

      def olnum_block?(node)
        node.is_a?(BlockNode) && node.block_type == :olnum
      end

      def find_next_ordered_list(children, start_index)
        (start_index...children.length).each do |j|
          node = children[j]
          if ordered_list_node?(node)
            return node
          end
        end
        nil
      end

      def ordered_list_node?(node)
        node.is_a?(ListNode) && node.ol?
      end

      def extract_olnum_value(olnum_node)
        # Extract number from olnum args
        if olnum_node.args.first
          olnum_node.args.first.to_i
        else
          1 # Default start number
        end
      end
    end
  end
end
