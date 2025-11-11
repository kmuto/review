# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/htmlutils'
require 'review/textutils'
require 'review/loggable'
require_relative 'base'

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
        # Render children with spacing between adjacent inline elements
        content = render_children_with_inline_spacing(node)
        return '' if content.empty?

        lines = content.split("\n")
        result = lines.join(' ')

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

      # Common code block rendering method used by all code block types
      def render_code_block_common(node)
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

      # Individual code block type visitors that delegate to common method
      def visit_code_block_list(node)
        render_code_block_common(node)
      end

      def visit_code_block_listnum(node)
        render_code_block_common(node)
      end

      def visit_code_block_emlist(node)
        render_code_block_common(node)
      end

      def visit_code_block_emlistnum(node)
        render_code_block_common(node)
      end

      def visit_code_block_cmd(node)
        render_code_block_common(node)
      end

      def visit_code_block_source(node)
        render_code_block_common(node)
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
        # Use node.id as the image path, get path from chapter if image is bound
        image_path = if @chapter&.image_bound?(node.id)
                       @chapter.image(node.id).path
                     else
                       node.id
                     end

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

      # visit_block is now handled by Base renderer with dynamic method dispatch

      def visit_block_quote(node)
        content = render_children(node).chomp
        lines = content.split("\n")
        quoted_lines = lines.map { |line| "> #{line}" }
        "#{quoted_lines.join("\n")}\n\n"
      end

      def visit_block_captionblock(node)
        # Use HTML div for caption blocks
        result = %Q(<div class="captionblock">\n\n)
        result += render_children(node)
        result += "\n</div>\n\n"
        result
      end

      def visit_embed(node)
        # Handle //raw and @<raw> commands with target builder specification
        if node.targeted_for?('markdown')
          content = node.content || ''
          # Convert \n to actual newlines
          content.gsub('\\n', "\n")
        else
          ''
        end
      end

      def visit_column(node)
        result = +''

        # Use HTML div for columns as Markdown doesn't have native support
        css_class = node.column_type.to_s

        result += %Q(<div class="#{css_class}">\n\n)

        caption = render_caption_inline(node.caption_node)
        result += "**#{caption}**\n\n" unless caption.empty?

        result += render_children(node)
        result += "\n</div>\n\n"

        result
      end

      def visit_block_lead(node)
        # Lead paragraphs - render as regular paragraphs in Markdown
        render_children(node) + "\n"
      end

      def visit_block_bibpaper(node)
        # Bibliography entries - render as list items
        result = +''

        # Get ID and caption
        bib_id = node.id || ''
        caption = render_caption_inline(node.caption_node)

        # Format as markdown list item with ID
        result += "* **[#{bib_id}]** #{caption}\n" unless caption.empty?

        # Add content if any
        content = render_children(node)
        result += "  #{content.gsub("\n", "\n  ")}\n" unless content.strip.empty?

        result + "\n"
      end

      def visit_block_blankline(node)
        # Blank line directive - render as double newline
        "\n\n"
      end

      def render_inline_element(type, content, node)
        method_name = "render_inline_#{type}"
        if respond_to?(method_name, true)
          send(method_name, type, content, node)
        else
          # Fallback for unknown inline elements: render as plain text
          # This allows graceful degradation for specialized elements
          ReVIEW.logger.warn("Unknown inline element: @<#{type}>{...} - rendering as plain text")
          content
        end
      end

      def render_caption_inline(caption_node)
        return '' unless caption_node

        # Use inline spacing for captions as well
        content = render_children_with_inline_spacing(caption_node)
        # Join lines like visit_paragraph does
        lines = content.split("\n")
        lines.join(' ')
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

      def render_inline_raw(_type, _content, node)
        node.targeted_for?('markdown') ? (node.content || '') : ''
      end

      def render_inline_embed(_type, _content, node)
        node.targeted_for?('markdown') ? (node.content || '') : ''
      end

      def render_inline_chap(_type, _content, node)
        ref_node = node.children.first
        unless ref_node.reference_node? && ref_node.resolved?
          raise 'BUG: Reference should be resolved at AST construction time'
        end

        data = ref_node.resolved_data
        chapter_num = text_formatter.format_chapter_number_full(data.chapter_number, data.chapter_type)
        escape_content(chapter_num.to_s)
      end

      def render_inline_title(_type, _content, node)
        ref_node = node.children.first
        unless ref_node.reference_node? && ref_node.resolved?
          raise 'BUG: Reference should be resolved at AST construction time'
        end

        data = ref_node.resolved_data
        title = data.chapter_title || ''
        "**#{escape_asterisks(title)}**"
      end

      def render_inline_chapref(_type, _content, node)
        ref_node = node.children.first
        unless ref_node.reference_node? && ref_node.resolved?
          raise 'BUG: Reference should be resolved at AST construction time'
        end

        data = ref_node.resolved_data
        display_str = text_formatter.format_reference(:chapter, data)
        escape_content(display_str)
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

      # Render children with spacing between adjacent inline elements
      # This prevents Markdown parsing issues when inline elements are adjacent
      #
      # Rules:
      # - Same type adjacent inlines are merged: @<b>{a}@<b>{b} → **ab**
      # - Different type adjacent inlines get space: @<b>{a}@<i>{b} → **a** *b*
      def render_children_with_inline_spacing(node)
        return '' if node.children.empty?

        # Group consecutive inline nodes of the same type
        groups = group_inline_nodes(node.children)

        result = +''
        prev_group_was_inline = false

        groups.each do |group|
          if group[:type] == :inline_group
            # Add space if previous group was also inline (but different type)
            result += ' ' if prev_group_was_inline

            # Merge same-type inline nodes and render together
            merged_content = group[:nodes].map { |n| render_children(n) }.join
            inline_type = group[:inline_type]

            # Render the merged content as a single inline element
            result += render_inline_element(inline_type, merged_content, group[:nodes].first)

            prev_group_was_inline = true
          else
            # Regular nodes (text, etc.) - just render normally
            group[:nodes].each do |n|
              result += visit(n)
            end
            prev_group_was_inline = false
          end
        end

        result
      end

      # Group consecutive inline nodes by type
      # Returns array of groups: [{type: :inline_group, inline_type: 'b', nodes: [...]}, ...]
      def group_inline_nodes(children)
        groups = []
        current_group = nil

        children.each do |child|
          if child.is_a?(ReVIEW::AST::InlineNode)
            inline_type = child.inline_type

            # Start new group if type changed or first inline
            if current_group.nil? || current_group[:type] != :inline_group || current_group[:inline_type] != inline_type
              # Save previous group if exists
              groups << current_group if current_group

              # Start new inline group
              current_group = {
                type: :inline_group,
                inline_type: inline_type,
                nodes: [child]
              }
            else
              # Add to current group (same type)
              current_group[:nodes] << child
            end
          else
            # Non-inline node
            # Save previous inline group if exists
            if current_group && current_group[:type] == :inline_group
              groups << current_group
              current_group = nil
            end

            # Start or continue regular node group
            if current_group.nil? || current_group[:type] != :regular
              groups << current_group if current_group
              current_group = { type: :regular, nodes: [child] }
            else
              current_group[:nodes] << child
            end
          end
        end

        # Don't forget the last group
        groups << current_group if current_group

        groups
      end

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
