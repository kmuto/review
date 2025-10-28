# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

module ReVIEW
  module AST
    # ListParser - Parse list lines and extract structured information
    #
    # This class handles parsing of different list types in Re:VIEW markup:
    # - Unordered lists (ul): * item content
    # - Ordered lists (ol): 1. item content
    # - Definition lists (dl): : term content
    #
    # Responsibilities:
    # - Parse individual list lines to extract level, content, and metadata
    # - Handle continuation lines that belong to list items
    # - Provide structured data for list builders to construct AST nodes
    class ListParser
      # Parsed list item data structure
      ListItemData = Struct.new(:type, :level, :content, :continuation_lines, :metadata, keyword_init: true) do
        def initialize(**args)
          super
          self.level ||= 1
          self.continuation_lines ||= []
          self.metadata ||= {}
        end

        # Create a new ListItemData with adjusted level
        # @param new_level [Integer] New level value
        # @return [ListItemData] New instance with adjusted level, or self if no change needed
        def with_adjusted_level(new_level)
          return self if new_level == level

          ListItemData.new(
            type: type,
            level: new_level,
            content: content,
            continuation_lines: continuation_lines,
            metadata: metadata
          )
        end
      end

      def initialize(location_provider = nil)
        @location_provider = location_provider
      end

      # Parse unordered list items from file input
      # @param f [LineInput] Input file stream
      # @return [Array<ListItemData>] Parsed list items
      def parse_unordered_list(f)
        items = []

        f.while_match(/\A\s+\*|\A\#@/) do |line|
          next if comment_line?(line)

          item_data = parse_unordered_line(line)
          next unless item_data

          # Collect continuation lines directly within this context
          continuation_lines = []
          f.while_match(/\A\s+(?!\*)\S/) do |cont|
            continuation_lines << cont.strip
          end
          item_data.continuation_lines = continuation_lines

          items << item_data
        end

        items
      end

      # Parse ordered list items from file input
      # @param f [LineInput] Input file stream
      # @return [Array<ListItemData>] Parsed list items
      def parse_ordered_list(f)
        items = []

        f.while_match(/\A\s+\d+\.|\A\#@/) do |line|
          next if comment_line?(line)

          item_data = parse_ordered_line(line)
          next unless item_data

          # Collect continuation lines directly within this context
          continuation_lines = []
          f.while_match(/\A\s+(?!\d+\.)\S/) do |cont|
            continuation_lines << cont.strip
          end
          item_data.continuation_lines = continuation_lines

          items << item_data
        end

        items
      end

      # Parse definition list items from file input
      # @param f [LineInput] Input file stream
      # @return [Array<ListItemData>] Parsed list items
      def parse_definition_list(f)
        items = []

        f.while_match(/\A\s*:|\A\#@/) do |line|
          next if comment_line?(line)

          item_data = parse_definition_line(line)
          next unless item_data

          # Collect definition content lines directly within this context
          continuation_lines = []
          f.while_match(/\A\s+(?!:)\S/) do |cont|
            continuation_lines << cont.strip
          end
          item_data.continuation_lines = continuation_lines

          items << item_data
        end

        items
      end

      private

      # Parse a single unordered list line
      # @param line [String] Input line
      # @return [ListItemData, nil] Parsed item data or nil if invalid
      def parse_unordered_line(line)
        # Extract level and content - Re:VIEW uses space indentation + * for nesting
        match = line.match(/\A(\s*)(\*+)\s*(.*)$/)
        return nil unless match

        indent_spaces = match[1].length
        stars = match[2].size
        content = match[3].strip

        # Calculate nesting level based on stars (*, **, ***, etc.)
        level = stars

        ListItemData.new(
          type: :ul,
          level: level,
          content: content,
          metadata: { stars: stars, indent_spaces: indent_spaces }
        )
      end

      # Parse a single ordered list line
      # @param line [String] Input line
      # @return [ListItemData, nil] Parsed item data or nil if invalid
      def parse_ordered_line(line)
        # Extract indentation, number and content
        match = line.match(/\A(\s+)(\d+)\.\s*(.*)$/)
        return nil unless match

        _indent = match[1]
        num = match[2]
        content = match[3].strip

        # Re:VIEW ordered lists do not support nesting - all items are level 1
        # The number format (1, 11, 111, etc.) is just the actual number, not a level indicator
        level = 1

        ListItemData.new(
          type: :ol,
          level: level,
          content: content,
          metadata: { number: num.to_i, number_string: num }
        )
      end

      # Parse a single definition list line
      # @param line [String] Input line
      # @return [ListItemData, nil] Parsed item data or nil if invalid
      def parse_definition_line(line)
        # Extract term
        match = line.match(/\A\s*:\s*(.*)$/)
        return nil unless match

        term = match[1].strip

        ListItemData.new(
          type: :dl,
          level: 1, # Definition lists are always level 1
          content: term,
          metadata: { is_term: true }
        )
      end

      # Check if line is a comment line
      # @param line [String] Input line
      # @return [Boolean] True if comment line
      def comment_line?(line)
        /\A\#@/.match?(line)
      end
    end
  end
end
