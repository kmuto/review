# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/ast'

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
      end

      def compile_code_block_to_ast(type, args, lines)
        create_code_block_node(type, args, lines)
      end

      def compile_image_to_ast(_type, args)
        create_and_add_node(AST::ImageNode,
                            id: args[0],
                            caption: process_caption(args, 1),
                            metric: args[2])
      end

      def compile_table_to_ast(type, args, lines)
        # Parse table data
        headers = []
        rows = []
        if lines
          # Simple table parsing for AST mode
          separator_index = lines.find_index { |line| line.match?(/^[-=]{12,}$/) }
          if separator_index
            headers = lines[0...separator_index]
            rows = lines[(separator_index + 1)..-1] || []
          else
            headers = []
            rows = lines
          end
        end

        node = case type
               when :table
                 create_node(AST::TableNode,
                             id: args[0],
                             caption: process_caption(args, 1),
                             headers: headers,
                             rows: rows,
                             table_type: :table)
               when :emtable
                 create_node(AST::TableNode,
                             id: nil, # emtable has no ID
                             caption: process_caption(args, 0),
                             headers: headers,
                             rows: rows,
                             table_type: :emtable)
               when :imgtable
                 create_node(AST::TableNode,
                             id: args[0],
                             caption: process_caption(args, 1),
                             headers: headers,
                             rows: rows,
                             table_type: :imgtable,
                             metric: args[2])
               else
                 # Fallback for unknown table types
                 create_node(AST::TableNode,
                             id: args[0],
                             caption: process_caption(args, 1),
                             headers: headers,
                             rows: rows,
                             table_type: type)
               end

        add_node_to_ast(node)
      end

      def compile_list_to_ast(type, lines)
        # Create list node and add items as children
        list_node = create_and_add_node(AST::ListNode, list_type: type)

        if lines
          lines.each do |line|
            item_node = create_node(AST::ListItemNode,
                                    content: line,
                                    level: 1)
            list_node.add_child(item_node)
          end
        end

        list_node
      end

      def compile_block_to_ast(lines, block_type)
        # Create a BlockNode for quote blocks
        node = AST::BlockNode.new(
          location: @ast_compiler.location,
          block_type: block_type
        )

        if lines
          lines.each { |line| @ast_compiler.inline_processor.parse_inline_elements(line, node) }
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

        if lines
          lines.each do |line|
            text_node = AST::TextNode.new(
              location: @ast_compiler.location,
              content: line
            )
            node.add_child(text_node)
          end
        end

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

      # Build block command AST node (e.g., embed, list, table, etc.)
      def build_block_command_ast(command_name, args, lines)
        case command_name
        when :embed
          build_embed_ast(args, lines)
        when :list, :listnum
          build_list_ast(command_name, args, lines)
        when :emlist, :emlistnum
          build_emlist_ast(command_name, args, lines)
        when :source
          build_source_ast(args, lines)
        when :cmd
          build_cmd_ast(args, lines)
        when :table, :emtable, :imgtable
          build_table_ast(command_name, args, lines)
        when :image, :indepimage, :numberlessimage
          build_image_ast(command_name, args, lines)
        when :quote, :blockquote
          build_quote_ast(command_name, args, lines)
        when :note, :memo, :tip, :info, :warning, :important, :caution, :notice
          build_minicolumn_ast(command_name, args, lines)
        when :footnote, :endnote
          build_footnote_ast(command_name, args, lines)
        when :raw
          build_raw_ast(args, lines)
        else
          # Unknown block command - raise error instead of creating generic node
          raise CompileError, "Unknown block command: //#{command_name}"
        end
      end

      # Build embed AST node
      def build_embed_ast(args, lines)
        node = AST::EmbedNode.new(
          location: @ast_compiler.location,
          embed_type: :block,
          lines: lines || [],
          arg: args&.any? ? args.first : nil
        )
        @ast_compiler.add_child_to_current_node(node)
      end

      # Build list/listnum AST node
      def build_list_ast(command_name, args, lines)
        create_code_block_node(command_name, args, lines)
      end

      # Build emlist/emlistnum AST node
      def build_emlist_ast(command_name, args, lines)
        create_code_block_node(command_name, args, lines)
      end

      # Build source AST node
      def build_source_ast(args, lines)
        create_code_block_node(:source, args, lines)
      end

      # Build cmd AST node
      def build_cmd_ast(args, lines)
        create_code_block_node(:cmd, args, lines)
      end

      # Build table AST node
      def build_table_ast(_command_name, args, lines)
        # Parse table content
        headers = []
        rows = []
        if lines&.any?
          separator_index = lines.find_index { |line| line.match?(/^[-=]{12,}$/) }
          if separator_index
            headers = lines[0...separator_index]
            rows = lines[(separator_index + 1)..-1] || []
          else
            rows = lines
          end
        end

        create_and_add_node(AST::TableNode,
                            id: safe_arg(args, 0),
                            caption: process_caption(args, 1),
                            headers: headers,
                            rows: rows)
      end

      # Build image AST node
      def build_image_ast(_command_name, args, _lines)
        create_and_add_node(AST::ImageNode,
                            id: safe_arg(args, 0),
                            caption: process_caption(args, 1),
                            metric: safe_arg(args, 2))
      end

      # Build quote AST node
      def build_quote_ast(command_name, _args, lines)
        node = create_node(AST::ParagraphNode)

        # Parse inline elements in quote content
        (lines || []).each do |line|
          @ast_compiler.inline_processor.parse_inline_elements(line, node)
        end

        add_node_to_ast(node)

        # Render immediately in hybrid mode - use quote-specific method
        if @ast_compiler.ast_renderer
          if command_name == :blockquote
            @ast_compiler.builder.blockquote(lines || [])
          else
            @ast_compiler.builder.quote(lines || [])
          end
        end
      end

      # Build minicolumn AST node (note, memo, tip, etc.)
      def build_minicolumn_ast(command_name, args, lines)
        node = AST::ParagraphNode.new(
          location: @ast_compiler.location
        )
        # NOTE: content is set separately as ParagraphNode doesn't accept content in constructor
        node.content = "#{command_name}: #{args.first || ''}"

        # Parse inline elements in minicolumn content
        (lines || []).each do |line|
          @ast_compiler.inline_processor.parse_inline_elements(line, node)
        end

        @ast_compiler.add_child_to_current_node(node)

        # Render immediately in hybrid mode - use minicolumn-specific method
        if @ast_compiler.ast_renderer
          @ast_compiler.builder.__send__("#{command_name}_begin", args.first)
          (lines || []).each do |line|
            # Process inline elements in line for proper rendering
            # This would need access to the text method from compiler
            @ast_compiler.builder.paragraph([line])
          end
          @ast_compiler.builder.__send__("#{command_name}_end")
        end
      end

      # Build footnote AST node
      def build_footnote_ast(command_name, args, _lines)
        # Footnotes are single-line commands, not block commands
        # Handle them as inline processing would
        if @ast_compiler.ast_renderer
          @ast_compiler.builder.__send__(command_name, *args)
        end
      end

      # Build raw AST node
      def build_raw_ast(args, lines)
        node = create_and_add_node(AST::EmbedNode,
                                   embed_type: :raw,
                                   lines: lines || [],
                                   arg: safe_arg(args, 0))
        # Render immediately in hybrid mode
        if @ast_compiler.ast_renderer && args&.any?
          @ast_compiler.builder.raw(args.first)
        end
      end

      # Build unordered list AST node
      def build_ulist_ast(f)
        node = create_node(AST::ListNode,
                           list_type: :ul)

        level = 0
        f.while_match(/\A\s+\*|\A\#@/) do |line|
          next if /\A\#@/.match?(line)

          # Collect raw lines without processing inline elements for AST
          raw_lines = [line.sub(/\*+/, '').strip]
          f.while_match(/\A\s+(?!\*)\S/) do |cont|
            raw_lines.push(cont.strip)
          end

          line =~ /\A\s+(\*+)/
          current_level = $1.size

          item_node = create_node(AST::ListItemNode,
                                  level: current_level)

          # Parse inline elements in item content
          raw_lines.each do |raw_line|
            @ast_compiler.inline_processor.parse_inline_elements(raw_line, item_node)
          end

          node.children << item_node
          level = current_level
        end

        add_node_to_ast(node)
      end

      # Build ordered list AST node
      def build_olist_ast(f)
        node = create_node(AST::ListNode,
                           list_type: :ol)

        f.while_match(/\A\s+\d+\.|\A\#@/) do |line|
          next if /\A\#@/.match?(line)

          num = line.match(/(\d+)\./)[1]
          raw_lines = [line.sub(/\d+\./, '').strip]
          f.while_match(/\A\s+(?!\d+\.)\S/) do |cont|
            raw_lines.push(cont.strip)
          end

          item_node = AST::ListItemNode.new(
            location: @ast_compiler.location,
            level: 1,
            content: num # Store original number for reference
          )

          # Parse inline elements in item content
          raw_lines.each do |raw_line|
            @ast_compiler.inline_processor.parse_inline_elements(raw_line, item_node)
          end

          node.children << item_node
        end

        @ast_compiler.add_child_to_current_node(node)
      end

      # Build definition list AST node
      def build_dlist_ast(f)
        node = AST::ListNode.new(
          location: @ast_compiler.location,
          list_type: :dl
        )

        while /\A\s*:/ =~ f.peek
          # Get definition term
          dt_line = f.gets.sub(/\A\s*:/, '').strip
          dt_node = AST::ListItemNode.new(
            location: @ast_compiler.location,
            level: 1
          )
          @ast_compiler.inline_processor.parse_inline_elements(dt_line, dt_node)

          # Get definition description
          desc_lines = []
          f.until_match(/\A(\S|\s*:|\s+\d+\.\s|\s+\*\s)/) do |line|
            desc_lines << line.strip
          end

          # Create a container node for the dt/dd pair
          item_node = AST::ListItemNode.new(
            location: @ast_compiler.location,
            level: 1
          )

          # Add dt as first child
          item_node.add_child(dt_node)

          # Add dd content as additional children
          desc_lines.each do |desc_line|
            @ast_compiler.inline_processor.parse_inline_elements(desc_line, item_node)
          end

          node.children << item_node
          f.skip_blank_lines
          f.skip_comment_lines
        end

        @ast_compiler.add_child_to_current_node(node)
      end

      private

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
        raise ArgumentError, "Unknown code block type: #{command_type}" unless config

        # Preserve original text
        original_text = lines ? lines.join("\n") : ''

        # Process lines for inline elements if needed
        processed_lines = nil
        if builder_needs_inline_processing? && lines
          processed_lines = lines.map do |line|
            paragraph_node = AST::ParagraphNode.new(location: @ast_compiler.location)
            @ast_compiler.inline_processor.parse_inline_elements(line, paragraph_node)
            paragraph_node
          end
        end

        create_and_add_node(AST::CodeBlockNode,
                            id: safe_arg(args, config[:id_index]),
                            caption: process_caption(args, config[:caption_index]),
                            lang: safe_arg(args, config[:lang_index]) || config[:default_lang],
                            lines: lines || [],
                            line_numbers: config[:line_numbers] || false,
                            code_type: command_type,
                            original_text: original_text,
                            processed_lines: processed_lines)
      end

      def process_caption(args, caption_index)
        caption_text = safe_arg(args, caption_index)
        return nil if caption_text.nil?

        AST::CaptionNode.parse(
          caption_text,
          location: @ast_compiler.location,
          inline_processor: @ast_compiler.inline_processor
        )
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

      # Configuration for different code block types
      CODE_BLOCK_CONFIGS = {
        list: { id_index: 0, caption_index: 1, lang_index: 2 },
        listnum: { id_index: 0, caption_index: 1, lang_index: 2, line_numbers: true },
        emlist: { caption_index: 0, lang_index: 1 },
        emlistnum: { caption_index: 0, lang_index: 1, line_numbers: true },
        cmd: { caption_index: 0, default_lang: 'shell' },
        source: { caption_index: 0, lang_index: 1 }
      }.freeze
    end
  end
end
