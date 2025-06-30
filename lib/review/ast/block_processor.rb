# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/ast'
require 'review/ast/block_data'
require 'review/lineinput'
require 'stringio'

module ReVIEW
  module AST
    # BlockProcessor - Block command processing and AST building
    #
    # This class handles the conversion of Re:VIEW block commands to AST nodes,
    # including code blocks, images, tables, lists, quotes, and minicolumns.
    #
    # Responsibilities:
    # - Process block commands (//list, //image, //table, etc.)
    # - Build appropriate AST nodes for block elements
    # - Handle block-specific parsing (table structure, list items, etc.)
    # - Coordinate with inline processor for content within blocks
    class BlockProcessor
      def initialize(ast_compiler)
        @ast_compiler = ast_compiler
        # Copy the static table to allow runtime modifications
        @dynamic_command_table = BLOCK_COMMAND_TABLE.dup
      end

      # Register a new block command handler
      # @param command_name [Symbol] The block command name (e.g., :custom_block)
      # @param handler_method [Symbol] The method name to handle this command
      # @example
      #   register_block_handler(:custom_block, :build_custom_block_ast)
      def register_block_handler(command_name, handler_method)
        @dynamic_command_table[command_name] = handler_method
      end

      # Unregister a block command handler
      # @param command_name [Symbol] The block command name to remove
      def unregister_block_handler(command_name)
        @dynamic_command_table.delete(command_name)
      end

      # Get all registered block commands
      # @return [Array<Symbol>] List of all registered command names
      def registered_commands
        @dynamic_command_table.keys
      end

      # Unified entry point - table-driven block processing
      # Receives BlockData and calls corresponding method based on dynamic command table
      def process_block_command(block_data)
        handler_method = @dynamic_command_table[block_data.name]

        unless handler_method
          raise CompileError, "Unknown block command: //#{block_data.name}#{format_location_info(block_data.location)}"
        end

        # Process block using Block-Scoped Compilation
        @ast_compiler.with_block_context(block_data) do |context|
          send(handler_method, context)
        end
      end

      def compile_code_block_to_ast(type, args, lines)
        create_code_block_node(type, args, lines)
      end

      def compile_image_to_ast(type, args)
        create_and_add_node(AST::ImageNode,
                            id: args[0],
                            caption: process_caption(args, 1),
                            metric: args[2],
                            image_type: type)
      end

      def compile_table_to_ast(type, args, lines)
        node = case type
               when :table
                 create_node(AST::TableNode,
                             id: args[0],
                             caption: process_caption(args, 1),
                             table_type: :table)
               when :emtable
                 create_node(AST::TableNode,
                             id: nil, # emtable has no ID
                             caption: process_caption(args, 0),
                             table_type: :emtable)
               when :imgtable
                 create_node(AST::TableNode,
                             id: args[0],
                             caption: process_caption(args, 1),
                             table_type: :imgtable,
                             metric: args[2])
               else
                 # Fallback for unknown table types
                 create_node(AST::TableNode,
                             id: args[0],
                             caption: process_caption(args, 1),
                             table_type: type)
               end

        if lines
          separator_index = lines.find_index { |line| line.match?(/\A[=-]{12}/) || line.match?(/\A[={}-]{12}/) }

          # Process header rows
          if separator_index
            header_lines = lines[0...separator_index]
            header_lines.each do |line|
              row_node = create_table_row_from_line(line, is_header: true, block_location: @ast_compiler.location)
              node.add_header_row(row_node)
            end

            # Process body rows
            body_lines = lines[(separator_index + 1)..-1] || []
            body_lines.each do |line|
              row_node = create_table_row_from_line(line, first_cell_header: false, block_location: @ast_compiler.location)
              node.add_body_row(row_node)
            end
          else
            # No separator, all lines are body rows with first cell as header
            lines.each do |line|
              row_node = create_table_row_from_line(line, first_cell_header: true, block_location: @ast_compiler.location)
              node.add_body_row(row_node)
            end
          end
        end

        add_node_to_ast(node)
      end

      def compile_list_to_ast(type, lines)
        # Create list node and add items as children
        list_node = create_and_add_node(AST::ListNode, list_type: type)

        lines.each do |line|
          item_node = create_node(AST::ListItemNode,
                                  content: line,
                                  level: 1)
          list_node.add_child(item_node)
        end

        list_node
      end

      def compile_block_to_ast(lines, block_type)
        # Create a BlockNode for quote blocks and other block types
        node = AST::BlockNode.new(
          location: @ast_compiler.location,
          block_type: block_type
        )

        if lines && lines.any?
          # Use the universal block processing method for structured content like lists and paragraphs
          case block_type
          when :quote, :lead, :blockquote, :read, :centering, :flushright, :address, :talk
            # These block types can contain structured content (paragraphs, lists)
            @ast_compiler.process_structured_content(node, lines)
          else
            # For other block types, use simple inline processing
            lines.each { |line| @ast_compiler.inline_processor.parse_inline_elements(line, node) }
          end
        end

        @ast_compiler.add_child_to_current_node(node)
      end

      def compile_minicolumn_to_ast(type, args, lines)
        # Create a MinicolumnNode for note, memo, tip, etc.
        node = AST::MinicolumnNode.new(
          location: @ast_compiler.location,
          minicolumn_type: type.to_sym,
          caption: process_caption(args, 0)
        )

        # Use the universal block processing method from Compiler for HTML Builder compatibility
        # This processes content using the same logic as regular document processing
        @ast_compiler.process_structured_content(node, lines)

        @ast_compiler.add_child_to_current_node(node)
      end

      def compile_embed_to_ast(args, lines)
        node = AST::EmbedNode.new(
          location: @ast_compiler.location,
          embed_type: :block,
          arg: args[0],
          lines: lines || []
        )

        @ast_compiler.add_child_to_current_node(node)
      end

      # Compile footnote to AST (entry point from compiler)
      def compile_footnote_to_ast(command_name, args, lines)
        build_footnote_ast(command_name, args, lines)
      end

      private

      # New methods supporting BlockData

      # Build code block (with nesting support)
      # Use BlockContext for consistent location information in AST construction
      def build_code_block_ast(context)
        config = CODE_BLOCK_CONFIGS[context.name]
        unless config
          raise CompileError, "Unknown code block type: #{context.name}#{context.format_location_info}"
        end

        # Preserve original text
        original_text = context.lines ? context.lines.join("\n") : ''

        # Create node using BlockContext (location automatically set to block start position)
        node = context.create_node(AST::CodeBlockNode,
                                   id: context.arg(config[:id_index]),
                                   caption: context.process_caption(context.args, config[:caption_index]),
                                   lang: context.arg(config[:lang_index]) || config[:default_lang],
                                   line_numbers: config[:line_numbers] || false,
                                   code_type: context.name,
                                   original_text: original_text)

        # Process main content
        if context.content?
          context.lines.each_with_index do |line, index|
            line_node = context.create_node(AST::CodeLineNode,
                                            line_number: config[:line_numbers] ? index + 1 : nil,
                                            original_text: line)

            # When inline processing is needed (BlockContext properly manages location information)
            if builder_needs_inline_processing?
              context.process_inline_elements(line, line_node)
            else
              text_node = context.create_node(AST::TextNode, content: line)
              line_node.add_child(text_node)
            end

            node.add_child(line_node)
          end
        end

        # Process nested blocks
        context.process_nested_blocks(node)

        # Add node to current AST
        @ast_compiler.add_child_to_current_node(node)
        node
      end

      # Build image block
      def build_image_ast(context)
        node = context.create_node(AST::ImageNode,
                                   id: context.arg(0),
                                   caption: context.process_caption(context.args, 1),
                                   metric: context.arg(2),
                                   image_type: context.name)
        @ast_compiler.add_child_to_current_node(node)
        node
      end

      # Build table block (with nesting support)
      def build_table_ast(context)
        node = case context.name
               when :table
                 context.create_node(AST::TableNode,
                                     id: context.arg(0),
                                     caption: context.process_caption(context.args, 1),
                                     table_type: :table)
               when :emtable
                 context.create_node(AST::TableNode,
                                     id: nil,
                                     caption: context.process_caption(context.args, 0),
                                     table_type: :emtable)
               when :imgtable
                 context.create_node(AST::TableNode,
                                     id: context.arg(0),
                                     caption: context.process_caption(context.args, 1),
                                     table_type: :imgtable,
                                     metric: context.arg(2))
               else
                 context.create_node(AST::TableNode,
                                     id: context.arg(0),
                                     caption: context.process_caption(context.args, 1),
                                     table_type: context.name)
               end

        # Process table rows
        if context.content?
          process_table_content(node, context.lines, context.start_location)
        end

        # Process nested blocks
        context.process_nested_blocks(node)

        @ast_compiler.add_child_to_current_node(node)
        node
      end

      # Build simple list
      def build_simple_list_ast(context)
        list_node = context.create_node(AST::ListNode, list_type: context.name)

        if context.content?
          context.lines.each do |line|
            item_node = context.create_node(AST::ListItemNode,
                                            content: line,
                                            level: 1)
            list_node.add_child(item_node)
          end
        end

        # Process nested blocks
        context.process_nested_blocks(list_node)

        @ast_compiler.add_child_to_current_node(list_node)
        list_node
      end

      # Build minicolumn (with nesting support)
      def build_minicolumn_ast(context)
        node = context.create_node(AST::MinicolumnNode,
                                   minicolumn_type: context.name,
                                   caption: context.process_caption(context.args, 0))

        # Process structured content
        context.process_structured_content_with_blocks(node)

        @ast_compiler.add_child_to_current_node(node)
        node
      end

      # Build quote block
      def build_quote_block_ast(context)
        node = context.create_node(AST::BlockNode, block_type: context.name)

        # Process structured content and nested blocks
        if context.nested_blocks?
          context.process_structured_content_with_blocks(node)
        elsif context.content?
          case context.name
          when :quote, :lead, :blockquote, :read, :centering, :flushright, :address, :talk
            @ast_compiler.process_structured_content(node, context.lines)
          else
            context.lines.each { |line| context.process_inline_elements(line, node) }
          end
        end

        @ast_compiler.add_child_to_current_node(node)
        node
      end

      # Build complex block
      def build_complex_block_ast(context)
        node = context.create_node(AST::BlockNode,
                                   block_type: context.name,
                                   args: context.args)

        # Process content and nested blocks
        if context.nested_blocks?
          context.process_structured_content_with_blocks(node)
        elsif context.content?
          context.lines.each do |line|
            context.process_inline_elements(line, node)
          end
        end

        @ast_compiler.add_child_to_current_node(node)
        node
      end

      # Build control command
      def build_control_command_ast(context)
        case context.name
        when :texequation
          build_tex_equation_ast(context)
        else
          node = context.create_node(AST::BlockNode,
                                     block_type: context.name,
                                     args: context.args)

          if context.content?
            context.lines.each do |line|
              text_node = context.create_node(AST::TextNode, content: line)
              node.add_child(text_node)
            end
          end

          @ast_compiler.add_child_to_current_node(node)
          node
        end
      end

      # TeX数式構築
      def build_tex_equation_ast(context)
        require 'review/ast/tex_equation_node'
        node = context.create_node(AST::TexEquationNode,
                                   id: context.arg(0),
                                   caption: context.arg(1))

        if context.content?
          context.lines.each { |line| node.add_content_line(line) }
        end

        @ast_compiler.add_child_to_current_node(node)
        node
      end

      # Raw AST構築
      def build_raw_ast(context)
        raw_content = context.arg(0) || ''
        target_builders, content = parse_raw_content(raw_content)

        node = context.create_node(AST::EmbedNode,
                                   embed_type: :raw,
                                   lines: context.lines || [],
                                   arg: raw_content,
                                   target_builders: target_builders,
                                   content: content)

        @ast_compiler.add_child_to_current_node(node)
        node
      end

      # Embed AST構築
      def build_embed_ast(context)
        node = context.create_node(AST::EmbedNode,
                                   embed_type: :block,
                                   arg: context.arg(0),
                                   lines: context.lines || [])

        @ast_compiler.add_child_to_current_node(node)
        node
      end

      # Build footnote
      def build_footnote_ast(context)
        footnote_id = context.arg(0)
        footnote_content = context.arg(1) || ''

        node = context.create_node(AST::FootnoteNode,
                                   id: footnote_id,
                                   content: footnote_content,
                                   footnote_type: context.name)

        if footnote_content && !footnote_content.empty?
          context.process_inline_elements(footnote_content, node)
        end

        @ast_compiler.add_child_to_current_node(node)
        node
      end

      # Process nested blocks
      def process_nested_blocks(parent_node, block_data)
        return unless block_data.nested_blocks?

        # Save current node context
        saved_current_node = @ast_compiler.current_ast_node
        @ast_compiler.instance_variable_set(:@current_ast_node, parent_node)

        # Process nested blocks recursively
        block_data.nested_blocks.each do |nested_block|
          process_block_command(nested_block)
        end

        # Restore context
        @ast_compiler.instance_variable_set(:@current_ast_node, saved_current_node)
      end

      # Process structured content including nested blocks
      def process_structured_content_with_blocks(parent_node, block_data)
        # Process regular lines
        @ast_compiler.process_structured_content(parent_node, block_data.lines) if block_data.content?

        # Process nested blocks
        process_nested_blocks(parent_node, block_data)
      end

      # Process table content
      def process_table_content(table_node, lines, block_location = nil)
        separator_index = lines.find_index { |line| line.match?(/\A[=-]{12}/) || line.match?(/\A[={}-]{12}/) }

        if separator_index
          # Process header rows
          header_lines = lines[0...separator_index]
          header_lines.each do |line|
            row_node = create_table_row_from_line(line, is_header: true, block_location: block_location)
            table_node.add_header_row(row_node)
          end

          # Process body rows
          body_lines = lines[(separator_index + 1)..-1] || []
          body_lines.each do |line|
            row_node = create_table_row_from_line(line, first_cell_header: false, block_location: block_location)
            table_node.add_body_row(row_node)
          end
        else
          # No separator - all body rows (first cell as header)
          lines.each do |line|
            row_node = create_table_row_from_line(line, first_cell_header: true, block_location: block_location)
            table_node.add_body_row(row_node)
          end
        end
      end

      # Format location information for error messages
      def format_location_info(location = nil)
        location ||= @ast_compiler.location
        return '' unless location

        info = " at line #{location.lineno}"
        info += " in #{location.filename}" if location.filename
        info
      end

      # Common AST node creation helpers

      # Create any AST node with location automatically set
      def create_node(node_class, **attributes)
        node_class.new(location: @ast_compiler.location, **attributes)
      end

      # Create AST node and add to current node in one step
      def create_and_add_node(node_class, **attributes)
        node = create_node(node_class, **attributes)
        add_node_to_ast(node)
        node
      end

      # Add node to current AST node
      def add_node_to_ast(node)
        @ast_compiler.add_child_to_current_node(node)
      end

      # Create text node with content
      def create_text_node(content)
        create_node(AST::TextNode, content: content)
      end

      # Unified factory method for creating code block nodes
      def create_code_block_node(command_type, args, lines)
        config = CODE_BLOCK_CONFIGS[command_type]
        unless config
          raise ArgumentError, "Unknown code block type: #{command_type}#{format_location_info}"
        end

        # Preserve original text for builders that don't need inline processing
        original_text = lines ? lines.join("\n") : ''

        node = create_and_add_node(AST::CodeBlockNode,
                                   id: safe_arg(args, config[:id_index]),
                                   caption: process_caption(args, config[:caption_index]),
                                   lang: safe_arg(args, config[:lang_index]) || config[:default_lang],
                                   line_numbers: config[:line_numbers] || false,
                                   code_type: command_type,
                                   original_text: original_text)

        # Process each line and create CodeLineNode
        if lines
          lines.each_with_index do |line, index|
            line_node = create_node(AST::CodeLineNode,
                                    line_number: config[:line_numbers] ? index + 1 : nil,
                                    original_text: line)

            # Check if this builder needs inline processing
            if builder_needs_inline_processing?
              # Parse inline elements in code line
              @ast_compiler.inline_processor.parse_inline_elements(line, line_node)
            else
              # Create simple TextNode for the entire line
              text_node = create_node(AST::TextNode, content: line)
              line_node.add_child(text_node)
            end

            node.add_child(line_node)
          end
        end

        node
      end

      def process_caption(args, caption_index, location = nil)
        caption_text = safe_arg(args, caption_index)
        return nil if caption_text.nil?

        # Location information priority: argument > @ast_compiler.location
        caption_location = location || @ast_compiler.location

        begin
          AST::CaptionNode.parse(
            caption_text,
            location: caption_location,
            inline_processor: @ast_compiler.inline_processor
          )
        rescue StandardError => e
          raise CompileError, "Error processing caption '#{caption_text}': #{e.message}#{format_location_info(caption_location)}"
        end
      end

      # Extract argument safely
      def safe_arg(args, index)
        return nil unless args && index && index.is_a?(Integer) && index >= 0 && args.size > index

        args[index]
      end

      # Check if the current builder needs inline processing in code blocks
      def builder_needs_inline_processing?
        # Always process inline elements to generate unified AST structure
        # Individual builders will decide how to interpret them
        true
      end

      # Create a table row node from a line containing tab-separated cells
      # The is_header parameter determines if all cells should be header cells
      # The first_cell_header parameter determines if only the first cell should be a header
      def create_table_row_from_line(line, is_header: false, first_cell_header: false, block_location: nil)
        row_node = create_node(AST::TableRowNode)

        # Split by tab to get cells
        cells = line.split("\t")
        if cells.empty?
          error_location = block_location || @ast_compiler.location
          raise CompileError, "Invalid table row: empty line or no tab-separated cells#{format_location_info(error_location)}"
        end

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
          # Convert prefix "." to empty content for separator disambiguation
          # Preserve all other content including spaces
          processed_content = cell_content.sub(/\A\./, '')
          @ast_compiler.inline_processor.parse_inline_elements(processed_content, cell_node)

          row_node.add_child(cell_node)
        end

        row_node
      end

      # Parse raw content for builder specification
      def parse_raw_content(content)
        return [nil, content] if content.nil? || content.empty?

        # Check for builder specification: |builder1,builder2|content
        if matched = content.match(/\A\|(.*?)\|(.*)/)
          builders = matched[1].split(',').map { |i| i.gsub(/\s/, '') }
          processed_content = matched[2]
          [builders, processed_content]
        else
          # No builder specification - target all builders
          [nil, content]
        end
      end

      # Configuration for different code block types
      CODE_BLOCK_CONFIGS = {
        list: { id_index: 0, caption_index: 1, lang_index: 2 },
        listnum: { id_index: 0, caption_index: 1, lang_index: 2, line_numbers: true },
        emlist: { caption_index: 0, lang_index: 1 },
        emlistnum: { caption_index: 0, lang_index: 1, line_numbers: true },
        cmd: { caption_index: 0, default_lang: 'shell' },
        source: { caption_index: 0, lang_index: 1 }
      }.freeze

      # Block command to handler method mapping table
      # This table-driven approach makes it easy to add new block types
      # and provides a clear overview of all supported commands
      BLOCK_COMMAND_TABLE = {
        # Code blocks
        list: :build_code_block_ast,
        listnum: :build_code_block_ast,
        emlist: :build_code_block_ast,
        emlistnum: :build_code_block_ast,
        cmd: :build_code_block_ast,
        source: :build_code_block_ast,

        # Media blocks
        image: :build_image_ast,
        indepimage: :build_image_ast,
        numberlessimage: :build_image_ast,

        # Table blocks
        table: :build_table_ast,
        emtable: :build_table_ast,
        imgtable: :build_table_ast,

        # Simple list blocks (//ul, //ol, //dl commands)
        ul: :build_simple_list_ast,
        ol: :build_simple_list_ast,
        dl: :build_simple_list_ast,

        # Minicolumn blocks
        note: :build_minicolumn_ast,
        memo: :build_minicolumn_ast,
        tip: :build_minicolumn_ast,
        info: :build_minicolumn_ast,
        warning: :build_minicolumn_ast,
        important: :build_minicolumn_ast,
        caution: :build_minicolumn_ast,
        notice: :build_minicolumn_ast,

        # Reference blocks
        footnote: :build_footnote_ast,
        endnote: :build_footnote_ast,

        # Embed blocks
        embed: :build_embed_ast,
        raw: :build_raw_ast,

        # Quote and content blocks
        read: :build_quote_block_ast,
        quote: :build_quote_block_ast,
        blockquote: :build_quote_block_ast,
        lead: :build_quote_block_ast,
        centering: :build_quote_block_ast,
        flushright: :build_quote_block_ast,
        address: :build_quote_block_ast,
        talk: :build_quote_block_ast,

        # Complex blocks
        doorquote: :build_complex_block_ast,
        bibpaper: :build_complex_block_ast,
        graph: :build_complex_block_ast,
        box: :build_complex_block_ast,

        # Control commands
        comment: :build_control_command_ast,
        olnum: :build_control_command_ast,
        blankline: :build_control_command_ast,
        noindent: :build_control_command_ast,
        pagebreak: :build_control_command_ast,
        firstlinenum: :build_control_command_ast,
        tsize: :build_control_command_ast,
        label: :build_control_command_ast,
        printendnotes: :build_control_command_ast,
        hr: :build_control_command_ast,
        bpo: :build_control_command_ast,
        parasep: :build_control_command_ast,
        beginchild: :build_control_command_ast,
        endchild: :build_control_command_ast,

        # Math blocks
        texequation: :build_tex_equation_ast
      }.freeze
    end
  end
end
