# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/ast'

module ReVIEW
  module AST
    class Renderer
      def initialize(builder)
        @builder = builder
      end

      # Render AST to output using the builder
      def render(ast_root)
        visit_node(ast_root)
      end

      private

      def visit_node(node)
        case node
        when AST::DocumentNode
          visit_document(node)
        when AST::HeadlineNode
          visit_headline(node)
        when AST::ParagraphNode
          visit_paragraph(node)
        when AST::ListNode
          visit_list(node)
        when AST::TableNode
          visit_table(node)
        when AST::ImageNode
          visit_image(node)
        when AST::CodeBlockNode
          visit_code_block(node)
        when AST::ColumnNode
          visit_column(node)
        when AST::InlineNode
          visit_inline(node)
        when AST::TextNode
          visit_text(node)
        when AST::CaptionNode
          visit_caption(node)
        when AST::EmbedNode
          visit_embed(node)
        else
          # For unknown node types, just visit children
          visit_children(node)
        end
      end

      def visit_children(node)
        node.children.each do |child|
          visit_node(child)
        end
      end

      def visit_document(node)
        # Document node itself doesn't generate output, just process children
        visit_children(node)
      end

      def visit_headline(node)
        @builder.headline(node.level, node.label, node.caption)
      end

      def visit_paragraph(node)
        # ParagraphNode content is always stored in children as TextNode/InlineNode
        lines = if node.children.any?
                  [render_inline_content(node)]
                else
                  # Empty paragraph
                  []
                end
        @builder.paragraph(lines)
      end

      def visit_list(node)
        case node.list_type
        when :ul
          visit_ul_list(node)
        when :ol
          visit_ol_list(node)
        when :dl
          visit_dl_list(node)
        end
      end

      def visit_ul_list(node)
        @builder.ul_begin
        node.children.each do |item|
          # Render item content using inline processing
          lines = [render_inline_content(item)]
          @builder.ul_item_begin(lines)
          @builder.ul_item_end
        end
        @builder.ul_end
      end

      def visit_ol_list(node)
        @builder.ol_begin
        node.children.each_with_index do |item, index|
          # Render item content using inline processing
          lines = [render_inline_content(item)]
          @builder.ol_item(lines, (index + 1).to_s)
        end
        @builder.ol_end
      end

      def visit_dl_list(node)
        @builder.dl_begin
        node.children.each do |item|
          # First child should be the dt (term)
          next unless item.children.any?

          dt_node = item.children[0]
          dt_content = if dt_node.is_a?(AST::TextNode)
                         dt_node.content
                       else
                         render_inline_content(dt_node)
                       end
          @builder.dt(dt_content)

          # Remaining children are dd content
          next unless item.children.size > 1

          dd_lines = item.children[1..-1].map do |child|
            if child.is_a?(AST::TextNode)
              child.content
            else
              render_inline_content(child)
            end
          end
          @builder.dd(dd_lines) if dd_lines.any?
        end
        @builder.dl_end
      end

      def visit_table(node)
        # Convert headers and rows to lines format expected by builder
        lines = []
        if node.headers.any?
          lines.concat(node.headers)
          lines << ('=' * 12) # table separator
        end
        lines.concat(node.rows) if node.rows.any?

        # Render caption using unified processing
        caption = render_caption_content(node.caption)

        # Call appropriate builder method based on table type
        case node.table_type
        when :emtable
          @builder.emtable(lines, caption)
        when :imgtable
          @builder.imgtable(lines, node.id, caption, node.metric)
        else
          @builder.table(lines, node.id, caption)
        end
      end

      def visit_image(node)
        # Render caption using unified processing
        caption = render_caption_content(node.caption)
        # Image builder method expects lines parameter (usually empty for images)
        @builder.image([], node.id, caption, node.metric)
      end

      def visit_code_block(node)
        lines = node.lines || []
        # Render caption using unified processing
        caption = render_caption_content(node.caption)

        if node.line_numbers
          if node.id && caption && !caption.empty?
            @builder.listnum(lines, node.id, caption, node.lang)
          else
            @builder.emlistnum(lines, caption, node.lang)
          end
        elsif node.id && caption && !caption.empty?
          @builder.list(lines, node.id, caption, node.lang)
        elsif node.lang == 'shell'
          @builder.cmd(lines, caption)
        else
          @builder.emlist(lines, caption, node.lang)
        end
      end

      def visit_inline(node)
        # Render inline element using builder's inline method
        if @builder.respond_to?("inline_#{node.inline_type}")
          # Render the content of the inline element
          content = render_inline_content(node)
          @builder.__send__("inline_#{node.inline_type}", content)
        else
          # Fallback: just render content without inline formatting
          render_inline_content(node)
        end
      end

      def visit_text(node)
        # Text nodes return their content for rendering
        node.content
      end

      # Helper method to render content of nodes with inline children
      def render_inline_content(node)
        result = +''
        node.children.each do |child|
          case child
          when AST::TextNode
            result << @builder.nofunc_text(child.content)
          when AST::InlineNode
            if @builder.respond_to?("inline_#{child.inline_type}")
              # Special handling for certain inline types
              case child.inline_type
              when 'ruby', 'href', 'kw', 'hd'
                # These have multiple args and need special processing
                result << @builder.__send__("inline_#{child.inline_type}", child.args.first)
              when 'img', 'list', 'table', 'eq', 'chap', 'chapref', 'sec', 'secref', 'labelref', 'ref', 'w', 'wb'
                # These are reference/cross-reference commands that use args directly
                result << if child.args.size > 1
                            # For commands with chapter|id format, pass the second argument (ID)
                            @builder.__send__("inline_#{child.inline_type}", child.args[1])
                          else
                            @builder.__send__("inline_#{child.inline_type}", child.args.first)
                          end
              else
                content = render_inline_content(child)
                result << @builder.__send__("inline_#{child.inline_type}", content)
              end
            else
              result << render_inline_content(child)
            end
          when AST::EmbedNode
            result << if child.embed_type == :inline
                        @builder.inline_embed(child.arg)
                      else
                        # Block embed shouldn't be in inline content, but handle gracefully
                        visit_embed(child).to_s
                      end
          else
            # For any other node types, try to visit them
            result << visit_node(child).to_s
          end
        end
        result
      end

      def visit_embed(node)
        case node.embed_type
        when :block
          # Block embed
          @builder.embed(node.lines, node.arg)
        when :inline
          # Inline embed - return the processed content for inline rendering
          @builder.inline_embed(node.arg)
        when :raw
          # Raw content
          @builder.raw(node.arg) if node.arg
        end
      end

      def visit_caption(node)
        # CaptionNode is processed inline and returns text for the builder
        render_inline_content(node)
      end

      def visit_column(node)
        # Render column caption using the unified caption processing
        caption = render_caption_content(node.caption)

        @builder.column_begin(node.level, node.label, caption)
        visit_children(node)
        @builder.column_end(node.level)
      end

      # Unified caption content rendering
      def render_caption_content(caption)
        case caption
        when AST::CaptionNode
          render_inline_content(caption)
        when Array
          # Legacy array format
          result = +''
          caption.each do |caption_node|
            result << visit_node(caption_node).to_s
          end
          result
        when String
          caption
        else
          ''
        end
      end
    end
  end
end
