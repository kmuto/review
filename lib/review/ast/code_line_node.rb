# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require_relative 'node'

module ReVIEW
  module AST
    # CodeLineNode - Represents a line in a code block
    #
    # A code line can contain text nodes and inline elements.
    # Line numbers are tracked for numbered code blocks (listnum, emlistnum).
    class CodeLineNode < Node
      def initialize(location:, line_number: nil, original_text: '', **kwargs)
        super(location: location, **kwargs)
        @line_number = line_number
        @original_text = original_text
        @children = []
      end

      attr_reader :line_number, :original_text, :children

      def accept(visitor)
        visitor.visit_code_line(self)
      end

      # Override to_h to include original_text
      def to_h
        result = super
        result[:line_number] = line_number
        result[:original_text] = original_text
        result
      end

      # Override serialize_to_hash to include original_text
      def serialize_to_hash(options = nil)
        hash = super
        hash[:line_number] = line_number if line_number
        hash[:original_text] = original_text
        hash
      end
    end
  end
end
