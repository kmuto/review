# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'json'

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

      # Custom JSON serialization with options
      def to_json_with_options(options = nil)
        require_relative('json_serializer')
        JSONSerializer.serialize(self, options || JSONSerializer::Options.new)
      end

      # JSON serialization preserving hierarchical structure
      def to_pretty_json(indent: '  ')
        JSON.pretty_generate(to_h, indent: indent)
      end

      # Compact JSON serialization (without location information)
      def to_compact_json
        options = JSONSerializer::Options.new
        options.include_location = false
        options.include_empty_arrays = false
        options.pretty = false
        to_json_with_options(options)
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
