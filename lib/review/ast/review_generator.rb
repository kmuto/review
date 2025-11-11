# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/ast'
require_relative 'visitor'

module ReVIEW
  module AST
    # ReVIEWGenerator - Generate Re:VIEW text from AST nodes
    class ReVIEWGenerator < Visitor
      # Generate Re:VIEW text from AST root node
      def generate(ast_root)
        visit(ast_root)
      end

      private

      # Visit all children of a node and concatenate results
      # Uses parent's visit_all method for consistency
      # @param node [AST::Node] The parent node
      # @return [String] Concatenated text from all children
      def visit_children(node)
        visit_all(node.children).join
      end

      # Escape special characters for Re:VIEW inline markup
      # Escapes backslashes and closing braces to prevent markup breaking
      # @param text [String] The text to escape
      # @return [String] Escaped text safe for Re:VIEW inline markup
      def escape_inline_content(text)
        text.to_s.gsub('\\', '\\\\\\\\').gsub('}', '\\}')
      end

      # Convert CaptionNode to Re:VIEW markup format
      # @param caption_node [CaptionNode, nil] The caption node to convert
      # @return [String] Re:VIEW markup string
      def caption_to_review_markup(caption_node)
        return '' if caption_node.nil? || caption_node.children.empty?

        caption_node.children.map { |child| render_node_as_review_markup(child) }.join
      end

      # Recursively render AST nodes as Re:VIEW markup text
      # This method is primarily used for rendering caption content where inline elements
      # need to be processed. For general node visiting, use the visit_* methods instead.
      # @param node [Node] The node to render
      # @return [String] Re:VIEW markup representation
      def render_node_as_review_markup(node)
        case node
        when ReVIEW::AST::TextNode
          node.content
        when ReVIEW::AST::InlineNode
          # Use the visit_inline_* methods for consistency
          visit(node)
        else
          node.leaf_node? ? node.content : ''
        end
      end

      def visit_document(node)
        visit_children(node)
      end

      def visit_headline(node)
        text = '=' * (node.level || 1)
        text += "{#{node.label}}" if node.label && !node.label.empty?

        caption_text = caption_to_review_markup(node.caption_node)
        text += ' ' + caption_text unless caption_text.empty?

        text + "\n\n" + visit_children(node)
      end

      def visit_paragraph(node)
        content = visit_children(node)
        return '' if content.strip.empty?

        content + "\n\n"
      end

      def visit_text(node)
        node.content || ''
      end

      def visit_reference(node)
        # ReferenceNode inherits from TextNode and has content
        # Simply output the content (which is the ref_id or resolved item_id)
        node.content || ''
      end

      def visit_footnote(node)
        # FootnoteNode represents a footnote definition
        # Format: //footnote[id][content]
        content = visit_children(node).strip
        footnote_type = node.footnote_type == :endnote ? 'endnote' : 'footnote'
        "//#{footnote_type}[#{node.id}][#{content}]\n\n"
      end

      def visit_tex_equation(node)
        # TexEquationNode represents LaTeX equation blocks
        # Format: //texequation[id][caption]{content//}
        text = '//texequation'
        text += "[#{node.id}]" if node.id?
        caption_text = caption_to_review_markup(node.caption_node)
        text += "[#{caption_text}]" unless caption_text.empty?
        text += "{\n"
        text += node.content || ''
        text += "\n" unless node.content&.end_with?("\n")
        text + "//}\n\n"
      end

      def visit_inline(node)
        # Use dynamic method dispatch for extensibility
        # To add a new inline type, define a method: visit_inline_<type>(node)
        method_name = "visit_inline_#{node.inline_type}"
        if respond_to?(method_name, true)
          send(method_name, node)
        else
          # Default implementation for unknown inline types
          visit_inline_default(node)
        end
      end

      # Default implementation for inline elements
      # Uses children content or first arg as fallback
      def visit_inline_default(node)
        content = visit_children(node)
        # Use args as fallback if children are empty
        if content.empty? && node.args.any?
          content = node.args.first.to_s
        end
        escaped_content = escape_inline_content(content)
        "@<#{node.inline_type}>{#{escaped_content}}"
      end

      # Inline element: @<kw>{word, description}
      def visit_inline_kw(node)
        if node.args.size >= 2
          word = escape_inline_content(node.args[0])
          desc = escape_inline_content(node.args[1])
          "@<kw>{#{word}, #{desc}}"
        elsif node.args.size == 1
          word = escape_inline_content(node.args[0])
          "@<kw>{#{word}}"
        else
          content = escape_inline_content(visit_children(node))
          "@<kw>{#{content}}"
        end
      end

      # Inline element: @<ruby>{base, ruby_text}
      def visit_inline_ruby(node)
        base = escape_inline_content(node.args[0])
        if node.args.size >= 2
          ruby_text = escape_inline_content(node.args[1])
          "@<ruby>{#{base}, #{ruby_text}}"
        else
          "@<ruby>{#{base}}"
        end
      end

      # Inline element: @<href>{url, text}
      def visit_inline_href(node)
        url = node.args[0] || ''
        content = visit_children(node)
        if content.empty?
          "@<href>{#{url}}"
        else
          escaped_content = escape_inline_content(content)
          "@<href>{#{url}, #{escaped_content}}"
        end
      end

      def visit_code_block(node)
        # Determine block type
        block_type = if node.id?
                       node.line_numbers ? 'listnum' : 'list'
                     else
                       node.line_numbers ? 'emlistnum' : 'emlist'
                     end

        # Build opening tag
        text = '//' + block_type
        text += "[#{node.id}]" if node.id?

        caption_text = caption_to_review_markup(node.caption_node)
        has_lang = node.lang && !node.lang.empty?
        has_caption = !caption_text.empty?

        # Handle caption and language parameters based on block type
        if block_type == 'list' || block_type == 'listnum'
          # list/listnum: //list[id][caption][lang]
          text += "[#{caption_text}]" if has_caption || has_lang
          text += "[#{node.lang}]" if has_lang
        elsif has_lang
          # emlist/emlistnum with lang: //emlist[caption][lang]
          # Caption parameter is required even when empty
          text += "[#{caption_text}]"
          text += "[#{node.lang}]"
        elsif has_caption
          # emlist/emlistnum with only caption: //emlist[caption]
          text += "[#{caption_text}]"
        end

        text += "{\n"

        # Add code lines from original_text or reconstruct from AST
        if node.original_text && !node.original_text.empty?
          text += node.original_text
        elsif node.children.any?
          # Reconstruct from AST structure
          lines = node.children.map do |line_node|
            if line_node.children
              line_node.children.map do |child|
                case child
                when ReVIEW::AST::TextNode
                  child.content
                when ReVIEW::AST::InlineNode
                  "@<#{child.inline_type}>{#{child.args.first || ''}}"
                else
                  child.to_s
                end
              end.join
            else
              line_node.to_s
            end
          end
          text += lines.join("\n")
        end
        text += "\n" unless text.end_with?("\n")

        text + "//}\n\n"
      end

      def visit_list(node)
        case node.list_type
        when :ul
          visit_unordered_list(node)
        when :ol
          visit_ordered_list(node)
        when :dl
          visit_definition_list(node)
        else
          visit_children(node)
        end
      end

      def visit_list_item(node)
        # This should be handled by parent list type
        visit_children(node)
      end

      def visit_table(node)
        table_type = node.table_type || :table
        text = build_table_header(node, table_type)
        text += build_table_body(node.header_rows, node.body_rows)
        text + "//}\n\n"
      end

      def visit_image(node)
        # Use image_type to determine the command (:image, :indepimage, :numberlessimage)
        image_command = node.image_type || :image
        text = "//#{image_command}[#{node.id || ''}]"

        caption_text = caption_to_review_markup(node.caption_node)
        text += "[#{caption_text}]" unless caption_text.empty?
        text += "[#{node.metric}]" if node.metric && !node.metric.empty?
        text + "\n\n"
      end

      def visit_minicolumn(node)
        text = "//#{node.minicolumn_type}"

        caption_text = caption_to_review_markup(node.caption_node)
        text += "[#{caption_text}]" unless caption_text.empty?
        text += "{\n"

        # Handle children - they may be strings or nodes
        if node.children.any?
          content_lines = []
          node.children.each do |child|
            if child.is_a?(String)
              # Skip empty strings
              content_lines << child unless child.strip.empty?
            else
              content_lines << visit(child)
            end
          end
          if content_lines.any?
            text += content_lines.join("\n")
            text += "\n" unless text.end_with?("\n")
          end
        end

        text + "//}\n\n"
      end

      def visit_block(node)
        # Use dynamic method dispatch for extensibility
        # To add a new block type, define a method: visit_block_<type>(node)
        #
        # EXTENSION GUIDE: When adding new block types:
        # 1. Define a new method: visit_block_<blocktype>(node)
        # 2. For simple wrapper blocks (like quote, read, lead):
        #    - Get content: content = visit_children(node)
        #    - Ensure newline: text += "\n" unless content.end_with?("\n")
        #    - Format: "//blocktype{\ncontent\n//}\n\n"
        # 3. For directive blocks (like pagebreak, hr):
        #    - Format: "//blocktype\n\n"
        # 4. For blocks with parameters (like footnote[id][content]):
        #    - Use node.args for parameters
        #    - Format: "//blocktype[#{node.args.join('][')}]\n\n"
        # 5. For blocks with caption (like texequation):
        #    - Use caption_to_review_markup(node.caption_node)
        #    - Check node.id? for ID availability
        method_name = "visit_block_#{node.block_type}"
        if respond_to?(method_name, true)
          send(method_name, node)
        else
          # Default: just render children for unknown block types
          visit_children(node)
        end
      end

      # Simple wrapper block helper
      # Wraps content in //blocktype{ ... //}
      def render_simple_wrapper_block(block_type, content)
        text = "//#{block_type}{\n" + content
        text += "\n" unless content.end_with?("\n")
        text + "//}\n\n"
      end

      # Block: //quote{ ... //}
      def visit_block_quote(node)
        content = visit_children(node)
        render_simple_wrapper_block('quote', content)
      end

      # Block: //read{ ... //}
      def visit_block_read(node)
        content = visit_children(node)
        render_simple_wrapper_block('read', content)
      end

      # Block: //lead{ ... //}
      def visit_block_lead(node)
        content = visit_children(node)
        render_simple_wrapper_block('lead', content)
      end

      # Block: //centering{ ... //}
      def visit_block_centering(node)
        content = visit_children(node)
        render_simple_wrapper_block('centering', content)
      end

      # Block: //flushright{ ... //}
      def visit_block_flushright(node)
        content = visit_children(node)
        render_simple_wrapper_block('flushright', content)
      end

      # Block: //comment{ ... //}
      def visit_block_comment(node)
        content = visit_children(node)
        render_simple_wrapper_block('comment', content)
      end

      # Block: //address{ ... //}
      def visit_block_address(node)
        content = visit_children(node)
        render_simple_wrapper_block('address', content)
      end

      # Block: //talk{ ... //}
      def visit_block_talk(node)
        content = visit_children(node)
        render_simple_wrapper_block('talk', content)
      end

      # Block: //blankline
      def visit_block_blankline(_node)
        "//blankline\n\n"
      end

      # Block: //noindent
      def visit_block_noindent(node)
        "//noindent\n" + visit_children(node)
      end

      # Block: //pagebreak
      def visit_block_pagebreak(_node)
        "//pagebreak\n\n"
      end

      # Block: //hr
      def visit_block_hr(_node)
        "//hr\n\n"
      end

      # Block: //parasep
      def visit_block_parasep(_node)
        "//parasep\n\n"
      end

      # Block: //bpo
      def visit_block_bpo(_node)
        "//bpo\n\n"
      end

      # Block: //printendnotes
      def visit_block_printendnotes(_node)
        "//printendnotes\n\n"
      end

      # Block: //beginchild
      def visit_block_beginchild(_node)
        "//beginchild\n\n"
      end

      # Block: //endchild
      def visit_block_endchild(_node)
        "//endchild\n\n"
      end

      # Block: //olnum[num]
      def visit_block_olnum(node)
        "//olnum[#{node.args.join(', ')}]\n\n"
      end

      # Block: //firstlinenum[num]
      def visit_block_firstlinenum(node)
        "//firstlinenum[#{node.args.join(', ')}]\n\n"
      end

      # Block: //tsize[...]
      def visit_block_tsize(node)
        "//tsize[#{node.args.join(', ')}]\n\n"
      end

      # Block: //label[id]
      def visit_block_label(node)
        "//label[#{node.args.first}]\n\n"
      end

      # Block: //footnote[id][content]
      def visit_block_footnote(node)
        content = visit_children(node)
        "//footnote[#{node.args.join('][') || ''}][#{content.strip}]\n\n"
      end

      # Block: //endnote[id][content]
      def visit_block_endnote(node)
        content = visit_children(node)
        "//endnote[#{node.args.join('][') || ''}][#{content.strip}]\n\n"
      end

      # Block: //texequation[id][caption]{ ... //}
      def visit_block_texequation(node)
        text = '//texequation'
        caption_text = caption_to_review_markup(node.caption_node)
        if node.id || !caption_text.empty?
          text += "[#{node.id}]" if node.id
          text += "[#{caption_text}]" unless caption_text.empty?
        end
        text += "{\n"
        content = visit_children(node)
        text += content
        text += "\n" unless content.end_with?("\n")
        text + "//}\n\n"
      end

      # Block: //doorquote[...]{ ... //}
      def visit_block_doorquote(node)
        text = '//doorquote'
        text += "[#{node.args.join('][')}]" if node.args.any?
        text += "{\n"
        content = visit_children(node)
        text += content
        text += "\n" unless content.end_with?("\n")
        text + "//}\n\n"
      end

      # Block: //bibpaper[...]{ ... //}
      def visit_block_bibpaper(node)
        text = '//bibpaper'
        text += "[#{node.args.join('][')}]" if node.args.any?
        text += "{\n"
        content = visit_children(node)
        text += content
        text += "\n" unless content.end_with?("\n")
        text + "//}\n\n"
      end

      # Block: //graph[...]{ ... //}
      def visit_block_graph(node)
        text = '//graph'
        text += "[#{node.args.join('][')}]" if node.args.any?
        text += "{\n"
        content = visit_children(node)
        text += content
        text += "\n" unless content.end_with?("\n")
        text + "//}\n\n"
      end

      # Block: //box[caption]{ ... //}
      def visit_block_box(node)
        text = '//box'
        text += "[#{node.args.first}]" if node.args.any?
        text += "{\n"
        content = visit_children(node)
        text += content
        text += "\n" unless content.end_with?("\n")
        text + "//}\n\n"
      end

      def visit_embed(node)
        case node.embed_type
        when :block
          target = node.target_builders&.join(',') || ''
          text = "//embed[#{target}]{\n"
          text += node.content || ''
          text += "\n" unless text.end_with?("\n")
          text + "//}\n\n"
        when :raw
          target = node.target_builders&.join(',') || ''
          text = "//raw[#{target}]{\n"
          text += node.content || ''
          text += "\n" unless text.end_with?("\n")
          text + "//}\n\n"
        else
          # Inline embed should be handled in inline context
          "@<embed>{#{node.content || ''}}"
        end
      end

      def visit_caption(node)
        visit_children(node)
      end

      def visit_column(node)
        text = '=' * (node.level || 1)
        text += '[column]'
        text += "{#{node.label}}" if node.label && !node.label.empty?
        caption_text = caption_to_review_markup(node.caption_node)
        text += " #{caption_text}" unless caption_text.empty?
        text += "\n\n"
        text += visit_children(node)
        text += "\n" unless text.end_with?("\n")
        text += '=' * (node.level || 1)
        text += "[/column]\n\n"
        text
      end

      def visit_unordered_list(node)
        text = ''
        node.children.each do |item|
          next unless item.is_a?(ReVIEW::AST::ListItemNode)

          level = item.level || 1
          marker = '*' * level
          text += format_list_item(marker, level, item)
        end
        text + (text.empty? ? '' : "\n")
      end

      def visit_ordered_list(node)
        text = ''
        node.children.each_with_index do |item, index|
          next unless item.is_a?(ReVIEW::AST::ListItemNode)

          level = item.level || 1
          number = item.number || (index + 1)
          marker = "#{number}."
          text += format_list_item(marker, level, item)
        end
        text + (text.empty? ? '' : "\n")
      end

      def visit_definition_list(node)
        text = ''
        node.children.each do |item|
          next unless item.is_a?(ReVIEW::AST::ListItemNode)

          next unless item.term_children.any? || item.children.any?

          term = item.term_children.any? ? visit_all(item.term_children).join : ''
          text += ": #{term}\n"

          item.children.each do |defn|
            defn_text = visit(defn)
            # Remove trailing newlines from paragraph content in definition lists
            # to avoid creating blank lines between definition items
            defn_text = defn_text.sub(/\n+\z/, '') if defn.is_a?(ReVIEW::AST::ParagraphNode)
            text += "\t#{defn_text}\n" unless defn_text.strip.empty?
          end
        end
        text + (text.empty? ? '' : "\n")
      end

      # Format a list item with proper indentation
      def format_list_item(marker, _level, item)
        # For Re:VIEW format, all list items start with a single space
        indent = ' '

        # Separate nested lists from other content
        non_list_children = []
        nested_lists = []

        item.children.each do |child|
          if child.is_a?(ReVIEW::AST::ListNode)
            nested_lists << child
          else
            non_list_children << child
          end
        end

        # Process non-list content
        # Check if we have multiple TextNodes (possibly with InlineNodes in between)
        # which indicates continuation lines in the original markup
        text_node_count = non_list_children.count { |c| c.is_a?(ReVIEW::AST::TextNode) }

        if text_node_count > 1
          # Multiple text nodes indicate continuation lines
          # Process each child separately and join with newlines
          parts = []
          current_line = []

          non_list_children.each do |child|
            # Start a new line if we already have content
            if child.is_a?(ReVIEW::AST::TextNode) && current_line.any?
              # Join the current line and strip it
              parts << current_line.join.strip
              current_line = []
            end
            # Add the visited child to the current line (TextNode or InlineNode)
            current_line << visit(child)
          end

          # Don't forget the last line
          parts << current_line.join.strip if current_line.any?

          content = parts.first
          continuation = parts[1..].map { |part| "   #{part}" }.join("\n")
          content += "\n" + continuation unless continuation.empty?
        else
          content = visit_all(non_list_children).join.strip
        end

        # Build the item text
        text = "#{indent}#{marker} #{content}\n"

        # Process nested lists separately
        nested_lists.each do |nested_list|
          nested_text = visit(nested_list)
          # Remove the trailing newline from nested list to avoid extra blank line
          text += nested_text.chomp
        end

        text
      end

      # Build table opening tag with type, ID, and caption
      # @param node [TableNode] The table node
      # @param table_type [Symbol] The table type (:table, :imgtable, etc.)
      # @return [String] Table opening tag with parameters
      def build_table_header(node, table_type)
        text = "//#{table_type}"
        text += "[#{node.id}]" if node.id?

        caption_text = caption_to_review_markup(node.caption_node)
        text += "[#{caption_text}]" unless caption_text.empty?
        text + "{\n"
      end

      # Build table body with header and body rows
      # @param header_rows [Array<RowNode>] Header row nodes
      # @param body_rows [Array<RowNode>] Body row nodes
      # @return [String] Formatted table rows with separator
      def build_table_body(header_rows, body_rows)
        lines = format_table_rows(header_rows)
        lines << ('-' * 12) if header_rows.any?
        lines.concat(format_table_rows(body_rows))

        return '' if lines.empty?

        lines.join("\n") + "\n"
      end

      # Format multiple table rows
      # @param rows [Array<RowNode>] Row nodes to format
      # @return [Array<String>] Formatted row strings
      def format_table_rows(rows)
        rows.map { |row| format_table_row(row) }
      end

      # Format a single table row
      # @param row [RowNode] Row node to format
      # @return [String] Tab-separated cell contents
      def format_table_row(row)
        row.children.map { |cell| render_cell_content(cell) }.join("\t")
      end

      # Render table cell content
      # @param cell [CellNode] Cell node to render
      # @return [String] Cell content or '.' for empty cells
      def render_cell_content(cell)
        content = cell.children.map { |child| visit(child) }.join
        # Empty cells should be represented with a dot in Re:VIEW syntax
        content.empty? ? '.' : content
      end
    end
  end
end
