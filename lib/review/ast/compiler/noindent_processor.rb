# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/ast/node'
require 'review/ast/block_node'
require 'review/ast/paragraph_node'
require_relative 'post_processor'

module ReVIEW
  module AST
    class Compiler
      # NoindentProcessor - Processes //noindent commands in AST
      #
      # This processor finds //noindent block commands and applies the noindent
      # attribute to the next appropriate node (typically ParagraphNode).
      # The //noindent block node itself is removed from the AST.
      #
      # Usage:
      #   NoindentProcessor.process(ast_root)
      class NoindentProcessor < PostProcessor
        private

        def process_node(node)
          # Process in reverse order to safely delete nodes without index shifting issues
          (node.children.length - 1).downto(0) do |idx|
            child = node.children[idx]

            # Check if this is a noindent block command
            if noindent_command?(child)
              # Find the next target node for noindent attribute
              target_node = find_next_target_node(node.children, idx + 1)
              if target_node
                target_node.add_attribute(:noindent, true)
              end

              # Remove the noindent block node from AST
              node.children.delete_at(idx)
            else
              # Recursively process child nodes
              process_node(child)
            end
          end
        end

        def noindent_command?(node)
          node.is_a?(BlockNode) && node.block_type == :noindent
        end

        def find_next_target_node(children, start_index)
          (start_index...children.length).each do |j|
            node = children[j]
            return node if target_node_for_noindent?(node)
          end
          nil
        end

        def target_node_for_noindent?(node)
          # ParagraphNode is the primary target for noindent
          return true if node.is_a?(ParagraphNode)

          # Other nodes that can have noindent applied
          # Add more node types here as needed
          if node.is_a?(BlockNode)
            case node.block_type
            when :quote, :lead, :flushright, :flushleft
              return true
            end
          end

          false
        end
      end
    end
  end
end
