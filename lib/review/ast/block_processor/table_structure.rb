# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

module ReVIEW
  module AST
    class BlockProcessor
      class TableProcessor
        # Data structure representing table structure (intermediate representation)
        # This class represents the result of parsing table text lines into a structured format.
        # It serves as an intermediate layer between raw text and AST nodes.
        class TableStructure
          attr_reader :header_lines, :body_lines, :first_cell_header

          # Factory method to create TableStructure from raw text lines
          # @param lines [Array<String>] Raw table content lines
          # @return [TableStructure] Parsed table structure
          # @raise [ReVIEW::CompileError] If table is empty or invalid
          def self.from_lines(lines)
            validate_lines(lines)
            separator_index = find_separator_index(lines)

            if separator_index
              new(
                header_lines: lines[0...separator_index],
                body_lines: lines[(separator_index + 1)..-1] || [],
                first_cell_header: false
              )
            else
              new(
                header_lines: [],
                body_lines: lines,
                first_cell_header: true
              )
            end
          end

          def initialize(header_lines:, body_lines:, first_cell_header:)
            @header_lines = header_lines
            @body_lines = body_lines
            @first_cell_header = first_cell_header
          end

          # Check if table has explicit header section (separated by line)
          # @return [Boolean] True if has separator and header section
          def header_section?
            !header_lines.empty?
          end

          # Get total number of rows (header + body)
          # @return [Integer] Total row count
          def total_row_count
            header_lines.size + body_lines.size
          end

          class << self
            private

            # Validate table lines for emptiness and structure
            # @param lines [Array<String>] Content lines
            # @raise [ReVIEW::CompileError] If table is empty or only contains separator
            def validate_lines(lines)
              if lines.nil? || lines.empty?
                raise ReVIEW::CompileError, 'no rows in the table'
              end

              separator_index = find_separator_index(lines)

              if separator_index && separator_index == 0 && lines.length == 1
                raise ReVIEW::CompileError, 'no rows in the table'
              end
            end

            # Find separator line index in table lines
            # @param lines [Array<String>] Content lines
            # @return [Integer, nil] Separator index or nil if not found
            def find_separator_index(lines)
              lines.find_index { |line| line.match?(/\A[=-]{12}/) || line.match?(/\A[={}-]{12}/) }
            end
          end
        end
      end
    end
  end
end
