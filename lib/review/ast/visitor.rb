# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
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
      # The method name is derived from the node's class name.
      #
      # @param node [Object] The AST node to visit
      # @return [Object] The result of the visit method
      def visit(node)
        return nil if node.nil?

        method_name = derive_visit_method_name(node)

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

      # Generic visit method is disabled - all visitors must implement specific handlers
      def visit_generic(node)
        method_name = derive_visit_method_name_string(node)
        raise NotImplementedError, "Generic visitor is disabled. Implement #{method_name} for #{node.class.name}"
      end

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
          if node.respond_to?(:children) && node.children&.any?
            node.children.map { |child| extract_text(child) }.join
          elsif node.respond_to?(:content)
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

        if node.respond_to?(:children) && node.children
          node.children.map { |child| visit(child) }.join
        else
          extract_text(node)
        end
      end

      # Helper method to derive visit method name as string
      # This is useful for error messages and other string operations
      #
      # @param node [Object] The AST node
      # @return [String] The method name as string
      def derive_visit_method_name_string(node)
        class_name = node.class.name.split('::').last

        # Convert CamelCase to snake_case and remove 'Node' suffix
        method_name = class_name.
                      gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2').
                      gsub(/([a-z\d])([A-Z])/, '\1_\2').
                      downcase.
                      gsub(/_node$/, '')

        "visit_#{method_name}"
      end

      # Derive the visit method name from a node's class name.
      # Converts class names like 'HeadlineNode' to 'visit_headline'.
      #
      # @param node [Object] The AST node
      # @return [Symbol] The method name symbol
      def derive_visit_method_name(node)
        :"#{derive_visit_method_name_string(node)}"
      end
    end
  end
end
