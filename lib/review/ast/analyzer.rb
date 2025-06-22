# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

module ReVIEW
  module AST
    # Analyzer - AST structure analysis and statistics
    #
    # This class provides functionality for analyzing AST structures,
    # collecting statistics about node types, depths, and overall tree characteristics.
    class Analyzer
      # Get comprehensive statistics about an AST tree
      def self.statistics(ast_root)
        {
          total_nodes: count_nodes(ast_root),
          node_types: collect_node_types(ast_root).tally,
          depth: calculate_depth(ast_root)
        }
      end

      # Count total number of nodes in the AST
      def self.count_nodes(node)
        count = 1
        if node.respond_to?(:children) && node.children
          node.children.each { |child| count += count_nodes(child) }
        end
        count
      end

      # Calculate maximum depth of the AST
      def self.calculate_depth(node, current_depth = 0)
        max_depth = current_depth
        if node.respond_to?(:children) && node.children
          node.children.each do |child|
            child_depth = calculate_depth(child, current_depth + 1)
            max_depth = [max_depth, child_depth].max
          end
        end
        max_depth
      end

      # Collect all node types in the AST
      def self.collect_node_types(node)
        types = [node.class.name.split('::').last]
        if node.respond_to?(:children) && node.children
          node.children.each { |child| types += collect_node_types(child) }
        end
        types
      end
    end
  end
end