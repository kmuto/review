# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/ast/node'
require 'review/ast/block_node'
require 'review/ast/list_node'
require_relative 'base_processor'

module ReVIEW
  module AST
    class Compiler
      # OlnumProcessor - Processes //olnum commands in AST
      #
      # This processor finds //olnum block commands and applies the starting number
      # to the next ordered list node. If no ordered list follows, the olnum is
      # removed. The //olnum block node itself is removed from the AST.
      #
      # Usage:
      #   OlnumProcessor.process(ast_root)
      class OlnumProcessor < BaseProcessor
        def process(ast_root)
          # First pass: process //olnum commands
          process_node(ast_root)
          # Second pass: set olnum_start for all ordered lists
          add_olnum_starts(ast_root)
        end

        private

        def process_node(node)
          # Collect indices to delete (process in reverse to avoid index shifting)
          indices_to_delete = []

          node.children.each_with_index do |child, idx|
            if olnum_command?(child)
              # Find the next ordered list for olnum
              target_list = find_next_ordered_list(node.children, idx + 1)
              if target_list
                olnum_value = extract_olnum_value(child)
                target_list.start_number = olnum_value
                # Mark this list as explicitly set by //olnum
                target_list.olnum_start = olnum_value
              end

              indices_to_delete << idx
            else
              # Recursively process child nodes
              process_node(child)
            end
          end

          # Delete olnum nodes in reverse order to avoid index shifting
          indices_to_delete.reverse_each { |idx| node.children.delete_at(idx) }
        end

        # Set olnum_start for lists without explicit //olnum
        def add_olnum_starts(node)
          if ordered_list_node?(node) && node.olnum_start.nil?
            start_number = node.start_number || 1

            # Check if items have consecutive increasing numbers
            is_consecutive = node.children.each_with_index.all? do |item, idx|
              next true unless item.is_a?(ListItemNode)

              expected = start_number + idx
              actual = item.number || expected
              actual == expected
            end

            node.olnum_start = is_consecutive ? start_number : 1
          end

          node.children.each { |child| add_olnum_starts(child) }
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
end
