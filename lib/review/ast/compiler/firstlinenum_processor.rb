# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/ast/node'
require 'review/ast/block_node'
require 'review/ast/code_block_node'
require_relative 'base_processor'

module ReVIEW
  module AST
    class Compiler
      # FirstLineNumProcessor - Processes //firstlinenum commands in AST
      #
      # This processor finds //firstlinenum block commands and applies the
      # starting line number to the next CodeBlockNode. The //firstlinenum
      # block node itself is removed from the AST.
      #
      # Usage:
      #   FirstLineNumProcessor.process(ast_root)
      class FirstLineNumProcessor < BaseProcessor
        private

        def process_node(node)
          indices_to_remove = []

          node.children.each_with_index do |child, idx|
            if firstlinenum_command?(child)
              # Extract firstlinenum value
              value = extract_firstlinenum_value(child)

              if value
                # Find the next CodeBlockNode
                target_code_block = find_next_code_block(node.children, idx + 1)
                if target_code_block
                  apply_firstlinenum(target_code_block, value)
                end
              end

              # Mark firstlinenum node for removal
              indices_to_remove << idx
            else
              # Recursively process child nodes
              process_node(child)
            end
          end

          # Remove marked nodes in reverse order to avoid index shifting
          indices_to_remove.reverse_each do |idx|
            node.children.delete_at(idx)
          end
        end

        def firstlinenum_command?(node)
          node.is_a?(BlockNode) && node.block_type == :firstlinenum
        end

        # Extract firstlinenum value from firstlinenum node
        # @param firstlinenum_node [BlockNode] firstlinenum block node
        # @return [Integer, nil] line number value or nil
        def extract_firstlinenum_value(firstlinenum_node)
          arg = firstlinenum_node.args.first
          return nil unless arg

          arg.to_i
        end

        # Find the next CodeBlockNode in children array
        # @param children [Array<Node>] array of child nodes
        # @param start_index [Integer] index to start searching from
        # @return [CodeBlockNode, nil] next CodeBlockNode or nil if not found
        def find_next_code_block(children, start_index)
          (start_index...children.length).each do |j|
            node = children[j]
            return node if node.is_a?(CodeBlockNode)
          end
          nil
        end

        # Apply firstlinenum value to code block node
        # @param code_block [CodeBlockNode] code block node
        # @param value [Integer] starting line number
        def apply_firstlinenum(code_block, value)
          code_block.first_line_num = value
        end
      end
    end
  end
end
