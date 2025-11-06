# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

module ReVIEW
  module AST
    # Base visitor class for traversing AST nodes using the Visitor pattern.
    # This class provides a generic way to walk through AST structures and
    # perform operations on each node type.
    #
    # Usage:
    #   class MyVisitor < ReVIEW::AST::Visitor
    #     def visit_headline(node)
    #       # Process headline node
    #     end
    #
    #     def visit_paragraph(node)
    #       # Process paragraph node
    #     end
    #   end
    #
    #   visitor = MyVisitor.new
    #   result = visitor.visit(ast_root)
    class Visitor
      # Visit a node and dispatch to the appropriate visit method.
      #
      # @param node [Object] The AST node to visit
      # @return [Object] The result of the visit method
      def visit(node)
        return nil if node.nil?

        method_name = node.visit_method_name

        if respond_to?(method_name, true)
          send(method_name, node)
        else
          raise NotImplementedError, "Visitor #{self.class.name} does not implement #{method_name} for #{node.class.name}"
        end
      end

      # Visit multiple nodes and return an array of results.
      #
      # @param nodes [Array] Array of AST nodes to visit
      # @return [Array] Array of visit results
      def visit_all(nodes)
        return [] unless nodes

        nodes.map { |node| visit(node) }
      end

      private

      # Extract text content from a node, handling various node types.
      # This is useful for extracting plain text from caption nodes or
      # inline content.
      #
      # @param node [Object] The node to extract text from
      # @return [String] The extracted text content
      def extract_text(node)
        case node
        when String
          node
        when nil
          ''
        else
          if node.children&.any?
            node.children.map { |child| extract_text(child) }.join
          elsif node.leaf_node?
            node.content.to_s
          else
            node.to_s
          end
        end
      end

      # Process inline content within a node.
      # This method visits all children of a node and returns the processed content.
      #
      # @param node [Object] The node containing inline content
      # @return [String] The processed inline content
      def process_inline_content(node)
        return '' unless node

        if node.children
          node.children.map { |child| visit(child) }.join
        else
          extract_text(node)
        end
      end
    end
  end
end
