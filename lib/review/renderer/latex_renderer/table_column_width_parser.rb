# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

module ReVIEW
  module Renderer
    class LatexRenderer < Base
      # Parse tsize specification and generate column width information
      # This class handles the logic from LATEXBuilder's tsize/separate_tsize methods
      class TableColumnWidthParser
      # Parse tsize string and generate column specification and cellwidth array
      # @param tsize [String] tsize specification (e.g., "10,18,50" or "p{10mm}p{18mm}|p{50mm}")
      # @param col_count [Integer] number of columns
      # @return [Hash] { col_spec: String, cellwidth: Array<String> }
      def self.parse(tsize, col_count)
        return default_spec(col_count) if tsize.nil? || tsize.empty?

        if simple_format?(tsize)
          parse_simple_format(tsize)
        else
          parse_complex_format(tsize)
        end
      end

      # Generate default column specification (left-aligned columns with borders)
      # @param col_count [Integer] number of columns
      # @return [Hash] { col_spec: String, cellwidth: Array<String> }
      def self.default_spec(col_count)
        {
          col_spec: '|' + ('l|' * col_count),
          cellwidth: ['l'] * col_count
        }
      end

      # Check if tsize is in simple format (e.g., "10,18,50")
      # @param tsize [String] tsize specification
      # @return [Boolean] true if simple format
      def self.simple_format?(tsize)
        /\A[\d., ]+\Z/.match?(tsize)
      end

      # Parse simple format tsize (e.g., "10,18,50" means p{10mm},p{18mm},p{50mm})
      # @param tsize [String] tsize specification
      # @return [Hash] { col_spec: String, cellwidth: Array<String> }
      def self.parse_simple_format(tsize)
        cellwidth = tsize.split(/\s*,\s*/)
        cellwidth.collect! { |i| "p{#{i}mm}" }
        col_spec = '|' + cellwidth.join('|') + '|'

        { col_spec: col_spec, cellwidth: cellwidth }
      end

      # Parse complex format tsize (e.g., "p{10mm}p{18mm}|p{50mm}")
      # @param tsize [String] tsize specification
      # @return [Hash] { col_spec: String, cellwidth: Array<String> }
      def self.parse_complex_format(tsize)
        cellwidth = separate_tsize(tsize)
        { col_spec: tsize, cellwidth: cellwidth }
      end

      # Parse tsize string into array of column specifications like LATEXBuilder
      # Example: "p{10mm}p{18mm}|p{50mm}" -> ["p{10mm}", "p{18mm}", "p{50mm}"]
      # @param size [String] tsize specification
      # @return [Array<String>] array of column specifications
      def self.separate_tsize(size)
        ret = []
        s = +''
        brace = nil

        size.chars.each do |ch|
          case ch
          when '|'
            # Skip pipe characters (table borders)
            next
          when '{'
            brace = true
            s << ch
          when '}'
            brace = nil
            s << ch
            ret << s
            s = +''
          else
            if brace || s.empty?
              s << ch
            else
              ret << s
              s = ch
            end
          end
        end

        unless s.empty?
          ret << s
        end

        ret
      end

      # Check if cellwidth is fixed-width format (contains {)
      # @param cellwidth [String] column width specification
      # @return [Boolean] true if fixed-width
      def self.fixed_width?(cellwidth)
        cellwidth =~ /\{/
      end
      end
    end
  end
end
