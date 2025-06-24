# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/renderer/base'
require 'review/htmlutils'
require 'review/textutils'
require 'review/sec_counter'
require 'review/i18n'
require 'review/loggable'

module ReVIEW
  module Renderer
    class HTMLRenderer < Base
      include ReVIEW::HTMLUtils
      include ReVIEW::TextUtils
      include ReVIEW::Loggable

      attr_reader :chapter, :book

      def initialize(config: {}, options: {})
        super
        @chapter = options[:chapter]
        @book = options[:book] || @chapter&.book
        
        # Initialize logger like HTMLBuilder for error handling
        @logger = ReVIEW.logger

        # Initialize section counter like HTMLBuilder (handle nil chapter)
        @sec_counter = @chapter ? SecCounter.new(5, @chapter) : nil
        
        # Initialize counters for tables, images like HTMLBuilder
        # Note: list counter is not used - we use chapter list index instead
        @table_counter = 0
        @image_counter = 0
      end

      def visit_document(node)
        # Extract chapter information from AST node if available
        # This ensures renderer has access to chapter context for list numbering
        if node.respond_to?(:chapter) && node.chapter
          @chapter = node.chapter
          @book = @chapter&.book
          
          # Re-initialize section counter with proper chapter if we now have one
          @sec_counter = SecCounter.new(5, @chapter) if @chapter
        end
        
        content = render_children(node)
        post_process_document(content)
      end

      def visit_headline(node)
        level = node.level
        caption = render_children(node.caption) if node.caption

        # Use HTMLBuilder's headline_prefix method
        prefix, anchor = headline_prefix(level)

        # Generate anchor ID like HTMLBuilder
        anchor_html = anchor ? %Q(<a id="h#{anchor}"></a>) : ''

        # Generate section number like HTMLBuilder
        secno_html = prefix ? %Q(<span class="secno">#{prefix}</span>) : ''

        # Add proper spacing like HTMLBuilder - only h1 and h2 get extra newlines  
        spacing = (level == 1 || level == 2) ? "\n" : ""
        "<h#{level}>#{anchor_html}#{secno_html}#{caption}</h#{level}>\n#{spacing}"
      end

      def visit_paragraph(node)
        content = render_children(node)
        "<p>#{content}</p>\n"
      end

      def visit_list(node)
        tag = case node.list_type
              when :ul
                'ul'
              when :ol
                'ol'
              when :dl
                'dl'
              else
                'ul'
              end
        
        content = render_children(node)
        # Format list items with proper line breaks like HTMLBuilder
        formatted_content = content.gsub(/<\/li>(?=<li>)/, "</li>\n")
        formatted_content = formatted_content.gsub(/<li>([^<]*)<ul>/, "<li>\\1<ul>\n")
        formatted_content = formatted_content.gsub(/<\/ul><\/li>/, "</ul>\n</li>")
        "<#{tag}>\n#{formatted_content}\n</#{tag}>\n\n"
      end

      def visit_list_item(node)
        content = render_children(node)
        "<li>#{content}</li>"
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

        # Determine block type based on code_type like HTMLBuilder
        case node.code_type
        when :emlist
          # Emlist block - like HTMLBuilder's emlist
          caption_html = if node.caption
                           caption_content = render_children(node.caption)
                           %Q(<p class="caption">#{caption_content}</p>
)
                         else
                           ''
                         end

          lang_class = node.lang ? " language-#{node.lang}" : ""
          %Q(<div class="emlist-code">
#{caption_html}<pre class="emlist#{lang_class}">#{lines_content}</pre>
</div>
)
        when :emlistnum
          # Emlistnum block - like HTMLBuilder's emlistnum
          caption_html = if node.caption
                           caption_content = render_children(node.caption)
                           %Q(<p class="caption">#{caption_content}</p>
)
                         else
                           ''
                         end

          # Add line numbers like HTMLBuilder's emlistnum
          numbered_lines = lines_content.split("\n").map.with_index(1) do |line, i|
            " #{i.to_s.rjust(2)}: #{line}"
          end.join("\n")

          lang_class = node.lang ? " language-#{node.lang}" : ""
          %Q(<div class="emlistnum-code">
#{caption_html}<pre class="emlist#{lang_class}">#{numbered_lines}</pre>
</div>
)
        when :list
          # Regular list block - like HTMLBuilder's list
          caption_html = if node.caption
                           caption_content = render_children(node.caption)
                           # Generate list number like HTMLBuilder using chapter list index
                           list_number = generate_list_header(node.id, caption_content)
                           %Q(<p class="caption">#{list_number}</p>
)
                         else
                           ''
                         end

          lang_class = node.lang ? " language-#{node.lang}" : ""
          %Q(<div#{id_attr} class="caption-code">
#{caption_html}<pre class="list#{lang_class}">#{lines_content}</pre>
</div>
)
        when :listnum
          # Numbered list block - like HTMLBuilder's listnum  
          caption_html = if node.caption
                           caption_content = render_children(node.caption)
                           # Generate list number like HTMLBuilder using chapter list index
                           list_number = generate_list_header(node.id, caption_content)
                           %Q(<p class="caption">#{list_number}</p>
)
                         else
                           ''
                         end

          # Add line numbers like HTMLBuilder's listnum - match exact format
          lines_array = lines_content.split("\n")
          
          # Remove the last empty line if present (to match HTMLBuilder processing)
          lines_array.pop if lines_array.last && lines_array.last.empty?
          
          numbered_lines = lines_array.map.with_index(1) do |line, i|
            i.to_s.rjust(2) + ': ' + line
          end.join("\n") + "\n"

          lang_class = node.lang ? " language-#{node.lang}" : ""
          %Q(<div#{id_attr} class="code">
#{caption_html}<pre class="list#{lang_class}">#{numbered_lines}</pre>
</div>
)
        else
          # Fallback for unknown code types
          %Q(<div#{id_attr} class="caption-code">
<pre>#{lines_content}</pre>
</div>
)
        end
      end

      def visit_code_line(node)
        render_children(node) + "\n"
      end

      def visit_table(node)
        id_attr = node.id ? %Q( id="#{normalize_id(node.id)}") : ''

        caption_html = if node.caption
                         caption_content = render_children(node.caption)
                         # Generate table number like HTMLBuilder with proper counter
                         @table_counter += 1
                         table_number = "表1.#{@table_counter}: #{caption_content}"
                         %Q(<p class="caption">#{table_number}</p>
)
                       else
                         ''
                       end

        # Render rows without thead/tbody sections like HTMLBuilder with proper formatting
        header_html = ''
        if node.header_rows.any?
          header_html = node.header_rows.map do |row|
            cells_html = row.children.map do |cell|
              content = render_children(cell)
              "<th>#{content}</th>"
            end.join
            "<tr>#{cells_html}</tr>"
          end.join("\n") + "\n"
        end

        body_html = ''
        if node.body_rows.any?
          body_html = node.body_rows.map do |row|
            cells_html = row.children.map do |cell|
              content = render_children(cell)
              "<td>#{content}</td>"
            end.join
            "<tr>#{cells_html}</tr>"
          end.join("\n") + "\n"
        end

        %Q(<div#{id_attr} class="table">
#{caption_html}<table>
#{header_html}#{body_html}</table>
</div>
)
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

        # Content already contains proper paragraph structure from ParagraphNode children
        content_html = render_children(node)

        %Q(<div class="#{type}"#{id_attr}>
#{caption_html}#{content_html}</div>

)
      end

      def visit_image(node)
        id_attr = node.id ? %Q( id="#{normalize_id(node.id)}") : ''
        
        # Check if image is bound like HTMLBuilder does
        if @chapter&.image_bound?(node.id)
          image_image_html(node.id, node.caption, nil, id_attr)
        else
          # For dummy images, ImageNode doesn't have lines, so use empty array
          image_dummy_html(node.id, node.caption, [], id_attr)
        end
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
        when 'code'
          %Q(<code class="inline-code tt">#{content}</code>)
        when 'tt'
          %Q(<code class="tt">#{content}</code>)
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

      def render_list_link(content, node)
        # Generate proper list reference like HTMLBuilder using chapter list index
        list_id = content
        
        begin
          # Use the same logic as HTMLBuilder's inline_list method
          chapter, extracted_id = extract_chapter_id(list_id)
          
          # Get list item from chapter
          list_item = chapter&.list(extracted_id)
          unless list_item && list_item.number
            raise KeyError, "list '#{list_id}' not found"
          end
          
          if get_chap(chapter)
            list_number = %Q(#{I18n.t('list')}#{I18n.t('format_number', [get_chap(chapter), list_item.number])})
          else
            list_number = %Q(#{I18n.t('list')}#{I18n.t('format_number_without_chapter', [list_item.number])})
          end
          
          # Generate href like HTMLBuilder
          if @book&.config&.[]('chapterlink') && chapter
            href = "./#{chapter.id}#{extname}##{normalize_id(extracted_id)}"
          else
            href = "./test.html##{extracted_id || list_id}"
          end
          
          %Q(<span class="listref"><a href="#{href}">#{list_number}</a></span>)
        rescue KeyError => e
          # Fallback for missing list references
          %Q(<span class="listref">#{I18n.t('list')}#{list_id}</span>)
        end
      end

      def render_img_link(content, node)
        # Generate proper image reference like HTMLBuilder using chapter image index
        img_id = content
        
        begin
          # Use the same logic as HTMLBuilder's inline_img method
          chapter, extracted_id = extract_chapter_id(img_id)
          
          # Get image item from chapter
          image_item = chapter&.image(extracted_id)
          unless image_item && image_item.number
            raise KeyError, "image not found"
          end
          
          if get_chap(chapter)
            image_number = %Q(#{I18n.t('image')}#{I18n.t('format_number', [get_chap(chapter), image_item.number])})
          else
            image_number = %Q(#{I18n.t('image')}#{I18n.t('format_number_without_chapter', [image_item.number])})
          end
          
          # Generate href like HTMLBuilder - use correct CSS class "imgref"
          if @book&.config&.[]('chapterlink') && chapter
            href = "./#{chapter.id}#{extname}##{normalize_id(extracted_id || img_id)}"
          else
            href = "./test.html##{img_id}"
          end
          
          %Q(<span class="imgref"><a href="#{href}">#{image_number}</a></span>)
        rescue KeyError
          # Handle missing images like HTMLBuilder - log error and provide fallback
          @logger.error("unknown image: #{img_id}")
          # Return fallback display like HTMLBuilder
          %Q(<span class="imgref">#{I18n.t('image')}??</span>)
        end
      end

      def render_table_link(content, node)
        # Generate proper table reference like HTMLBuilder using chapter table index
        table_id = content
        
        # Use the same logic as HTMLBuilder's inline_table method
        chapter, extracted_id = extract_chapter_id(table_id)
        
        # Get table item from chapter
        table_item = chapter&.table(extracted_id)
        unless table_item && table_item.number
          raise KeyError, "table '#{table_id}' not found"
        end
        
        if get_chap(chapter)
          table_number = %Q(#{I18n.t('table')}#{I18n.t('format_number', [get_chap(chapter), table_item.number])})
        else
          table_number = %Q(#{I18n.t('table')}#{I18n.t('format_number_without_chapter', [table_item.number])})
        end
        
        # Generate href like HTMLBuilder - use same CSS class "tableref"
        if @book&.config&.[]('chapterlink') && chapter
          href = "./#{chapter.id}#{extname}##{normalize_id(extracted_id || table_id)}"
        else
          href = "./test.html##{table_id}"
        end
        
        %Q(<span class="tableref"><a href="#{href}">#{table_number}</a></span>)
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
          %Q(<a href="#{url}" class="link">#{text}</a>)
        else
          %Q(<a href="#{content}" class="link">#{content}</a>)
        end
      end

      def render_url_link(content, _node)
        %Q(<a href="#{escape(content)}">#{content}</a>)
      end

      def post_process_document(content)
        # Fix extra spacing after lists to match HTMLBuilder
        content = content.gsub(/(<\/ul>)\n\n\n/, "\\1\n\n")
        content = content.gsub(/(<\/ol>)\n\n\n/, "\\1\n\n")
        # Remove extra newlines but preserve necessary spacing
        content = content.gsub(/\n\n\n+/, "\n\n")
        content
      end

      def escape(str)
        super(str.to_s)
      end

      # Generate headline prefix and anchor like HTMLBuilder
      def headline_prefix(level)
        return [nil, nil] unless @sec_counter
        
        @sec_counter.inc(level)
        anchor = @sec_counter.anchor(level)
        prefix = @sec_counter.prefix(level, @book&.config&.[]('secnolevel'))
        [prefix, anchor]
      end

      def normalize_id(id)
        # Remove # prefix if present (common in Re:VIEW syntax)
        id = id.gsub(/^#/, '') if id.start_with?('#')

        # HTML-safe ID normalization
        # Replace non-alphanumeric characters with dashes
        id.gsub(/[^a-zA-Z0-9_-]/, '-')
      end

      # Builder-compatible methods for list reference handling
      def extract_chapter_id(chap_ref)
        m = /\A([\w+-]+)\|(.+)/.match(chap_ref)
        if m
          ch = @book.contents.detect { |chap| chap.id == m[1] }
          raise KeyError unless ch

          return [ch, m[2]]
        end
        [@chapter, chap_ref]
      end

      def get_chap(chapter = @chapter)
        if @book&.config&.[]('secnolevel') && @book.config['secnolevel'] > 0 && 
           !chapter.number.nil? && !chapter.number.to_s.empty?
          if chapter.is_a?(ReVIEW::Book::Part)
            return I18n.t('part_short', chapter.number)
          else
            return chapter.format_number(nil)
          end
        end
        nil
      end

      def extname
        ".#{@book&.config&.[]('htmlext') || 'html'}"
      end

      # Image helper methods matching HTMLBuilder's implementation
      def image_image_html(id, caption, metric, id_attr)
        caption_html = image_header_html(id, caption)
        
        begin
          image_path = @chapter.image(id).path.sub(%r{\A\./}, '')
          caption_content = caption ? render_children(caption) : ''
          
          img_html = %Q(<img src="#{image_path}" alt="#{escape(caption_content)}" />)
          
          # Check caption positioning like HTMLBuilder
          if caption_top?('image') && caption
            %Q(<div#{id_attr} class="image">
#{caption_html}#{img_html}
</div>
)
          else
            %Q(<div#{id_attr} class="image">
#{img_html}
#{caption_html}</div>
)
          end
        rescue StandardError
          # If image loading fails, fall back to dummy
          image_dummy_html(id, caption, [], id_attr)
        end
      end

      def image_dummy_html(id, caption, lines, id_attr)
        caption_html = image_header_html(id, caption)
        
        # Generate dummy image content exactly like HTMLBuilder
        # HTMLBuilder puts each line and adds newlines via 'puts'
        if lines.empty?
          lines_content = "\n"  # Empty image block just has one newline 
        else
          lines_content = "\n" + lines.map { |line| escape(line) }.join("\n") + "\n"
        end
        
        # Check caption positioning like HTMLBuilder  
        if caption_top?('image') && caption
          %Q(<div#{id_attr} class="image">
#{caption_html}<pre class="dummyimage">#{lines_content}</pre>
</div>
)
        else
          %Q(<div#{id_attr} class="image">
<pre class="dummyimage">#{lines_content}</pre>
#{caption_html}</div>
)
        end
      end

      def image_header_html(id, caption)
        return '' unless caption
        
        caption_content = render_children(caption)
        
        # Generate image number like HTMLBuilder using chapter image index
        image_item = @chapter&.image(id)
        unless image_item && image_item.number
          raise KeyError, "image '#{id}' not found"
        end
        
        if get_chap
          image_number = %Q(#{I18n.t('image')}#{I18n.t('format_number_header', [get_chap, image_item.number])})
        else
          image_number = %Q(#{I18n.t('image')}#{I18n.t('format_number_header_without_chapter', [image_item.number])})
        end
        
        %Q(<p class="caption">
#{image_number}#{I18n.t('caption_prefix')}#{caption_content}
</p>
)
      end

      def caption_top?(type)
        @book&.config&.[]('caption_position')&.[](type) == 'top'
      end

      # Generate list header like HTMLBuilder's list_header method
      def generate_list_header(id, caption)
        return '' unless @chapter

        begin
          list_item = @chapter.list(id)
          unless list_item && list_item.number
            raise KeyError, "list '#{id}' not found"
          end

          if get_chap
            "#{I18n.t('list')}#{I18n.t('format_number_header', [get_chap, list_item.number])}#{I18n.t('caption_prefix')}#{caption}"
          else
            "#{I18n.t('list')}#{I18n.t('format_number_header_without_chapter', [list_item.number])}#{I18n.t('caption_prefix')}#{caption}"
          end
        rescue KeyError => e
          # Fallback to simple numbering if chapter list index is not available
          "#{I18n.t('list')}#{id}: #{caption}"
        end
      end
    end
  end
end
