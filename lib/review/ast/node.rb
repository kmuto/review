# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'json'
require_relative 'json_serializer'

module ReVIEW
  module AST
    class Node
      attr_accessor :location, :parent, :children, :type, :id, :content, :original_text

      def initialize(location: nil, type: nil, id: nil, content: nil, original_text: nil, **_kwargs)
        @location = location
        @children = []
        @parent = nil
        @type = type
        @id = id
        @content = content
        @original_text = original_text
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

      # Basic JSON serialization for compatibility
      def to_h
        result = {
          type: self.class.name.split('::').last,
          location: location_to_h,
          children: children.map(&:to_h)
        }
        result[:node_type] = @type if @type && !@type.empty?
        result[:id] = @id if @id && !@id.empty?
        result[:content] = @content if @content && !@content.empty?
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
          hash[:location] = location_to_h
        end

        # Call node-specific serialization
        serialize_properties(hash, options)

        # Serialize child nodes if any
        if children && (options.include_empty_arrays || children.any?)
          hash[:children] = children.map { |child| child.serialize_to_hash(options) }
        end

        hash
      end

      protected

      # Override this method in subclasses to add node-specific properties
      def serialize_properties(hash, options)
        # Base Node implementation
        hash[:children] = [] if children.none? && options.include_empty_arrays

        # Handle generic Node instances (used for read, minicolumn, etc.)
        if instance_of?(ReVIEW::AST::Node)
          hash[:node_type] = type if type && !type.empty?
          hash[:id] = id if id && !id.empty?
          hash[:content] = content if content && !content.empty?
        end

        hash
      end

      private

      def location_to_h
        return nil unless location

        {
          filename: location.filename,
          lineno: location.lineno
        }
      end
    end
  end
end
