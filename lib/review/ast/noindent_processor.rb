# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require_relative 'node'
require_relative 'block_node'
require_relative 'paragraph_node'

module ReVIEW
  module AST
    # NoIndentProcessor - Processes //noindent commands in AST
    #
    # This processor finds //noindent block commands and applies the noindent
    # attribute to the next appropriate node (typically ParagraphNode).
    # The //noindent block node itself is removed from the AST.
    #
    # Usage:
    #   processor = NoIndentProcessor.new
    #   processor.process(ast_root)
    class NoIndentProcessor
      def initialize
        # Track processing state if needed
      end

      # Process the AST to handle noindent commands
      def process(ast_root)
        return ast_root unless ast_root

        process_node(ast_root)
        ast_root
      end

      private

      def process_node(node)
        return unless node.children

        i = 0
        while i < node.children.length
          child = node.children[i]

          # Check if this is a noindent block command
          if noindent_block?(child)
            # Find the next target node for noindent attribute
            target_node = find_next_target_node(node.children, i + 1)
            if target_node
              target_node.add_attribute(:noindent, true)
            end

            # Remove the noindent block node from AST
            node.children.delete_at(i)
            # Don't increment i since we removed an element
            next
          end

          # Recursively process child nodes
          process_node(child) if child.children
          i += 1
        end
      end

      def noindent_block?(node)
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
