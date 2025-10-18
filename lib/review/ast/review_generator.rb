# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/ast'

module ReVIEW
  module AST
    # ReVIEWGenerator - Generate Re:VIEW text from AST nodes
    #
    # This class converts AST structures back to Re:VIEW text format,
    # enabling round-trip conversion between Re:VIEW text and AST.
    #
    # All visitor methods are pure functions that return text without side effects,
    # ensuring order-independent processing.
    class ReVIEWGenerator
      def initialize(options = {})
        @options = options
      end

      # Generate Re:VIEW text from AST root node
      # @param ast_root [AST::Node] The root node of AST
      # @return [String] Generated Re:VIEW text
      def generate(ast_root)
        visit(ast_root)
      end

      private

      # Visit a node and return its Re:VIEW representation
      # @param node [AST::Node] The node to visit
      # @return [String] Re:VIEW text representation
      def visit(node)
        return '' unless node

        # Handle plain strings
        return node if node.is_a?(String)

        # Handle Hash objects (from JSON deserialization issues)
        if node.is_a?(Hash)
          if node['type'] == 'CaptionNode' || node['type'] == 'TextNode'
            # Extract content from serialized node
            if node['children']
              return node['children'].map { |child| visit(child) }.join
            elsif node['content']
              return node['content'].to_s
            end
          end
          return node.inspect # Convert hash to string representation for debugging
        end

        method_name = "visit_#{node.class.name.split('::').last.sub(/Node$/, '').downcase}"
        if respond_to?(method_name, true)
          send(method_name, node)
        else
          visit_children(node)
        end
      end

      # Visit all children of a node and concatenate results
      # @param node [AST::Node] The parent node
      # @return [String] Concatenated text from all children
      def visit_children(node)
        return '' unless node.children

        node.children.map { |child| visit(child) }.join
      end

      # === Document Node ===
      def visit_document(node)
        visit_children(node)
      end

      # === Headline Node ===
      def visit_headline(node)
        text = '=' * (node.level || 1)
        text += "[#{node.label}]" if node.label && !node.label.empty?

        caption_text = caption_to_text(node.caption)
        text += ' ' + caption_text unless caption_text.empty?

        text + "\n\n" + visit_children(node)
      end

      # === Paragraph Node ===
      def visit_paragraph(node)
        content = visit_children(node)
        return '' if content.strip.empty?

        content + "\n\n"
      end

      # === Text Node ===
      def visit_text(node)
        node.content || ''
      end

      # === Inline Node ===
      def visit_inline(node)
        content = visit_children(node)

        # Debug: check if we're getting the content properly
        # Only use args as content for specific inline types that don't have special handling
        if content.empty? && node.respond_to?(:args) && node.args&.any? && !%w[href kw ruby].include?(node.inline_type)
          # Use first arg as content if children are empty
          content = node.args.first.to_s
        end

        case node.inline_type
        when 'href'
          # href has special syntax with URL
          url = node.args&.first || ''
          if content.empty?
            "@<href>{#{url}}"
          else
            "@<href>{#{url}, #{content}}"
          end
        when 'kw'
          # kw can have optional description
          if node.args&.any?
            "@<kw>{#{content}, #{node.args.join(', ')}}"
          else
            "@<kw>{#{content}}"
          end
        when 'ruby'
          # ruby has base text and ruby text
          ruby_text = node.args&.first || ''
          "@<ruby>{#{content}, #{ruby_text}}"
        else
          "@<#{node.inline_type}>{#{content}}"
        end
      end

      # === Code Block Node ===
      def visit_codeblock(node)
        # Determine block type
        block_type = if node.id?
                       node.line_numbers ? 'listnum' : 'list'
                     else
                       node.line_numbers ? 'emlistnum' : 'emlist'
                     end

        # Build opening tag
        text = '//' + block_type
        text += "[#{node.id}]" if node.id?

        caption_text = caption_to_text(node.caption)
        text += "[#{caption_text}]" if caption_text && !caption_text.empty?
        text += "{\n"

        # Add code lines from original_text or reconstruct from AST
        if node.original_text && !node.original_text.empty?
          text += node.original_text
        elsif node.children&.any?
          # Reconstruct from AST structure
          lines = node.children.map do |line_node|
            if line_node.children
              line_node.children.map do |child|
                case child
                when ReVIEW::AST::TextNode
                  child.content
                when ReVIEW::AST::InlineNode
                  "@<#{child.inline_type}>{#{child.args&.first || ''}}"
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

      # === List Node ===
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

      # === List Item Node ===
      def visit_listitem(node)
        # This should be handled by parent list type
        visit_children(node)
      end

      # === Table Node ===
      def visit_table(node)
        # Determine table type
        table_type = node.table_type || :table

        # Build opening tag
        text = "//#{table_type}"
        text += "[#{node.id}]" if node.id?

        caption_text = caption_to_text(node.caption)
        text += "[#{caption_text}]" if caption_text && !caption_text.empty?
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

      # === Image Node ===
      def visit_image(node)
        text = "//image[#{node.id || ''}]"

        caption_text = caption_to_text(node.caption)
        text += "[#{caption_text}]" if caption_text && !caption_text.empty?
        text += "[#{node.metric}]" if node.metric && !node.metric.empty?
        text + "\n\n"
      end

      # === Minicolumn Node ===
      def visit_minicolumn(node)
        text = "//#{node.minicolumn_type}"

        caption_text = caption_to_text(node.caption)
        text += "[#{caption_text}]" if caption_text && !caption_text.empty?
        text += "{\n"

        # Handle children - they may be strings or nodes
        if node.children&.any?
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

      # === Block Node ===
      def visit_block(node) # rubocop:disable Metrics/CyclomaticComplexity
        case node.block_type
        when :quote
          "//quote{\n" + visit_children(node) + "//}\n\n"
        when :read
          "//read{\n" + visit_children(node) + "//}\n\n"
        when :lead
          "//lead{\n" + visit_children(node) + "//}\n\n"
        when :centering
          "//centering{\n" + visit_children(node) + "//}\n\n"
        when :flushright
          "//flushright{\n" + visit_children(node) + "//}\n\n"
        when :comment
          "//comment{\n" + visit_children(node) + "//}\n\n"
        when :blankline
          "//blankline\n\n"
        when :noindent
          "//noindent\n" + visit_children(node)
        when :pagebreak
          "//pagebreak\n\n"
        when :olnum
          "//olnum[#{node.args&.join(', ')}]\n\n"
        when :firstlinenum
          "//firstlinenum[#{node.args&.join(', ')}]\n\n"
        when :tsize
          "//tsize[#{node.args&.join(', ')}]\n\n"
        when :footnote
          content = visit_children(node)
          "//footnote[#{node.args&.join('][') || ''}][#{content.strip}]\n\n"
        when :endnote
          content = visit_children(node)
          "//endnote[#{node.args&.join('][') || ''}][#{content.strip}]\n\n"
        when :label
          "//label[#{node.args&.first}]\n\n"
        when :printendnotes
          "//printendnotes\n\n"
        when :beginchild
          "//beginchild\n\n"
        when :endchild
          "//endchild\n\n"
        when :texequation
          # Math equation blocks
          text = '//texequation'
          if node.id || node.caption
            text += "[#{node.id}]" if node.id
            text += "[#{node.caption}]" if node.caption
          end
          text += "{\n"
          text += visit_children(node)
          text += "//}\n\n"

          text
        when :doorquote
          text = '//doorquote'
          text += "[#{node.args.join('][') if node.args&.any?}]"
          text += "{\n"
          text += visit_children(node)
          text += "//}\n\n"

          text
        when :bibpaper
          text = '//bibpaper'
          text += "[#{node.args.join('][') if node.args&.any?}]"
          text += "{\n"
          text += visit_children(node)
          text += "//}\n\n"

          text
        when :talk
          text = '//talk'
          text += "{\n"
          text += visit_children(node)
          text += "//}\n\n"

          text
        when :graph
          text = '//graph'
          text += "[#{node.args.join('][') if node.args&.any?}]"
          text += "{\n"
          text += visit_children(node)
          text += "//}\n\n"

          text
        when :address
          "//address{\n" + visit_children(node) + "//}\n\n"
        when :bpo
          "//bpo\n\n"
        when :hr
          "//hr\n\n"
        when :parasep
          "//parasep\n\n"
        when :box
          text = '//box'
          text += "[#{node.args.first}]" if node.args&.any?
          text += "{\n"
          text += visit_children(node)
          text += "//}\n\n"

          text
        else
          visit_children(node)
        end
      end

      # === Embed Node ===
      def visit_embed(node)
        case node.embed_type
        when :block
          text = "//embed[#{node.arg || ''}]{\n"
          text += (node.lines || []).join("\n")
          text += "\n" unless text.end_with?("\n")
          text + "//}\n\n"
        when :raw
          text = "//raw[#{node.arg || ''}]{\n"
          text += (node.lines || []).join("\n")
          text += "\n" unless text.end_with?("\n")
          text + "//}\n\n"
        else
          # Inline embed should be handled in inline context
          "@<embed>{#{node.arg || ''}}"
        end
      end

      # === Caption Node ===
      def visit_caption(node)
        visit_children(node)
      end

      # === Column Node ===
      def visit_column(node)
        text = '=' * (node.level || 1)
        text += '[column]'
        text += " #{node.caption.to_text}" if node.caption
        text + "\n\n" + visit_children(node)
      end

      # Helper method for unordered lists
      def visit_unordered_list(node)
        text = ''
        node.children&.each do |item|
          next unless item.is_a?(ReVIEW::AST::ListItemNode)

          text += format_list_item('*', item.level || 1, item)
        end
        text + (text.empty? ? '' : "\n")
      end

      # Helper method for ordered lists
      def visit_ordered_list(node)
        text = ''
        node.children&.each_with_index do |item, index|
          next unless item.is_a?(ReVIEW::AST::ListItemNode)

          number = item.number || (index + 1)
          text += format_list_item("#{number}.", item.level || 1, item)
        end
        text + (text.empty? ? '' : "\n")
      end

      # Helper method for definition lists
      def visit_definition_list(node)
        text = ''
        node.children&.each do |item|
          next unless item.is_a?(ReVIEW::AST::ListItemNode)

          # First child is term, rest are definitions
          next unless item.children&.any?

          term = visit(item.children.first)
          text += ": #{term}\n"

          item.children[1..-1].each do |defn|
            defn_text = visit(defn)
            text += "\t#{defn_text}\n" unless defn_text.strip.empty?
          end
        end
        text + (text.empty? ? '' : "\n")
      end

      # Format a list item with proper indentation
      def format_list_item(marker, level, item)
        # For Re:VIEW format, level 1 starts with no indent
        # Level 2+ gets additional spaces
        indent = ' ' * ((level - 1) * 2)
        content = visit_children(item).strip

        # Handle nested lists
        lines = content.split("\n")
        first_line = lines.shift || ''

        text = "#{indent}#{marker} #{first_line}\n"

        # Add continuation lines with proper indentation
        lines.each do |line|
          text += "#{indent}  #{line}\n"
        end

        text
      end

      # Helper to extract text from caption nodes
      def caption_to_text(caption)
        return '' unless caption

        if caption.respond_to?(:to_text)
          caption.to_text
        elsif caption.respond_to?(:children) && caption.children
          # For CaptionNode, extract text from children
          caption.children.map { |child| visit(child) }.join
        elsif caption.respond_to?(:to_s)
          caption.to_s
        else
          ''
        end
      end

      # Helper to render table cell content
      def render_cell_content(cell)
        return '' unless cell.respond_to?(:children)

        cell.children.map do |child|
          case child
          when ReVIEW::AST::TextNode
            child.content
          when ReVIEW::AST::InlineNode
            "@<#{child.inline_type}>{#{child.args&.first || ''}}"
          else
            visit(child)
          end
        end.join
      end
    end
  end
end
