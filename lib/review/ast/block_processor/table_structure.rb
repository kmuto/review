# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

module ReVIEW
  module AST
    class BlockProcessor
      class TableProcessor
        # Data structure representing table structure (intermediate representation)
        class TableStructure
          attr_reader :header_lines, :body_lines, :first_cell_header

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

          class << self
            private

            # @param lines [Array<String>] Content lines
            def validate_lines(lines)
              if lines.nil? || lines.empty?
                raise ReVIEW::CompileError, 'no rows in the table'
              end

              separator_index = find_separator_index(lines)

              if separator_index && separator_index == 0 && lines.length == 1
                raise ReVIEW::CompileError, 'no rows in the table'
              end
            end

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
