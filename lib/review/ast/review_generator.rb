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

      # Convert CaptionNode to Re:VIEW markup format
      # @param caption_node [CaptionNode, nil] The caption node to convert
      # @return [String] Re:VIEW markup string
      def caption_to_review_markup(caption_node)
        return '' if caption_node.nil? || caption_node.children.empty?

        caption_node.children.map { |child| render_node_as_review_markup(child) }.join
      end

      # Recursively render AST nodes as Re:VIEW markup text
      # @param node [Node] The node to render
      # @return [String] Re:VIEW markup representation
      def render_node_as_review_markup(node)
        case node
        when ReVIEW::AST::TextNode
          node.content
        when ReVIEW::AST::InlineNode
          # Convert back to Re:VIEW markup
          content = node.children.map { |child| render_node_as_review_markup(child) }.join
          "@<#{node.inline_type}>{#{content}}"
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
        # For certain inline types, use args instead of visit_children
        # kw, ruby: args contain the actual content, children may have duplicate data
        case node.inline_type
        when 'kw'
          # kw: @<kw>{word, description} - use args directly
          if node.args.size >= 2
            word = node.args[0].to_s.gsub('\\', '\\\\\\\\').gsub('}', '\\}')
            desc = node.args[1].to_s.gsub('\\', '\\\\\\\\').gsub('}', '\\}')
            "@<kw>{#{word}, #{desc}}"
          elsif node.args.size == 1
            word = node.args[0].to_s.gsub('\\', '\\\\\\\\').gsub('}', '\\}')
            "@<kw>{#{word}}"
          else
            content = visit_children(node).gsub('\\', '\\\\\\\\').gsub('}', '\\}')
            "@<kw>{#{content}}"
          end
        when 'ruby'
          # ruby: @<ruby>{base, ruby_text} - use args directly
          base = node.args[0].to_s.gsub('\\', '\\\\\\\\').gsub('}', '\\}')
          if node.args.size >= 2
            ruby_text = node.args[1].to_s.gsub('\\', '\\\\\\\\').gsub('}', '\\}')
            "@<ruby>{#{base}, #{ruby_text}}"
          else
            "@<ruby>{#{base}}"
          end
        when 'href'
          # href: @<href>{url, text} - special handling
          url = node.args[0] || ''
          content = visit_children(node)
          if content.empty?
            "@<href>{#{url}}"
          else
            escaped_content = content.gsub('\\', '\\\\\\\\').gsub('}', '\\}')
            "@<href>{#{url}, #{escaped_content}}"
          end
        else
          # Default: use visit_children
          content = visit_children(node)
          # Use args as fallback if children are empty
          if content.empty? && node.args.any?
            content = node.args.first.to_s
          end
          escaped_content = content.gsub('\\', '\\\\\\\\').gsub('}', '\\}')
          "@<#{node.inline_type}>{#{escaped_content}}"
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
        # Determine table type
        table_type = node.table_type || :table

        # Build opening tag
        text = "//#{table_type}"
        text += "[#{node.id}]" if node.id?

        caption_text = caption_to_review_markup(node.caption_node)
        text += "[#{caption_text}]" unless caption_text.empty?
        text += "{\n"

        # Add header rows
        header_lines = node.header_rows.map do |header_row|
          header_row.children.map do |cell|
            render_cell_content(cell)
          end.join("\t")
        end

        # Add body rows
        body_lines = node.body_rows.map do |body_row|
          body_row.children.map do |cell|
            render_cell_content(cell)
          end.join("\t")
        end

        # Combine all lines with separator if headers exist
        all_lines = header_lines
        all_lines << ('-' * 12) if header_lines.any?
        all_lines.concat(body_lines)

        text += all_lines.join("\n")
        text += "\n" if all_lines.any?

        text + "//}\n\n"
      end

      def visit_image(node)
        text = "//image[#{node.id || ''}]"

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

      def visit_block(node) # rubocop:disable Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
        case node.block_type
        when :quote
          content = visit_children(node)
          text = "//quote{\n" + content
          text += "\n" unless content.end_with?("\n")
          text + "//}\n\n"
        when :read
          content = visit_children(node)
          text = "//read{\n" + content
          text += "\n" unless content.end_with?("\n")
          text + "//}\n\n"
        when :lead
          content = visit_children(node)
          text = "//lead{\n" + content
          text += "\n" unless content.end_with?("\n")
          text + "//}\n\n"
        when :centering
          content = visit_children(node)
          text = "//centering{\n" + content
          text += "\n" unless content.end_with?("\n")
          text + "//}\n\n"
        when :flushright
          content = visit_children(node)
          text = "//flushright{\n" + content
          text += "\n" unless content.end_with?("\n")
          text + "//}\n\n"
        when :comment
          content = visit_children(node)
          text = "//comment{\n" + content
          text += "\n" unless content.end_with?("\n")
          text + "//}\n\n"
        when :blankline
          "//blankline\n\n"
        when :noindent
          "//noindent\n" + visit_children(node)
        when :pagebreak
          "//pagebreak\n\n"
        when :olnum
          "//olnum[#{node.args.join(', ')}]\n\n"
        when :firstlinenum
          "//firstlinenum[#{node.args.join(', ')}]\n\n"
        when :tsize
          "//tsize[#{node.args.join(', ')}]\n\n"
        when :footnote
          content = visit_children(node)
          "//footnote[#{node.args.join('][') || ''}][#{content.strip}]\n\n"
        when :endnote
          content = visit_children(node)
          "//endnote[#{node.args.join('][') || ''}][#{content.strip}]\n\n"
        when :label
          "//label[#{node.args.first}]\n\n"
        when :printendnotes
          "//printendnotes\n\n"
        when :beginchild
          "//beginchild\n\n"
        when :endchild
          "//endchild\n\n"
        when :texequation
          # Math equation blocks
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
          text += "//}\n\n"

          text
        when :doorquote
          text = '//doorquote'
          text += "[#{node.args.join('][') if node.args.any?}]"
          text += "{\n"
          content = visit_children(node)
          text += content
          text += "\n" unless content.end_with?("\n")
          text += "//}\n\n"

          text
        when :bibpaper
          text = '//bibpaper'
          text += "[#{node.args.join('][') if node.args.any?}]"
          text += "{\n"
          content = visit_children(node)
          text += content
          text += "\n" unless content.end_with?("\n")
          text += "//}\n\n"

          text
        when :talk
          text = '//talk'
          text += "{\n"
          content = visit_children(node)
          text += content
          text += "\n" unless content.end_with?("\n")
          text += "//}\n\n"

          text
        when :graph
          text = '//graph'
          text += "[#{node.args.join('][') if node.args.any?}]"
          text += "{\n"
          content = visit_children(node)
          text += content
          text += "\n" unless content.end_with?("\n")
          text += "//}\n\n"

          text
        when :address
          content = visit_children(node)
          text = "//address{\n" + content
          text += "\n" unless content.end_with?("\n")
          text + "//}\n\n"
        when :bpo
          "//bpo\n\n"
        when :hr
          "//hr\n\n"
        when :parasep
          "//parasep\n\n"
        when :box
          text = '//box'
          text += "[#{node.args.first}]" if node.args.any?
          text += "{\n"
          content = visit_children(node)
          text += content
          text += "\n" unless content.end_with?("\n")
          text += "//}\n\n"

          text
        else
          visit_children(node)
        end
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

      # Helper to render table cell content
      def render_cell_content(cell)
        content = cell.children.map do |child|
          visit(child)
        end.join

        # Empty cells should be represented with a dot in Re:VIEW syntax
        content.empty? ? '.' : content
      end
    end
  end
end
