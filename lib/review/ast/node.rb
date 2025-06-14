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
      attr_accessor :location, :parent, :children, :type, :id, :content

      def initialize(location = nil)
        @location = location
        @children = []
        @parent = nil
        @type = nil
        @id = nil
        @content = nil
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

      # For JSON output
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

      # Serialize node to hash with options
      def serialize_to_hash(options = nil)
        options ||= JSONSerializer::Options.new

        # Start with type
        hash = {
          type: self.class.name.split('::').last
        }

        # Include location information
        if options.include_location && location
          hash[:location] = serialize_location(location)
        end

        # Call node-specific serialization
        serialize_properties(hash, options)

        # Serialize child nodes if any
        if children && (options.include_empty_arrays || children.any?)
          hash[:children] = children.map { |child| child.serialize_to_hash(options) }
        end

        hash
      end

      # Custom JSON serialization with options
      def to_json_with_options(options = nil)
        options ||= JSONSerializer::Options.new
        hash = serialize_to_hash(options)
        if options.pretty
          JSON.pretty_generate(hash, indent: options.indent)
        else
          JSON.generate(hash)
        end
      end

      # JSON serialization preserving hierarchical structure
      def to_pretty_json(indent: '  ')
        options = JSONSerializer::Options.new
        options.indent = indent
        to_json_with_options(options)
      end

      # Compact JSON serialization (without location information)
      def to_compact_json
        options = JSONSerializer::Options.new
        options.include_location = false
        options.include_empty_arrays = false
        options.pretty = false
        to_json_with_options(options)
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

      # Serialize location information
      def serialize_location(location)
        {
          filename: location.respond_to?(:filename) ? location.filename : nil,
          lineno: location.respond_to?(:lineno) ? location.lineno : nil
        }
      end

      private

      def location_to_h
        return nil unless location

        begin
          {
            filename: location.filename,
            lineno: location.lineno
          }
        rescue StandardError
          {
            filename: location.filename,
            lineno: nil
          }
        end
      end
    end
  end
end
