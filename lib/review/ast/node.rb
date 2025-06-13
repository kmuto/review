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
      attr_accessor :location, :parent, :children

      def initialize(location = nil)
        @location = location
        @children = []
        @parent = nil
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
        {
          type: self.class.name.split('::').last,
          location: location_to_h,
          children: children.map(&:to_h)
        }
      end

      def to_json(*args)
        to_h.to_json(*args)
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
