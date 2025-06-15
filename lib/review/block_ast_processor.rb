# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/ast'

module ReVIEW
  # BlockASTProcessor - Block command processing and AST building
  #
  # This class handles the conversion of Re:VIEW block commands to AST nodes,
  # including code blocks, images, tables, lists, quotes, and minicolumns.
  #
  # Responsibilities:
  # - Process block commands (//list, //image, //table, etc.)
  # - Build appropriate AST nodes for block elements
  # - Handle block-specific parsing (table structure, list items, etc.)
  # - Coordinate with inline processor for content within blocks
  class BlockASTProcessor
    def initialize(ast_compiler)
      @ast_compiler = ast_compiler
    end

    def compile_code_block_to_ast(type, args, lines)
      case type
      when :list, :listnum
        node = AST::CodeBlockNode.new(
          location: @ast_compiler.location,
          id: args[0],
          caption: args[1],
          lang: args[2],
          lines: lines || [],
          line_numbers: (type == :listnum)
        )
      when :emlist, :emlistnum
        node = AST::CodeBlockNode.new(
          location: @ast_compiler.location,
          caption: args[0],
          lang: args[1],
          lines: lines || [],
          line_numbers: (type == :emlistnum)
        )
      when :cmd
        node = AST::CodeBlockNode.new(
          location: @ast_compiler.location,
          caption: args[0],
          lang: 'shell',
          lines: lines || [],
          line_numbers: false
        )
      when :source
        node = AST::CodeBlockNode.new(
          location: @ast_compiler.location,
          caption: args[0],
          lang: args[1],
          lines: lines || [],
          line_numbers: false
        )
      end
      @ast_compiler.add_child_to_current_node(node)
    end

    def compile_image_to_ast(_type, args)
      node = AST::ImageNode.new(
        location: @ast_compiler.location,
        id: args[0],
        caption: args[1],
        metric: args[2]
      )

      @ast_compiler.add_child_to_current_node(node)
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
               AST::TableNode.new(
                 location: @ast_compiler.location,
                 id: args[0],
                 caption: args[1],
                 headers: headers,
                 rows: rows,
                 table_type: :table
               )
             when :emtable
               AST::TableNode.new(
                 location: @ast_compiler.location,
                 id: nil, # emtable has no ID
                 caption: args[0],
                 headers: headers,
                 rows: rows,
                 table_type: :emtable
               )
             when :imgtable
               AST::TableNode.new(
                 location: @ast_compiler.location,
                 id: args[0],
                 caption: args[1],
                 headers: headers,
                 rows: rows,
                 table_type: :imgtable,
                 metric: args[2]
               )
             else
               # Fallback for unknown table types
               AST::TableNode.new(
                 location: @ast_compiler.location,
                 id: args[0],
                 caption: args[1],
                 headers: headers,
                 rows: rows,
                 table_type: type
               )
             end

      @ast_compiler.add_child_to_current_node(node)
    end

    def compile_list_to_ast(type, lines)
      # Create list items
      items = []
      if lines
        lines.each do |line|
          item_node = AST::ListItemNode.new(
            location: @ast_compiler.location,
            content: line,
            level: 1
          )
          items << item_node
        end
      end

      node = AST::ListNode.new(
        location: @ast_compiler.location,
        list_type: type,
        items: items
      )

      @ast_compiler.add_child_to_current_node(node)
    end

    def compile_quote_to_ast(lines)
      node = AST::ParagraphNode.new(location: @ast_compiler.location)
      if lines
        lines.each { |line| @ast_compiler.inline_processor.parse_inline_elements(line, node) }
      end

      @ast_compiler.add_child_to_current_node(node)
    end

    def compile_minicolumn_to_ast(type, args, lines)
      # For now, create a simple container node
      # This could be extended to a specific MinicolumnNode type
      node = AST::Node.new(
        location: @ast_compiler.location,
        type: 'minicolumn',
        id: type.to_s,
        content: args && args[0] ? args[0] : nil
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

    def compile_read_to_ast(lines)
      # Create a generic node for read blocks
      node = AST::Node.new(
        location: @ast_compiler.location,
        type: 'read',
        content: (lines || []).join("\n")
      )

      # Process each line as text content
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
        # Fallback - create generic node
        generic_node = AST::Node.new(
          location: @ast_compiler.location,
          type: command_name.to_s
        )
        @ast_compiler.add_child_to_current_node(generic_node)
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

      # Render immediately in hybrid mode
      @ast_compiler.render_with_ast_renderer(:visit_embed, node)
    end

    # Build list/listnum AST node
    def build_list_ast(command_name, args, lines)
      node = AST::CodeBlockNode.new(
        location: @ast_compiler.location,
        id: args&.any? ? args[0] : nil,
        caption: args && args.size > 1 ? args[1] : nil,
        lang: args && args.size > 2 ? args[2] : nil,
        lines: lines || [],
        line_numbers: (command_name == :listnum)
      )
      @ast_compiler.add_child_to_current_node(node)

      # Render immediately in hybrid mode
      @ast_compiler.render_with_ast_renderer(:visit_code_block, node)
    end

    # Build emlist/emlistnum AST node
    def build_emlist_ast(command_name, args, lines)
      node = AST::CodeBlockNode.new(
        location: @ast_compiler.location,
        caption: args&.any? ? args[0] : nil,
        lang: args && args.size > 1 ? args[1] : nil,
        lines: lines || [],
        line_numbers: (command_name == :emlistnum)
      )
      @ast_compiler.add_child_to_current_node(node)

      # Render immediately in hybrid mode
      @ast_compiler.render_with_ast_renderer(:visit_code_block, node)
    end

    # Build source AST node
    def build_source_ast(args, lines)
      node = AST::CodeBlockNode.new(
        location: @ast_compiler.location,
        caption: args&.any? ? args[0] : nil,
        lang: args && args.size > 1 ? args[1] : nil,
        lines: lines || []
      )
      @ast_compiler.add_child_to_current_node(node)

      # Render immediately in hybrid mode
      @ast_compiler.render_with_ast_renderer(:visit_code_block, node)
    end

    # Build cmd AST node
    def build_cmd_ast(args, lines)
      node = AST::CodeBlockNode.new(
        location: @ast_compiler.location,
        caption: args&.any? ? args[0] : nil,
        lang: 'shell',
        lines: lines || []
      )
      @ast_compiler.add_child_to_current_node(node)

      # Render immediately in hybrid mode
      @ast_compiler.render_with_ast_renderer(:visit_code_block, node)
    end

    # Build table AST node
    def build_table_ast(_command_name, args, lines)
      # Parse table content
      headers = []
      rows = []
      if lines && lines.any?
        separator_index = lines.find_index { |line| line.match?(/^[-=]{12,}$/) }
        if separator_index
          headers = lines[0...separator_index]
          rows = lines[(separator_index + 1)..-1] || []
        else
          rows = lines
        end
      end

      node = AST::TableNode.new(
        location: @ast_compiler.location,
        id: args&.any? ? args[0] : nil,
        caption: args && args.size > 1 ? args[1] : nil,
        headers: headers,
        rows: rows
      )

      @ast_compiler.add_child_to_current_node(node)

      # Render immediately in hybrid mode
      @ast_compiler.render_with_ast_renderer(:visit_table, node)
    end

    # Build image AST node
    def build_image_ast(_command_name, args, _lines)
      node = AST::ImageNode.new(
        location: @ast_compiler.location,
        id: args&.any? ? args[0] : nil,
        caption: args && args.size > 1 ? args[1] : nil,
        metric: args && args.size > 2 ? args[2] : nil
      )
      @ast_compiler.add_child_to_current_node(node)

      # Render immediately in hybrid mode
      @ast_compiler.render_with_ast_renderer(:visit_image, node)
    end

    # Build quote AST node
    def build_quote_ast(command_name, _args, lines)
      node = AST::ParagraphNode.new(location: @ast_compiler.location)

      # Parse inline elements in quote content
      (lines || []).each do |line|
        @ast_compiler.inline_processor.parse_inline_elements(line, node)
      end

      @ast_compiler.add_child_to_current_node(node)

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
      node = AST::EmbedNode.new(
        location: @ast_compiler.location,
        embed_type: :raw,
        lines: lines || [],
        arg: args&.any? ? args.first : nil
      )
      @ast_compiler.add_child_to_current_node(node)

      # Render immediately in hybrid mode
      if @ast_compiler.ast_renderer && args&.any?
        @ast_compiler.builder.raw(args.first)
      end
    end

    # Build unordered list AST node
    def build_ulist_ast(f)
      node = AST::ListNode.new(
        location: @ast_compiler.location,
        list_type: :ul
      )

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

        item_node = AST::ListItemNode.new(
          location: @ast_compiler.location,
          level: current_level
        )

        # Parse inline elements in item content
        raw_lines.each do |raw_line|
          @ast_compiler.inline_processor.parse_inline_elements(raw_line, item_node)
        end

        node.children << item_node
        level = current_level
      end

      @ast_compiler.add_child_to_current_node(node)

      # Render immediately in hybrid mode
      @ast_compiler.render_with_ast_renderer(:visit_list, node)
    end

    # Build ordered list AST node
    def build_olist_ast(f)
      node = AST::ListNode.new(
        location: @ast_compiler.location,
        list_type: :ol
      )

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

      # Render immediately in hybrid mode
      @ast_compiler.render_with_ast_renderer(:visit_list, node)
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

      # Render immediately in hybrid mode
      @ast_compiler.render_with_ast_renderer(:visit_list, node)
    end
  end
end
