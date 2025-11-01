# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require_relative 'table_structure'

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
        def initialize(ast_compiler)
          @ast_compiler = ast_compiler
        end

        # Build table AST node from block context
        # @param context [BlockContext] Block context
        # @return [TableNode] Created table node
        def build_table_node(context)
          node = case context.name
                 when :table
                   caption_node = context.process_caption(context.args, 1)
                   context.create_node(AST::TableNode,
                                       id: context.arg(0),
                                       caption_node: caption_node,
                                       table_type: :table)
                 when :emtable
                   caption_node = context.process_caption(context.args, 0)
                   context.create_node(AST::TableNode,
                                       id: nil,
                                       caption_node: caption_node,
                                       table_type: :emtable)
                 when :imgtable
                   caption_node = context.process_caption(context.args, 1)
                   context.create_node(AST::TableNode,
                                       id: context.arg(0),
                                       caption_node: caption_node,
                                       table_type: :imgtable,
                                       metric: context.arg(2))
                 else
                   caption_node = context.process_caption(context.args, 1)
                   context.create_node(AST::TableNode,
                                       id: context.arg(0),
                                       caption_node: caption_node,
                                       table_type: context.name)
                 end

          if !context.content? || context.lines.nil? || context.lines.empty?
            unless context.name == :imgtable
              raise ReVIEW::CompileError, 'no rows in the table'
            end
          else
            process_content(node, context.lines, context.start_location)
          end

          context.process_nested_blocks(node)

          @ast_compiler.add_child_to_current_node(node)
          node
        end

        # Process table content lines into row nodes
        # @param table_node [TableNode] Table node to populate
        # @param lines [Array<String>] Content lines
        # @param block_location [Location] Block start location
        def process_content(table_node, lines, block_location)
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
        def create_row(line, block_location:, is_header: false, first_cell_header: false)
          cells = line.strip.split(row_separator_regexp).map { |s| s.sub(/\A\./, '') }
          if cells.empty?
            location_info = block_location.format_for_error
            raise CompileError, "Invalid table row: empty line or no tab-separated cells#{location_info}"
          end

          row_node = create_node(AST::TableRowNode, row_type: is_header ? :header : :body)

          cells.each_with_index do |cell_content, index|
            cell_type = if is_header
                          :th
                        elsif first_cell_header && index == 0 # rubocop:disable Lint/DuplicateBranch
                          :th
                        else
                          :td
                        end

            cell_node = create_node(AST::TableCellNode, cell_type: cell_type)
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

          rows.each do |row|
            while row.children.last && row.children.last.children.empty?
              row.children.pop
            end
          end

          max_cols = rows.map { |row| row.children.size }.max

          rows.each do |row|
            cells_needed = max_cols - row.children.size
            cell_type = row.children.first&.cell_type || :td
            cells_needed.times do
              empty_cell = create_node(AST::TableCellNode, cell_type: cell_type)
              row.add_child(empty_cell)
            end
          end
        end

        # Get table row separator regexp from config
        # Matches the logic in Builder#table_row_separator_regexp
        # @return [Regexp] Separator pattern
        def row_separator_regexp
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
      end
    end
  end
end
