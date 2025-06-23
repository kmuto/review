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

        # Add label if present
        label_part = node.label ? "\\label{#{escape(node.label)}}" : ''

        "\\#{section_command}{#{caption}}#{label_part}"
      end

      def visit_paragraph(node)
        content = render_children(node)
        "#{content}\n"
      end

      def visit_text(node)
        escape(node.content.to_s)
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
            "\\begin{reviewlistblock}\n" +
              "\\reviewlistcaption{#{caption}}\n" +
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

        # Generate column specification (all left-aligned)
        col_spec = 'l' * col_count

        result = []
        result << '\\begin{table}[h]'
        result << '\\centering'
        result << "\\begin{tabular}{#{col_spec}}"
        result << '\\hline'

        # Render header rows
        if node.header_rows.any?
          node.header_rows.each do |row|
            cells = row.children.map { |cell| render_children(cell) }
            result << "#{cells.join(' & ')} \\\\"
          end
          result << '\\hline'
        end

        # Render body rows
        if node.body_rows.any?
          node.body_rows.each do |row|
            cells = row.children.map { |cell| render_children(cell) }
            result << "#{cells.join(' & ')} \\\\"
          end
        end

        result << '\\hline'
        result << '\\end{tabular}'
        if caption && !caption.empty?
          result << "\\caption{#{caption}}"
        end
        if node.id && !node.id.empty?
          result << "\\label{#{escape(node.id)}}"
        end
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
        result << '\\begin{figure}[h]'
        result << '\\centering'
        result << "\\includegraphics{#{escape(node.id)}}"
        if caption && !caption.empty?
          result << "\\caption{#{caption}}"
        end
        if node.id && !node.id.empty?
          result << "\\label{#{escape(node.id)}}"
        end
        result << '\\end{figure}'

        result.join("\n")
      end

      def visit_list(node)
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

        content = render_children(node)
        "\\begin{#{env_name}}\n#{content}\\end{#{env_name}}\n"
      end

      def visit_list_item(node)
        content = render_children(node)
        "\\item #{content}\n"
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
        result << "\\begin{#{env_name}}"
        if caption && !caption.empty?
          result << "[#{caption}]"
        end
        result << content
        result << "\\end{#{env_name}}"

        result.join
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
          "\\textbf{#{content}}"
        when 'i', 'em'
          "\\textit{#{content}}"
        when 'tt', 'code'
          "\\texttt{#{content}}"
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
            "\\ref{#{escape(node.args.first)}}"
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
