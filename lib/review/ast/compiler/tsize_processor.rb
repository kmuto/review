# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/ast/node'
require 'review/ast/block_node'
require 'review/ast/table_node'

module ReVIEW
  module AST
    class Compiler
      # TsizeProcessor - Processes //tsize commands in AST
      #
      # This processor finds //tsize block commands and applies column width
      # information to the next TableNode. The //tsize block node itself is
      # removed from the AST.
      #
      # Usage:
      #   TsizeProcessor.process(ast_root, target_format: 'latex')
      class TsizeProcessor
        def self.process(ast_root, target_format: nil)
          new(target_format: target_format).process(ast_root)
        end

        def initialize(target_format: nil)
          @target_format = target_format # nil means apply to all formats
        end

        # Process the AST to handle tsize commands
        def process(ast_root)
          process_node(ast_root)
        end

        private

        def process_node(node)
          indices_to_remove = []

          node.children.each_with_index do |child, idx|
            if tsize_command?(child)
              # Extract tsize value (considering target specification)
              tsize_value = extract_tsize_value(child)

              if tsize_value
                # Find the next TableNode
                target_table = find_next_table(node.children, idx + 1)
                if target_table
                  apply_tsize_to_table(target_table, tsize_value)
                end
              end

              # Mark tsize node for removal
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

        def tsize_command?(node)
          node.is_a?(BlockNode) && node.block_type == :tsize
        end

        # Extract tsize value from tsize node, considering target specification
        # @param tsize_node [BlockNode] tsize block node
        # @return [String, nil] tsize value or nil if not applicable to target format
        def extract_tsize_value(tsize_node)
          arg = tsize_node.args.first
          return nil unless arg

          # Parse target specification format: |latex,html|value
          # Target names are multi-character words (latex, html, idgxml, etc.)
          # LaTeX column specs like |l|c|r| are NOT target specifications
          # We distinguish by checking if the first part contains only builder names (words with 2+ chars)
          if matched = arg.match(/\A\|([a-z]{2,}(?:\s*,\s*[a-z]{2,})*)\|(.*)/)
            # This is a target specification like |latex,html|10,20,30
            targets = matched[1].split(',').map(&:strip)
            value = matched[2]

            # Check if current format is in the target list
            # If target_format is nil, we can't determine if this should be applied
            # so we return nil (skip it)
            return nil if @target_format.nil?

            return targets.include?(@target_format) ? value : nil
          else
            # Generic format (applies to all formats)
            # This includes LaTeX column specs like |l|c|r| which should be used as-is
            arg
          end
        end

        # Find the next TableNode in children array
        # @param children [Array<Node>] array of child nodes
        # @param start_index [Integer] index to start searching from
        # @return [TableNode, nil] next TableNode or nil if not found
        def find_next_table(children, start_index)
          (start_index...children.length).each do |j|
            node = children[j]
            return node if node.is_a?(TableNode)
          end
          nil
        end

        # Apply tsize specification to table node
        # @param table_node [TableNode] table node to apply tsize to
        # @param tsize_value [String] tsize specification string
        def apply_tsize_to_table(table_node, tsize_value)
          # Use TableNode's built-in tsize parsing method
          table_node.parse_and_set_tsize(tsize_value)
        end
      end
    end
  end
end
