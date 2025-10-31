# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

module ReVIEW
  module AST
    class BlockProcessor
      # TableProcessor - Handles table-related block processing
      #
      # This class is responsible for processing table block commands
      # (//table, //emtable, //imgtable) and converting them into
      # proper AST structures with TableNode, TableRowNode, and TableCellNode.
      #
      # Responsibilities:
      # - Parse table content lines into structured rows and cells
      # - Handle different table types (table, emtable, imgtable)
      # - Adjust column counts for consistency
      # - Process header/body row separation
      # - Handle inline elements within table cells
      #
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
              # Table has explicit header section separated by line
              new(
                header_lines: lines[0...separator_index],
                body_lines: lines[(separator_index + 1)..-1] || [],
                first_cell_header: false
              )
            else
              # No separator - all body rows with first cell as header
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
          def has_header_section?
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

              # Check if table only contains separator (no actual data rows)
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

        def initialize(ast_compiler)
          @ast_compiler = ast_compiler
        end

        # Build table AST node from block context
        # @param context [BlockContext] Block context
        # @return [TableNode] Created table node
        def build_table_node(context)
          node = case context.name
                 when :table
                   caption_data = context.process_caption(context.args, 1)
                   context.create_node(AST::TableNode,
                                       id: context.arg(0),
                                       caption_node: caption_node(caption_data),
                                       table_type: :table)
                 when :emtable
                   caption_data = context.process_caption(context.args, 0)
                   context.create_node(AST::TableNode,
                                       id: nil,
                                       caption_node: caption_node(caption_data),
                                       table_type: :emtable)
                 when :imgtable
                   caption_data = context.process_caption(context.args, 1)
                   context.create_node(AST::TableNode,
                                       id: context.arg(0),
                                       caption_node: caption_node(caption_data),
                                       table_type: :imgtable,
                                       metric: context.arg(2))
                 else
                   caption_data = context.process_caption(context.args, 1)
                   context.create_node(AST::TableNode,
                                       id: context.arg(0),
                                       caption_node: caption_node(caption_data),
                                       table_type: context.name)
                 end

          # Validate and process table rows
          # Check for empty table first (before context.content? check)
          # Note: imgtable can be empty as it embeds an image file, not table data
          if !context.content? || context.lines.nil? || context.lines.empty?
            unless context.name == :imgtable
              raise ReVIEW::CompileError, 'no rows in the table'
            end
          else
            # Process table content only if not empty
            process_content(node, context.lines, context.start_location)
          end

          # Process nested blocks
          context.process_nested_blocks(node)

          @ast_compiler.add_child_to_current_node(node)
          node
        end

        # Process table content lines into row nodes
        # @param table_node [TableNode] Table node to populate
        # @param lines [Array<String>] Content lines
        # @param block_location [Location] Block start location
        def process_content(table_node, lines, block_location = nil)
          structure = TableStructure.from_lines(lines)

          header_rows, body_rows = build_rows_from_structure(structure, block_location)

          adjust_columns(header_rows + body_rows)

          process_and_add_rows(table_node, header_rows, body_rows)
        end

        # Create table row node from a line containing tab-separated cells
        # @param line [String] Line content
        # @param is_header [Boolean] Whether all cells should be header cells
        # @param first_cell_header [Boolean] Whether only first cell should be header
        # @param block_location [Location] Block start location
        # @return [TableRowNode] Created row node
        def create_row(line, is_header: false, first_cell_header: false, block_location: nil)
          # Split by configured separator to get cells
          cells = line.strip.split(row_separator_regexp).map { |s| s.sub(/\A\./, '') }
          if cells.empty?
            error_location = block_location || @ast_compiler.location
            raise CompileError, "Invalid table row: empty line or no tab-separated cells#{format_location_info(error_location)}"
          end

          row_node = create_node(AST::TableRowNode, row_type: is_header ? :header : :body)

          cells.each_with_index do |cell_content, index|
            # Determine cell type based on row context and position
            cell_type = if is_header
                          :th # All cells in header rows are <th>
                        elsif first_cell_header && index == 0 # rubocop:disable Lint/DuplicateBranch
                          :th  # First cell in non-header rows is <th> (row header)
                        else
                          :td  # Regular data cells
                        end

            cell_node = create_node(AST::TableCellNode, cell_type: cell_type)

            # Parse inline elements in cell content
            # Note: prefix "." has already been removed during split
            @ast_compiler.inline_processor.parse_inline_elements(cell_content, cell_node)

            row_node.add_child(cell_node)
          end

          row_node
        end

        private

        # Build row nodes from table structure
        # @param structure [TableStructure] Table structure data
        # @param block_location [Location] Block start location
        # @return [Array<Array<TableRowNode>, Array<TableRowNode>>] Header rows and body rows
        def build_rows_from_structure(structure, block_location)
          header_rows = structure.header_lines.map do |line|
            create_row(line, is_header: true, block_location: block_location)
          end

          body_rows = structure.body_lines.map do |line|
            create_row(line, first_cell_header: structure.first_cell_header, block_location: block_location)
          end

          [header_rows, body_rows]
        end

        # Process and add rows to table node
        # @param table_node [TableNode] Table node to populate
        # @param header_rows [Array<TableRowNode>] Header rows
        # @param body_rows [Array<TableRowNode>] Body rows
        def process_and_add_rows(table_node, header_rows, body_rows)
          header_rows.each { |row| table_node.add_header_row(row) }
          body_rows.each { |row| table_node.add_body_row(row) }
        end

        # Adjust table row columns to ensure all rows have the same number of columns
        # Matches the behavior of Builder#adjust_n_cols
        # @param rows [Array<TableRowNode>] Rows to adjust
        def adjust_columns(rows)
          return if rows.empty?

          # Remove trailing empty cells from each row
          rows.each do |row|
            while row.children.last && row.children.last.children.empty?
              row.children.pop
            end
          end

          # Find maximum column count
          max_cols = rows.map { |row| row.children.size }.max

          # Add empty cells to rows that need them
          rows.each do |row|
            cells_needed = max_cols - row.children.size
            cells_needed.times do
              # Determine cell type based on whether this is a header row
              # Check if first cell is :th to determine if this is a header row
              cell_type = row.children.first&.cell_type == :th ? :th : :td
              empty_cell = create_node(AST::TableCellNode, cell_type: cell_type)
              row.add_child(empty_cell)
            end
          end
        end

        # Get table row separator regexp from config
        # Matches the logic in Builder#table_row_separator_regexp
        # @return [Regexp] Separator pattern
        def row_separator_regexp
          # Get config from chapter's book (same as Builder pattern)
          # Handle cases where chapter or book may not exist (e.g., in tests)
          chapter = @ast_compiler.chapter
          config = if chapter && chapter.respond_to?(:book) && chapter.book
                     chapter.book.config || {}
                   else
                     {}
                   end

          case config['table_row_separator']
          when 'singletab'
            /\t/
          when 'spaces'
            /\s+/
          when 'verticalbar'
            /\s*\|\s*/
          else
            # Default: 'tabs' or nil - consecutive tabs treated as one separator
            /\t+/
          end
        end

        # Create any AST node with location automatically set
        # @param node_class [Class] Node class to instantiate
        # @param attributes [Hash] Node attributes
        # @return [Node] Created node
        def create_node(node_class, **attributes)
          node_class.new(location: @ast_compiler.location, **attributes)
        end

        # Extract caption node from caption data hash
        # @param caption_data [Hash, nil] Caption data hash
        # @return [CaptionNode, nil] Caption node
        def caption_node(caption_data)
          caption_data && caption_data[:node]
        end

        # Format location information for error messages
        # @param location [Location, nil] Location object
        # @return [String] Formatted location string
        def format_location_info(location = nil)
          location ||= @ast_compiler.location
          return '' unless location

          info = " at line #{location.lineno}"
          info += " in #{location.filename}" if location.filename
          info
        end
      end
    end
  end
end
