# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/renderer/base'
require 'review/htmlutils'
require 'review/textutils'
require 'review/loggable'

module ReVIEW
  module Renderer
    class MarkdownRenderer < Base
      include ReVIEW::HTMLUtils
      include ReVIEW::TextUtils
      include ReVIEW::Loggable

      def initialize(chapter)
        super
        @blank_seen = true
        @ul_indent = 0
        @noindent = nil
        @table_rows = []
        @table_header_count = 0
        @rendering_context = nil
      end

      def target_name
        'markdown'
      end

      def visit_document(node)
        render_children(node)
      end

      def visit_headline(node)
        level = node.level
        caption = render_caption_inline(node.caption_node)

        # Use Markdown # syntax
        prefix = '#' * level
        "#{prefix} #{caption}\n\n"
      end

      def visit_paragraph(node)
        content = render_children(node)
        return '' if content.empty?

        lines = content.split("\n")
        result = lines.join(' ')

        # Handle noindent directive
        if @noindent
          @noindent = nil
        end
        "#{result}\n\n"
      end

      def visit_list(node)
        result = +''

        case node.list_type
        when :ul
          node.children.each do |item|
            result += visit_list_item(item, :ul)
          end
        when :ol
          node.children.each_with_index do |item, index|
            result += visit_list_item(item, :ol, index + 1)
          end
        when :dl
          result += "<dl>\n"
          node.children.each do |item|
            result += visit_definition_item(item)
          end
          result += "</dl>\n\n"
        else
          raise NotImplementedError, "MarkdownRenderer does not support list_type #{node.list_type}."
        end

        result + "\n"
      end

      def visit_list_item(node, type = :ul, number = nil)
        # Separate text content from nested lists
        text_content = +''
        nested_lists = +''

        node.children.each do |child|
          if child.class.name.include?('ListNode')
            # This is a nested list - render it separately
            nested_lists += visit(child)
          else
            # This is regular content
            text_content += visit(child)
          end
        end

        text_content = text_content.chomp

        # Use the level attribute from the node for proper indentation
        level = node.level || 1

        result = case type
                 when :ul
                   # Calculate indent based on level (0-based indentation: level 1 = 0 spaces, level 2 = 2 spaces, etc.)
                   indent = '  ' * (level - 1)
                   "#{indent}* #{text_content}\n"
                 when :ol
                   # For ordered lists, also apply indentation based on level
                   indent = '  ' * (level - 1)
                   "#{indent}#{number}. #{text_content}\n"
                 end

        # Add any nested lists after the item
        result += nested_lists
        result
      end

      def visit_item(node)
        # Handle list items that come directly without parent list context
        content = render_children(node).chomp
        "* #{content}\n"
      end

      def visit_definition_item(node)
        # Handle definition term - use term_children (AST structure)
        term = if node.term_children && !node.term_children.empty?
                 # Render term children (which contain inline elements)
                 node.term_children.map { |child| visit(child) }.join
               else
                 '' # No term available
               end

        # Handle definition content (all children are definition content)
        definition_parts = node.children.map do |child|
          visit(child) # Use visit instead of render_children for individual nodes
        end
        definition = definition_parts.join(' ').strip

        "<dt>#{term}</dt>\n<dd>#{definition}</dd>\n"
      end

      def visit_code_block(node)
        result = ''
        lang = node.lang || ''

        # Add caption if present
        caption = render_caption_inline(node.caption_node)
        result += "**#{caption}**\n\n" unless caption.empty?

        # Generate fenced code block
        result += "```#{lang}\n"

        # Handle line numbers if needed
        if node.line_numbers
          code_content = render_children(node).chomp
          lines = code_content.split("\n")
          first_line_number = (node.respond_to?(:first_line_number) && node.first_line_number) || 1

          lines.each_with_index do |line, i|
            line_num = (first_line_number + i).to_s.rjust(3)
            result += "#{line_num}: #{line}\n"
          end
        else
          code_content = render_children(node)
          # Remove trailing newline if present to avoid double newlines
          code_content = code_content.chomp if code_content.end_with?("\n")
          result += code_content
          result += "\n"
        end

        result += "```\n\n"

        result
      end

      def visit_code_line(node)
        render_children(node) + "\n"
      end

      def visit_table(node)
        @table_rows = []
        @table_header_count = 0

        # Add caption if present
        result = +''
        caption = render_caption_inline(node.caption_node)
        result += "**#{caption}**\n\n" unless caption.empty?

        # Process table content
        render_children(node)

        # Generate markdown table
        if @table_rows.any?
          result += generate_markdown_table
        end

        result += "\n"
        result
      end

      def visit_table_row(node)
        cells = []
        node.children.each do |cell|
          cell_content = render_children(cell).gsub('|', '\\|')
          # Skip separator rows (rows that contain only dashes)
          unless /^-+$/.match?(cell_content.strip)
            cells << cell_content
          end
        end

        # Only add non-empty rows
        if cells.any? { |cell| !cell.strip.empty? }
          @table_rows << cells
          @table_header_count = [@table_header_count, cells.length].max if @table_rows.length == 1
        end
        ''
      end

      def visit_table_cell(node)
        render_children(node)
      end

      def visit_image(node)
        image_path = node.image_path || node.id
        caption = render_caption_inline(node.caption_node)

        # Remove ./ prefix if present
        image_path = image_path.sub(%r{\A\./}, '')

        if caption.empty?
          "![](#{image_path})\n\n"
        else
          "![#{caption}](#{image_path})\n\n"
        end
      end

      def visit_minicolumn(node)
        result = +''

        # Use HTML div for minicolumns as Markdown doesn't have native support
        css_class = node.minicolumn_type.to_s

        result += %Q(<div class="#{css_class}">\n\n)

        caption = render_caption_inline(node.caption_node)
        result += "**#{caption}**\n\n" unless caption.empty?

        result += render_children(node)
        result += "\n</div>\n\n"

        result
      end

      def visit_block(node)
        case node.block_type.to_sym
        when :quote
          visit_quote_block(node)
        when :captionblock
          visit_caption_block(node)
        else
          visit_generic_block(node)
        end
      end

      def visit_quote_block(node)
        content = render_children(node).chomp
        lines = content.split("\n")
        quoted_lines = lines.map { |line| "> #{line}" }
        "#{quoted_lines.join("\n")}\n\n"
      end

      def visit_caption_block(node)
        # Use HTML div for caption blocks
        result = %Q(<div class="captionblock">\n\n)
        result += render_children(node)
        result += "\n</div>\n\n"
        result
      end

      def visit_generic_block(node)
        # Use HTML div for generic blocks
        css_class = node.block_type.to_s
        result = %Q(<div class="#{css_class}">\n\n)
        result += render_children(node)
        result += "\n</div>\n\n"
        result
      end

      def visit_inline(node)
        type = node.inline_type
        content = render_children(node)

        # Call inline rendering methods directly
        method_name = "render_inline_#{type}"
        if respond_to?(method_name, true)
          send(method_name, type, content, node)
        else
          # Fallback for unknown elements
          content
        end
      end

      def render_caption_inline(caption_node)
        caption_node ? render_children(caption_node) : ''
      end

      def visit_footnote(node)
        footnote_id = node.id
        content = render_children(node)

        "[^#{footnote_id}]: #{content}\n\n"
      end

      def visit_text(node)
        node.content || ''
      end

      def visit_reference(node)
        node.content || ''
      end

      def render_inline_b(_type, content, _node)
        "**#{escape_asterisks(content)}**"
      end

      def render_inline_strong(_type, content, _node)
        "**#{escape_asterisks(content)}**"
      end

      def render_inline_i(_type, content, _node)
        "*#{escape_asterisks(content)}*"
      end

      def render_inline_em(_type, content, _node)
        "*#{escape_asterisks(content)}*"
      end

      def render_inline_code(_type, content, _node)
        "`#{content}`"
      end

      def render_inline_tt(_type, content, _node)
        "`#{content}`"
      end

      def render_inline_kbd(_type, content, _node)
        "`#{content}`"
      end

      def render_inline_samp(_type, content, _node)
        "`#{content}`"
      end

      def render_inline_var(_type, content, _node)
        "*#{escape_asterisks(content)}*"
      end

      def render_inline_sup(_type, content, _node)
        "<sup>#{escape_content(content)}</sup>"
      end

      def render_inline_sub(_type, content, _node)
        "<sub>#{escape_content(content)}</sub>"
      end

      def render_inline_del(_type, content, _node)
        "~~#{content}~~"
      end

      def render_inline_ins(_type, content, _node)
        "<ins>#{escape_content(content)}</ins>"
      end

      def render_inline_u(_type, content, _node)
        "<u>#{escape_content(content)}</u>"
      end

      def render_inline_br(_type, _content, _node)
        "\n"
      end

      def render_inline_raw(_type, content, node)
        if node.args.first
          format = node.args.first
          if format == 'markdown'
            content
          else
            '' # Ignore raw content for other formats
          end
        else
          content
        end
      end

      def render_inline_chap(_type, content, _node)
        escape_content(content)
      end

      def render_inline_title(_type, content, _node)
        "**#{escape_asterisks(content)}**"
      end

      def render_inline_chapref(_type, content, _node)
        escape_content(content)
      end

      def render_inline_list(_type, content, _node)
        escape_content(content)
      end

      def render_inline_img(_type, content, node)
        if node.args.first
          image_id = node.args.first
          "![#{escape_content(content)}](##{image_id})"
        else
          "![#{escape_content(content)}](##{content})"
        end
      end

      def render_inline_icon(_type, content, node)
        if node.args.first
          image_path = node.args.first
          image_path = image_path.sub(%r{\A\./}, '')
          "![](#{image_path})"
        else
          "![](#{content})"
        end
      end

      def render_inline_table(_type, content, _node)
        escape_content(content)
      end

      def render_inline_fn(_type, content, node)
        if node.args.first
          fn_id = node.args.first
          "[^#{fn_id}]"
        else
          "[^#{content}]"
        end
      end

      def render_inline_kw(_type, content, node)
        if node.args.length >= 2
          word = node.args[0]
          alt = node.args[1]
          "**#{escape_asterisks(word)}** (#{escape_content(alt)})"
        else
          "**#{escape_asterisks(content)}**"
        end
      end

      def render_inline_bou(_type, content, _node)
        "*#{escape_asterisks(content)}*"
      end

      def render_inline_ami(_type, content, _node)
        "*#{escape_asterisks(content)}*"
      end

      def render_inline_href(_type, content, node)
        args = node.args || []
        if args.length >= 2
          url = args[0]
          text = args[1]
          "[#{text}](#{url})"
        else
          "[#{content}](#{content})"
        end
      end

      def render_inline_ruby(_type, content, node)
        if node.args.length >= 2
          base = node.args[0]
          ruby = node.args[1]
          "<ruby>#{escape_content(base)}<rt>#{escape_content(ruby)}</rt></ruby>"
        else
          escape_content(content)
        end
      end

      def render_inline_m(_type, content, _node)
        "$$#{content}$$"
      end

      def render_inline_idx(_type, content, _node)
        escape_content(content)
      end

      def render_inline_hidx(_type, _content, _node)
        ''
      end

      def render_inline_comment(_type, content, _node)
        if @book&.config&.[]('draft')
          "<!-- #{escape_content(content)} -->"
        else
          ''
        end
      end

      def render_inline_hd(_type, content, _node)
        escape_content(content)
      end

      def render_inline_sec(_type, content, _node)
        escape_content(content)
      end

      def render_inline_secref(_type, content, _node)
        escape_content(content)
      end

      def render_inline_labelref(_type, content, _node)
        escape_content(content)
      end

      def render_inline_ref(_type, content, _node)
        escape_content(content)
      end

      def render_inline_pageref(_type, content, _node)
        escape_content(content)
      end

      def render_inline_w(_type, content, _node)
        # Dictionary lookup for word substitution
        dictionary = @book&.config&.[]('dictionary') || {}
        translated = dictionary[content]
        escape_content(translated || "[missing word: #{content}]")
      end

      def render_inline_wb(_type, content, _node)
        # Dictionary lookup with bold formatting
        dictionary = @book&.config&.[]('dictionary') || {}
        word_content = dictionary[content] || "[missing word: #{content}]"
        "**#{escape_asterisks(word_content)}**"
      end

      # Helper methods
      def escape_content(str)
        escape(str)
      end

      def escape_asterisks(str)
        str.gsub('*', '\\*')
      end

      private

      def generate_markdown_table
        return '' if @table_rows.empty?

        result = +''

        # Header row
        header = @table_rows.first
        result += "| #{header.join(' | ')} |\n"

        # Separator row
        separators = header.map { ':--' }
        result += "| #{separators.join(' | ')} |\n"

        # Data rows
        @table_rows[1..-1]&.each do |row|
          # Pad row to match header length
          padded_row = row + ([''] * (@table_header_count - row.length))
          result += "| #{padded_row.join(' | ')} |\n"
        end

        result
      end
    end
  end
end
