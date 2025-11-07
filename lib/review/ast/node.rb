# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'json'
require_relative 'json_serializer'

module ReVIEW
  module AST
    # Abstract base class for all AST nodes
    # This class should not be instantiated directly - use specific subclasses instead
    #
    # Design principles:
    # - Branch nodes (like ParagraphNode, InlineNode) inherit from Node and have children
    # - Leaf nodes (like TextNode, ImageNode) inherit from LeafNode and cannot have children
    # - LeafNode may have a content attribute, but subclasses can define their own data attributes
    # - Never mix content and children in the same node
    class Node
      attr_reader :location, :type, :id, :original_text, :children
      attr_accessor :parent

      def initialize(location:, type: nil, id: nil, original_text: nil, **_kwargs)
        # Prevent direct instantiation of abstract base class (except in tests)
        if self.instance_of?(ReVIEW::AST::Node)
          raise StandardError, 'AST::Node is an abstract class and cannot be instantiated directly. Use a specific subclass instead.'
        end

        @location = location
        @children = []
        @parent = nil
        @type = type
        @id = id
        @original_text = original_text
        @attributes = {}
      end

      def leaf_node?
        false
      end

      def reference_node?
        false
      end

      def accept(visitor)
        visitor.visit(self)
      end

      def add_child(child)
        child.parent = self
        @children << child
      end

      def remove_child(child)
        child.parent = nil
        @children.delete(child)
      end

      # Replace a child node with a new node
      def replace_child(old_child, new_child)
        index = @children.index(old_child)
        return false unless index

        old_child.parent = nil
        @children[index] = new_child
        new_child.parent = self
        true
      end

      def insert_child(idx, *nodes)
        nodes.each do |node|
          node.parent = self
        end
        @children.insert(idx, *nodes)
      end

      # Check if node has a non-empty id
      def id?
        @id && !@id.empty?
      end

      # Attribute management methods
      def add_attribute(key, value)
        @attributes[key] = value
      end

      def attribute?(key)
        @attributes.key?(key)
      end

      # Return the visit method name for this node as a symbol.
      # This is used by the Visitor pattern for method dispatch.
      #
      # @return [Symbol] The visit method symbol (e.g., :visit_headline)
      #
      # @example
      #   HeadlineNode.new.visit_method_name #=> :visit_headline
      def visit_method_name
        class_name = self.class.name.split('::').last

        # Convert CamelCase to snake_case and remove 'Node' suffix
        method_name = class_name.
                      gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2').
                      gsub(/([a-z\d])([A-Z])/, '\1_\2').
                      downcase.
                      gsub(/_node$/, '')

        :"visit_#{method_name}"
      end

      # Basic JSON serialization for compatibility
      def to_h
        result = {
          type: self.class.name.split('::').last,
          location: location&.to_h,
          children: children.map(&:to_h)
        }
        result[:node_type] = @type if @type && !@type.empty?
        result[:id] = @id if @id && !@id.empty?
        result
      end

      def to_json(*args)
        to_h.to_json(*args)
      end

      # Enhanced JSON serialization with options (using JSONSerializer)
      def serialize_to_hash(options = nil)
        options ||= JSONSerializer::Options.new

        # Start with type
        hash = {
          type: self.class.name.split('::').last
        }

        # Include location information
        if options.include_location
          hash[:location] = location&.to_h
        end

        # Call node-specific serialization
        serialize_properties(hash, options)

        # Serialize child nodes if any
        if children && children.any?
          hash[:children] = children.map { |child| child.serialize_to_hash(options) }
        end

        hash
      end

      private

      # Override this method in subclasses to add node-specific properties
      def serialize_properties(hash, _options)
        # Base Node implementation - does nothing by default
        hash
      end
    end
  end
end
