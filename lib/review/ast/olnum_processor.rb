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
    #   OlnumProcessor.process(ast_root)
    class OlnumProcessor
      def self.process(ast_root)
        new.process(ast_root)
      end

      # Process the AST to handle olnum commands
      def process(ast_root)
        process_node(ast_root)
      end

      private

      def process_node(node)
        node.children.each_with_index do |child, idx|
          if olnum_command?(child)
            # Find the next ordered list for olnum
            target_list = find_next_ordered_list(node.children, idx + 1)
            if target_list
              olnum_value = extract_olnum_value(child)
              target_list.start_number = olnum_value
            end

            node.children.delete_at(idx)
          else
            # Recursively process child nodes
            process_node(child)
          end
        end
      end

      def olnum_command?(node)
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
        (olnum_node.args.first || 1).to_i
      end
    end
  end
end
