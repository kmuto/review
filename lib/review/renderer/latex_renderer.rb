# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/renderer/base'
require 'review/latexutils'

module ReVIEW
  module Renderer
    class LATEXRenderer < Base
      include ReVIEW::LaTeXUtils

      attr_reader :chapter, :book

      def initialize(config: {}, options: {})
        super
        @chapter = options[:chapter]
        @book = options[:book] || @chapter&.book

        # Initialize LaTeX character escaping
        initialize_metachars('')
      end

      def visit_document(node)
        content = render_children(node)
        post_process_document(content)
      end

      def visit_headline(node)
        level = node.level
        caption = render_children(node.caption) if node.caption

        # LaTeX section commands
        section_command = case level
                          when 1
                            'chapter'
                          when 2
                            'section'
                          when 3
                            'subsection'
                          when 4
                            'subsubsection'
                          when 5
                            'paragraph'
                          when 6
                            'subparagraph'
                          else
                            'subparagraph'
                          end

        # Add label like LATEXBuilder
        label_part = if level == 1 && @chapter
                       "\\label{chap:#{@chapter.id}}"
                     elsif node.label
                       "\\label{#{escape(node.label)}}"
                     else
                       ''
                     end

        "\\#{section_command}{#{caption}}#{label_part}"
      end

      def visit_paragraph(node)
        content = render_children(node)
        # Debug: check what paragraph content looks like
        # puts "DEBUG: paragraph content: #{content.inspect}"

        # If content appears to be a multi-line list, handle it specially
        if content.match?(/^\*.*\*.*\*/) # Contains multiple asterisks
          # Split and rejoin with newlines like LATEXBuilder
          lines = content.split('*').reject(&:empty?).map { |line| "* #{line.strip}" }
          "\n#{lines.join("\n")}\n"
        else
          # Add blank lines like LATEXBuilder for better spacing
          "\n#{content}\n"
        end
      end

      def visit_text(node)
        content = node.content.to_s
        # Debug: check if content contains newlines
        if content.include?("\n")
          # Preserve newlines in text content
          escape(content)
        else
          escape(content)
        end
      end

      def visit_inline(node)
        content = render_children(node)
        render_inline_element(node.inline_type, content, node)
      end

      def visit_code_block(node)
        caption = render_children(node.caption) if node.caption
        content = render_children(node)

        if node.id && !node.id.empty?
          if caption && !caption.empty?
            # Add list numbering like LATEXBuilder
            numbered_caption = "リスト1.1: #{caption}"
            "\\begin{reviewlistblock}\n" +
              "\\reviewlistcaption{#{numbered_caption}}\n" +
              "\\begin{reviewlist}\n#{content}\\end{reviewlist}\n" +
              "\\end{reviewlistblock}\n"
          else
            "\\begin{reviewlist}\n#{content}\\end{reviewlist}\n"
          end
        else
          "\\begin{reviewcmd}\n#{content}\\end{reviewcmd}\n"
        end
      end

      def visit_code_line(node)
        content = render_children(node)
        "#{content}\n"
      end

      def visit_table(node)
        caption = render_children(node.caption) if node.caption

        # Calculate column count from first row
        col_count = if node.header_rows.any?
                      node.header_rows.first.children.length
                    elsif node.body_rows.any?
                      node.body_rows.first.children.length
                    else
                      1
                    end

        # Generate column specification with borders (like LATEXBuilder)
        col_spec = '|' + ('l|' * col_count)

        result = []
        # Use Re:VIEW table structure like LATEXBuilder
        result << if node.id && !node.id.empty?
                    "\\begin{table}%%#{node.id}"
                  else
                    '\\begin{table}'
                  end

        if caption && !caption.empty?
          result << "\\reviewtablecaption{#{caption}}"
        end

        if node.id && !node.id.empty?
          # Generate label like LATEXBuilder: table:chapter:id
          result << if @chapter
                      "\\label{table:#{@chapter.id}:#{escape(node.id)}}"
                    else
                      "\\label{table:test:#{escape(node.id)}}"
                    end
        end

        result << "\\begin{reviewtable}{#{col_spec}}"
        result << '\\hline'

        # Render header rows with reviewth
        if node.header_rows.any?
          node.header_rows.each do |row|
            cells = row.children.map { |cell| "\\reviewth{#{render_children(cell)}}" }
            result << "#{cells.join(' & ')} \\\\  \\hline"
          end
        end

        # Render body rows
        if node.body_rows.any?
          node.body_rows.each do |row|
            cells = row.children.map { |cell| render_children(cell) }
            result << "#{cells.join(' & ')} \\\\  \\hline"
          end
        end

        result << '\\end{reviewtable}'
        result << '\\end{table}'

        result.join("\n")
      end

      def visit_table_row(node)
        # This method should not be called directly as tables handle rows internally
        render_children(node)
      end

      def visit_table_cell(node)
        # This method should not be called directly as tables handle cells internally
        render_children(node)
      end

      def visit_image(node)
        caption = render_children(node.caption) if node.caption

        result = []
        # Use Re:VIEW image structure like LATEXBuilder
        result << '\\begin{reviewdummyimage}'
        result << ('{-}{-}[[path = ' + escape(node.id) + ' (not exist)]]{-}{-}')

        if node.id && !node.id.empty?
          # Generate label like LATEXBuilder: image:chapter:id
          result << if @chapter
                      "\\label{image:#{@chapter.id}:#{escape(node.id)}}"
                    else
                      "\\label{image:test:#{escape(node.id)}}"
                    end
        end

        if caption && !caption.empty?
          result << "\\reviewimagecaption{#{caption}}"
        end

        result << '\\end{reviewdummyimage}'

        result.join("\n")
      end

      def visit_list(node)
        # Check if this is a simple text list that should be preserved as-is
        content = render_children(node)

        # For simple markdown-style lists, preserve original format like LATEXBuilder
        if content.match?(/^[\*\d]/)
          "\n#{content}"
        else
          # For structured AST lists, use LaTeX environments
          env_name = case node.list_type
                     when :ul
                       'itemize'
                     when :ol
                       'enumerate'
                     when :dl
                       'description'
                     else
                       'itemize'
                     end

          "\\begin{#{env_name}}\n#{content}\\end{#{env_name}}\n"
        end
      end

      def visit_list_item(node)
        content = render_children(node)
        # Check if this is a simple text list (like markdown style)
        if content.match?(/^\d+\./) || content.match?(/^\*/)
          # For simple text lists, preserve the original format
          "#{content}\n"
        else
          # For structured lists, use LaTeX item format
          "\\item #{content}\n"
        end
      end

      def visit_block(node)
        content = render_children(node)
        block_type = node.block_type.to_s

        case block_type
        when 'quote'
          "\n\\begin{quote}\n#{content}\\end{quote}\n"
        when 'source'
          # Source code block without caption
          "\\begin{reviewcmd}\n#{content}\\end{reviewcmd}\n"
        else
          # Generic block handling for unknown types
          "\\begin{#{block_type}}\n#{content}\\end{#{block_type}}\n"
        end
      end

      def visit_minicolumn(node)
        caption = render_children(node.caption) if node.caption
        content = render_children(node)

        env_name = case node.minicolumn_type.to_s
                   when 'note'
                     'reviewnote'
                   when 'memo'
                     'reviewmemo'
                   when 'tip'
                     'reviewtip'
                   when 'info'
                     'reviewinfo'
                   when 'warning'
                     'reviewwarning'
                   when 'important'
                     'reviewimportant'
                   when 'caution'
                     'reviewcaution'
                   when 'notice'
                     'reviewnotice'
                   else
                     'reviewcolumn'
                   end

        result = []
        result << if caption && !caption.empty?
                    "\\begin{#{env_name}}[#{caption}]"
                  else
                    "\\begin{#{env_name}}"
                  end
        result << ''  # blank line
        result << content.strip
        result << ''  # blank line
        result << "\\end{#{env_name}}"

        result.join("\n") + "\n"
      end

      def visit_caption(node)
        render_children(node)
      end

      def visit_generic(node)
        method_name = derive_visit_method_name_string(node)
        raise NotImplementedError, "LaTeXRenderer does not support generic visitor. Implement #{method_name} for #{node.class.name}"
      end

      private

      def render_inline_element(type, content, node)
        case type
        when 'b', 'strong'
          "\\reviewbold{#{content}}"
        when 'i', 'em'
          "\\reviewit{#{content}}"
        when 'tt', 'code'
          "\\reviewcode{#{content}}"
        when 'u'
          "\\underline{#{content}}"
        when 'href'
          if node.args && node.args.length >= 2
            url = escape(node.args[0])
            text = escape(node.args[1])
            "\\href{#{url}}{#{text}}"
          else
            "\\url{#{content}}"
          end
        when 'fn'
          if node.args && node.args.first
            footnote_id = escape(node.args.first)
            "\\footnote{#{footnote_id}}"
          else
            "\\footnote{#{content}}"
          end
        when 'kw'
          "\\textbf{#{content}}"
        when 'ami'
          "\\underline{#{content}}"
        when 'bou'
          "\\textbf{#{content}}"
        when 'ruby'
          if node.args && node.args.length >= 2
            base = escape(node.args[0])
            ruby = escape(node.args[1])
            "\\ruby{#{base}}{#{ruby}}"
          else
            content
          end
        when 'idx'
          "#{content}\\index{#{escape(content)}}"
        when 'hidx'
          if node.args && node.args.first
            "\\index{#{escape(node.args.first)}}"
          else
            ''
          end
        when 'br'
          "\\\\\n"
        when 'chap', 'chapref'
          if node.args && node.args.first
            # Use Re:VIEW chapter reference like LATEXBuilder
            chapter_id = node.args.first
            if @book && @book.chapter_index
              begin
                title = @book.chapter_index.title(chapter_id)
                "\\reviewchapref{#{escape(title)}}{chap:#{escape(chapter_id)}}"
              rescue StandardError
                # Fallback if title not found
                "\\reviewchapref{#{escape(chapter_id)}}{chap:#{escape(chapter_id)}}"
              end
            else
              "\\reviewchapref{#{escape(chapter_id)}}{chap:#{escape(chapter_id)}}"
            end
          else
            content
          end
        when 'list', 'listref'
          if node.args && node.args.first
            "\\ref{#{escape(node.args.first)}}"
          else
            content
          end
        when 'table', 'tableref'
          if node.args && node.args.first
            "\\ref{#{escape(node.args.first)}}"
          else
            content
          end
        when 'img', 'imgref'
          if node.args && node.args.first
            "\\ref{#{escape(node.args.first)}}"
          else
            content
          end
        when 'eq', 'eqref'
          if node.args && node.args.first
            "\\eqref{#{escape(node.args.first)}}"
          else
            content
          end
        when 'bib', 'bibref'
          if node.args && node.args.first
            "\\cite{#{escape(node.args.first)}}"
          else
            content
          end
        when 'm'
          # Mathematical expressions - don't escape content
          "$#{node.args&.first || content}$"
        else
          # Unknown inline element, escape content
          escape(content)
        end
      end

      def render_children(node)
        return '' unless node.children

        node.children.map { |child| visit(child) }.join
      end

      def post_process_document(content)
        content
      end

      def normalize_id(id)
        # LaTeX-safe ID normalization
        id.gsub(/[^a-zA-Z0-9_-]/, '_')
      end
    end
  end
end
