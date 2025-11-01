# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

module ReVIEW
  module Renderer
    # FootnoteCollector - Collects and manages footnotes within a rendering context
    #
    # This class handles the collection of footnotes that occur in contexts where
    # they cannot be rendered immediately (e.g., within table captions, minicolumns).
    # Instead of rendering \footnote{} directly, these contexts use \footnotemark
    # and collect the footnotes for later output as \footnotetext{}.
    #
    # Key responsibilities:
    # - Collect footnote nodes and their assigned numbers
    # - Generate appropriate footnotetext output for LaTeX
    # - Generate appropriate footnote output for HTML
    # - Track footnote order and numbering
    class FootnoteCollector
      include Enumerable

      # Footnote data structure
      FootnoteEntry = Struct.new(:node, :number, :content, keyword_init: true)

      def initialize
        @footnotes = []
      end

      # Add a footnote to the collection
      # @param footnote_node [AST::FootnoteNode] the footnote AST node
      # @param footnote_number [Integer] the assigned footnote number
      def add(footnote_node, footnote_number)
        entry = FootnoteEntry.new(
          node: footnote_node,
          number: footnote_number,
          content: nil # Content will be rendered when needed
        )
        @footnotes << entry
      end

      # Get the number of collected footnotes
      # @return [Integer] number of footnotes
      def size
        @footnotes.size
      end

      # Clear all collected footnotes
      def clear
        @footnotes.clear
      end

      # Iterate over collected footnotes
      # @yield [FootnoteEntry] each footnote entry
      def each(&block)
        @footnotes.each(&block)
      end

      # Get all footnote numbers in order
      # @return [Array<Integer>] array of footnote numbers
      def numbers
        @footnotes.map(&:number)
      end

      # Convert to hash for debugging/serialization
      # @return [Hash] hash representation
      def to_h
        {
          size: size,
          numbers: numbers,
          footnotes: @footnotes.map do |entry|
            # Get text preview from footnote node children
            preview_text = if entry.node.respond_to?(:to_text)
                             entry.node.to_text
                           else
                             ''
                           end
            {
              number: entry.number,
              id: entry.node.id,
              content_preview: preview_text.slice(0, 50)
            }
          end
        }
      end

      # String representation for debugging
      # @return [String] string representation
      def to_s
        if @footnotes.empty?
          'FootnoteCollector[empty]'
        else
          numbers_str = numbers.join(', ')
          "FootnoteCollector[#{size} footnotes: #{numbers_str}]"
        end
      end
    end
  end
end
