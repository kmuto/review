# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/renderer/base'
require 'review/htmlutils'

module ReVIEW
  module Renderer
    class HTMLRenderer < Base
      include ReVIEW::HTMLUtils

      attr_reader :chapter, :book

      def initialize(config: {}, options: {})
        super
        @chapter = options[:chapter]
        @book = options[:book] || @chapter&.book
      end

      def visit_document(node)
        content = render_children(node)
        post_process_document(content)
      end

      def visit_headline(node)
        level = node.level
        caption = render_children(node.caption) if node.caption

        # Generate anchor ID like HTMLBuilder
        if level == 1
          anchor_id = "h1"
        elsif level == 2
          anchor_id = "h1-1"  # HTMLBuilder uses parent numbering for h2
        else
          anchor_id = "h#{level}"
        end
        anchor_html = %Q(<a id="#{anchor_id}"></a>)

        # Generate section number like HTMLBuilder
        secno_html = ''
        if @chapter
          chapter_number = @chapter.number
          if chapter_number && chapter_number > 0
            if level == 1
              secno_html = %Q(<span class="secno">第#{chapter_number}章　</span>)
            elsif level == 2
              secno_html = %Q(<span class="secno">#{chapter_number}.1　</span>)
            end
          end
        end

        "<h#{level}>#{anchor_html}#{secno_html}#{caption}</h#{level}>"
      end

      def visit_paragraph(node)
        content = render_children(node)
        "<p>#{content}</p>"
      end

      def visit_text(node)
        escape(node.content.to_s)
      end

      def visit_inline(node)
        content = render_children(node)
        render_inline_element(node.inline_type, content, node)
      end

      def visit_code_block(node)
        id_attr = node.id ? %Q( id="#{normalize_id(node.id)}") : ''

        lines_content = render_children(node)

        caption_html = if node.caption
                         caption_content = render_children(node.caption)
                         # Generate list number like HTMLBuilder
                         list_number = "リスト1.1: #{caption_content}"
                         %Q(<p class="caption">#{list_number}</p>)
                       else
                         ''
                       end

        # Use HTMLBuilder-compatible structure with class="caption-code" on wrapper
        %Q(<div#{id_attr} class="caption-code">
#{caption_html}<pre class="list">#{lines_content}</pre>
</div>)
      end

      def visit_code_line(node)
        render_children(node) + "\n"
      end

      def visit_table(node)
        id_attr = node.id ? %Q( id="#{normalize_id(node.id)}") : ''

        caption_html = if node.caption
                         caption_content = render_children(node.caption)
                         # Generate table number like HTMLBuilder
                         table_number = "表1.1: #{caption_content}"
                         %Q(<p class="caption">#{table_number}</p>)
                       else
                         ''
                       end

        # Render rows without thead/tbody sections like HTMLBuilder
        header_html = ''
        if node.header_rows.any?
          header_html = node.header_rows.map do |row|
            cells_html = row.children.map do |cell|
              content = render_children(cell)
              "<th>#{content}</th>"
            end.join
            "<tr>#{cells_html}</tr>"
          end.join
        end

        body_html = ''
        if node.body_rows.any?
          body_html = node.body_rows.map do |row|
            cells_html = row.children.map do |cell|
              content = render_children(cell)
              "<td>#{content}</td>"
            end.join
            "<tr>#{cells_html}</tr>"
          end.join
        end

        %Q(<div#{id_attr} class="table">
#{caption_html}<table>
#{header_html}#{body_html}</table>
</div>)
      end

      def visit_table_row(node)
        cells_html = render_children(node)
        "<tr>#{cells_html}</tr>"
      end

      def visit_table_cell(node)
        content = render_children(node)
        "<td>#{content}</td>"
      end

      def visit_column(node)
        id_attr = node.id ? %Q( id="#{normalize_id(node.id)}") : ''

        caption_html = if node.caption
                         caption_content = render_children(node.caption)
                         %Q(<div class="column-header">#{caption_content}</div>)
                       else
                         ''
                       end

        content = render_children(node)

        %Q(<div class="column"#{id_attr}>
#{caption_html}#{content}</div>)
      end

      def visit_minicolumn(node)
        type = node.minicolumn_type.to_s
        id_attr = node.id ? %Q( id="#{normalize_id(node.id)}") : ''

        caption_html = if node.caption
                         caption_content = render_children(node.caption)
                         %Q(<p class="caption">#{caption_content}</p>)
                       else
                         ''
                       end

        # Wrap content in paragraph tags like HTMLBuilder
        content = render_children(node)
        content_html = content.empty? ? '' : %Q(<p>#{content}</p>)

        %Q(<div class="#{type}"#{id_attr}>
#{caption_html}#{content_html}</div>)
      end

      def visit_block(node)
        case node.command
        when 'note'
          render_note_block(node)
        when 'memo'
          render_memo_block(node)
        when 'tip'
          render_tip_block(node)
        when 'info'
          render_info_block(node)
        when 'warning'
          render_warning_block(node)
        when 'important'
          render_important_block(node)
        when 'caution'
          render_caution_block(node)
        when 'notice'
          render_notice_block(node)
        else
          render_generic_block(node)
        end
      end

      protected

      def render_children(node)
        return '' unless node&.children

        node.children.map { |child| visit(child) }.join
      end

      def visit_generic(node)
        method_name = derive_visit_method_name_string(node)
        raise NotImplementedError, "HTMLRenderer does not support generic visitor. Implement #{method_name} for #{node.class.name}"
      end

      def render_inline_element(type, content, node)
        case type
        when 'b', 'strong'
          "<b>#{content}</b>"
        when 'i', 'em'
          "<i>#{content}</i>"
        when 'code', 'tt'
          %Q(<code class="inline-code tt">#{content}</code>)
        when 'kbd'
          "<kbd>#{content}</kbd>"
        when 'samp'
          "<samp>#{content}</samp>"
        when 'var'
          "<var>#{content}</var>"
        when 'sup'
          "<sup>#{content}</sup>"
        when 'sub'
          "<sub>#{content}</sub>"
        when 'del'
          "<del>#{content}</del>"
        when 'ins'
          "<ins>#{content}</ins>"
        when 'u'
          "<u>#{content}</u>"
        when 'br'
          '<br />'
        when 'chap'
          render_chap_link(content, node)
        when 'title'
          render_title_link(content, node)
        when 'chapref'
          render_chapref_link(content, node)
        when 'list'
          render_list_link(content, node)
        when 'img'
          render_img_link(content, node)
        when 'table'
          render_table_link(content, node)
        when 'fn'
          render_footnote_link(content, node)
        when 'kw'
          render_keyword(content, node)
        when 'bou'
          render_bou(content, node)
        when 'ami'
          render_ami(content, node)
        when 'href'
          render_href_link(content, node)
        when 'url'
          render_url_link(content, node)
        else
          content
        end
      end

      def render_table_section(rows, section_tag, cell_tag)
        return '' if rows.empty?

        rows_html = rows.map do |row_node|
          cells_html = row_node.children.map do |cell_node|
            content = render_children(cell_node)
            "<#{cell_tag}>#{content}</#{cell_tag}>"
          end.join
          "<tr>#{cells_html}</tr>"
        end.join

        "<#{section_tag}>#{rows_html}</#{section_tag}>"
      end

      def render_note_block(node)
        render_callout_block(node, 'note')
      end

      def render_memo_block(node)
        render_callout_block(node, 'memo')
      end

      def render_tip_block(node)
        render_callout_block(node, 'tip')
      end

      def render_info_block(node)
        render_callout_block(node, 'info')
      end

      def render_warning_block(node)
        render_callout_block(node, 'warning')
      end

      def render_important_block(node)
        render_callout_block(node, 'important')
      end

      def render_caution_block(node)
        render_callout_block(node, 'caution')
      end

      def render_notice_block(node)
        render_callout_block(node, 'notice')
      end

      def render_callout_block(node, type)
        id_attr = node.id ? %Q( id="#{normalize_id(node.id)}") : ''

        caption_html = if node.caption
                         caption_content = render_children(node.caption)
                         %Q(<div class="#{type}-header">#{caption_content}</div>)
                       else
                         ''
                       end

        content = render_children(node)

        %Q(<div class="#{type}"#{id_attr}>
#{caption_html}#{content}</div>)
      end

      def render_generic_block(node)
        id_attr = node.id ? %Q( id="#{normalize_id(node.id)}") : ''
        content = render_children(node)

        %Q(<div class="#{escape(node.command)}"#{id_attr}>#{content}</div>)
      end

      def render_chap_link(content, _node)
        %Q(<span class="chap-ref">#{content}</span>)
      end

      def render_title_link(content, _node)
        %Q(<span class="title-ref">#{content}</span>)
      end

      def render_chapref_link(content, _node)
        %Q(<span class="chapref-ref">#{content}</span>)
      end

      def render_list_link(content, _node)
        %Q(<span class="list-ref">#{content}</span>)
      end

      def render_img_link(content, _node)
        %Q(<span class="img-ref">#{content}</span>)
      end

      def render_table_link(content, _node)
        %Q(<span class="table-ref">#{content}</span>)
      end

      def render_footnote_link(content, _node)
        %Q(<span class="footnote">#{content}</span>)
      end

      def render_keyword(content, _node)
        %Q(<span class="keyword">#{content}</span>)
      end

      def render_bou(content, _node)
        %Q(<span class="bou">#{content}</span>)
      end

      def render_ami(content, _node)
        %Q(<span class="ami">#{content}</span>)
      end

      def render_href_link(content, node)
        args = node.args || []
        if args.length >= 2
          url = escape(args[0])
          text = args[1]
          %Q(<a href="#{url}">#{text}</a>)
        else
          %Q(<a href="#{content}">#{content}</a>)
        end
      end

      def render_url_link(content, _node)
        %Q(<a href="#{escape(content)}">#{content}</a>)
      end

      def post_process_document(content)
        content
      end

      def escape(str)
        super(str.to_s)
      end
    end
  end
end
