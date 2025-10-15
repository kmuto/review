# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/renderer/base'
require 'review/renderer/rendering_context'
require 'review/htmlutils'
require 'review/textutils'
require 'review/escape_utils'
require 'review/highlighter'
require 'review/sec_counter'
require 'review/i18n'
require 'review/loggable'
require 'review/ast/indexer'
require 'review/ast/compiler'
require 'review/template'

module ReVIEW
  module Renderer
    class HtmlRenderer < Base
      include ReVIEW::HTMLUtils
      include ReVIEW::TextUtils
      include ReVIEW::EscapeUtils
      include ReVIEW::Loggable

      attr_reader :chapter, :book

      def initialize(chapter)
        super

        # Initialize logger like HTMLBuilder for error handling
        @logger = ReVIEW.logger

        # Initialize section counter like HTMLBuilder (handle nil chapter)
        @sec_counter = @chapter ? SecCounter.new(5, @chapter) : nil

        # Initialize counters for tables, images like HTMLBuilder
        # Note: list counter is not used - we use chapter list index instead
        @table_counter = 0
        @image_counter = 0
        @first_line_num = nil # For line numbering like HTMLBuilder

        # Flag to track if indexes have been generated using AST::Indexer
        @ast_indexes_generated = false

        # Initialize template variables like HTMLBuilder
        @javascripts = []
        @body_ext = ''

        # Initialize RenderingContext for cleaner state management
        @rendering_context = RenderingContext.new(:document)
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

        # Generate indexes using AST::Indexer (builder-independent approach)
        generate_ast_indexes(node)

        # Generate body content only, like HTMLBuilder
        # The complete HTML document structure (html, head, body tags)
        # is handled by templates/html/layout-html5.html.erb
        render_children(node)
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

        # Add proper spacing like HTMLBuilder (disabled)
        spacing_before = ''
        spacing_after = ''
        "#{spacing_before}<h#{level}>#{anchor_html}#{secno_html}#{caption}</h#{level}>#{spacing_after}\n"
      end

      def visit_paragraph(node)
        content = render_children(node)
        # Remove newlines for HTMLBuilder compatibility
        content = content.gsub(/\n+/, '').strip

        # Check for noindent attribute
        if node.attribute?(:noindent)
          %Q(<p class="noindent">#{content}</p>\n)
        else
          "<p>#{content}</p>\n"
        end
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
                raise NotImplementedError, "HTMLRenderer does not support list_type #{node.list_type}."
              end

        # Check for start_number attribute for ordered lists
        start_attr = ''
        if node.list_type == :ol && node.attribute?(:start_number)
          start_num = node.fetch_attribute(:start_number)
          start_attr = %Q( start="#{start_num}")
        end

        content = render_children(node)
        # Format list items with proper line breaks like HTMLBuilder
        formatted_content = content.gsub(%r{</li>(?=<li>)}, "</li>\n")
        formatted_content = formatted_content.gsub(/<li>([^<]*)<ul>/, "<li>\\1<ul>\n")
        formatted_content = formatted_content.gsub('</ul></li>', "</ul>\n</li>")
        "<#{tag}#{start_attr}>\n#{formatted_content}\n</#{tag}>\n"
      end

      def visit_list_item(node)
        # Get parent list to determine list type
        parent_list = node.parent
        if parent_list && parent_list.list_type == :dl
          # Definition list item - first child is term, rest are definitions
          if node.children && node.children.length >= 2
            # First child is the term (dt)
            term = visit(node.children[0])
            dt_element = "<dt>#{term}</dt>"

            # Rest are definitions (dd elements)
            definitions = node.children[1..-1].map do |child|
              definition_content = visit(child)
              "<dd>#{definition_content}</dd>"
            end

            dt_element + definitions.join
          elsif node.children && node.children.length == 1
            # Only term, no definition
            term = visit(node.children[0])
            "<dt>#{term}</dt>"
          else
            # Fallback to content
            "<dt>#{escape_content(node.content.to_s)}</dt>"
          end
        else
          # Regular list item
          content = render_children(node)
          "<li>#{content}</li>"
        end
      end

      def visit_text(node)
        escape_content(node.content.to_s)
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
          # Emlist block - like HTMLBuilder's emlist with proper detab and line processing
          caption_html = if node.caption && caption_top?('list')
                           caption_content = render_children(node.caption)
                           %Q(<p class="caption">#{caption_content}</p>\n)
                         else
                           ''
                         end

          caption_bottom_html = if node.caption && !caption_top?('list')
                                  caption_content = render_children(node.caption)
                                  %Q(<p class="caption">#{caption_content}</p>\n)
                                else
                                  ''
                                end

          # Process lines like HTMLBuilder with detab and proper line endings
          processed_content = process_code_lines_like_builder(lines_content, node.lang)

          lang_class = node.lang ? " language-#{node.lang}" : ''
          highlight_class = highlight? ? ' highlight' : ''
          %Q(<div class="emlist-code">\n#{caption_html}<pre class="emlist#{lang_class}#{highlight_class}">#{processed_content}</pre>\n#{caption_bottom_html}</div>\n)
        when :emlistnum
          # Emlistnum block - like HTMLBuilder's emlistnum
          caption_html = if node.caption && caption_top?('list')
                           caption_content = render_children(node.caption)
                           %Q(<p class="caption">#{caption_content}</p>\n)
                         else
                           ''
                         end

          caption_bottom_html = if node.caption && !caption_top?('list')
                                  caption_content = render_children(node.caption)
                                  %Q(<p class="caption">#{caption_content}</p>\n)
                                else
                                  ''
                                end

          # Process lines like HTMLBuilder with detab and proper line endings
          # For emlistnum, we don't highlight first, we pass raw content to line numberer
          numbered_lines = add_line_numbers_like_emlistnum(lines_content, node.lang)

          lang_class = node.lang ? " language-#{node.lang}" : ''
          highlight_class = highlight? ? ' highlight' : ''
          %Q(<div class="emlistnum-code">\n#{caption_html}<pre class="emlist#{lang_class}#{highlight_class}">#{numbered_lines}</pre>\n#{caption_bottom_html}</div>\n)
        when :list
          # Regular list block - like HTMLBuilder's list
          caption_html = if node.caption
                           caption_content = render_children(node.caption)
                           # Generate list number like HTMLBuilder using chapter list index
                           list_number = generate_list_header(node.id, caption_content)
                           %Q(<p class="caption">#{list_number}</p>\n)
                         else
                           ''
                         end

          # Process lines like HTMLBuilder with detab and proper line endings
          processed_content = process_code_lines_like_builder(lines_content, node.lang)

          lang_class = node.lang ? " language-#{node.lang}" : ''
          highlight_class = highlight? ? ' highlight' : ''
          %Q(<div#{id_attr} class="caption-code">\n#{caption_html}<pre class="list#{lang_class}#{highlight_class}">#{processed_content}</pre>\n</div>\n)
        when :listnum
          # Numbered list block - like HTMLBuilder's listnum
          caption_html = if node.caption
                           caption_content = render_children(node.caption)
                           # Generate list number like HTMLBuilder using chapter list index
                           list_number = generate_list_header(node.id, caption_content)
                           %Q(<p class="caption">#{list_number}</p>\n)
                         else
                           ''
                         end

          # Process lines like HTMLBuilder with detab and proper line endings
          # For listnum, we don't highlight first, we pass raw content to line numberer
          numbered_lines = add_line_numbers_like_listnum(lines_content, node.lang)

          lang_class = node.lang ? " language-#{node.lang}" : ''
          %Q(<div#{id_attr} class="code">\n#{caption_html}<pre class="list#{lang_class}">#{numbered_lines}</pre>\n</div>\n)
        else
          # Fallback for unknown code types
          processed_content = process_code_lines_like_builder(lines_content)
          %Q(<div#{id_attr} class="caption-code">\n<pre>#{processed_content}</pre>\n</div>\n)
        end
      end

      def visit_code_line(node)
        # Process each line like HTMLBuilder - detab and preserve exact content
        line_content = render_children(node)
        detab(line_content)
      end

      def visit_table(node)
        id_attr = node.id ? %Q( id="#{normalize_id(node.id)}") : ''

        # Process caption with proper context management
        caption_html = if node.caption
                         @rendering_context.with_child_context(:caption) do |caption_context|
                           caption_content = render_children_with_context(node.caption, caption_context)
                           # Generate table number like HTMLBuilder with proper counter
                           @table_counter += 1
                           table_number = "表1.#{@table_counter}: #{caption_content}"
                           %Q(<p class="caption">#{table_number}</p>
)
                         end
                       else
                         ''
                       end

        # Process table content with table context
        table_html = @rendering_context.with_child_context(:table) do |table_context|
          # Process all table rows using visitor pattern with table context
          all_rows = node.header_rows + node.body_rows
          rows_html = all_rows.map { |row| visit_with_context(row, table_context) }.join("\n")
          rows_html += "\n" unless rows_html.empty?

          %Q(<table>
#{rows_html}</table>)
        end

        %Q(<div#{id_attr} class="table">
#{caption_html}#{table_html}
</div>
)
      end

      def visit_table_row(node)
        cells_html = render_children(node)
        "<tr>#{cells_html}</tr>"
      end

      def visit_table_cell(node)
        content = render_children(node)
        tag = node.cell_type == :th ? 'th' : 'td'
        "<#{tag}>#{content}</#{tag}>"
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
                         %Q(<p class="caption">#{caption_content}</p>
)
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

        # Process image with caption context management
        if node.caption
          @rendering_context.with_child_context(:caption) do |caption_context|
            # Check if image is bound like HTMLBuilder does
            if @chapter&.image_bound?(node.id)
              image_image_html_with_context(node.id, node.caption, nil, id_attr, caption_context)
            else
              # For dummy images, ImageNode doesn't have lines, so use empty array
              image_dummy_html_with_context(node.id, node.caption, [], id_attr, caption_context)
            end
          end
        elsif @chapter&.image_bound?(node.id)
          # No caption, no special context needed
          image_image_html(node.id, node.caption, nil, id_attr)
        else
          image_dummy_html(node.id, node.caption, [], id_attr)
        end
      end

      def visit_block(node)
        block_type = node.block_type.to_s
        case block_type
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
        when 'quote', 'blockquote'
          render_quote_block(node)
        when 'comment'
          render_comment_block(node)
        else
          render_generic_block(node)
        end
      end

      def visit_tex_equation(node)
        content = node.content

        math_format = @book.config['math_format']

        return render_texequation_body(content, math_format) unless node.id?

        id_attr = %Q( id="#{normalize_id(node.id)}")
        caption_html = if get_chap
                         if node.caption?
                           %Q(<p class="caption">#{I18n.t('equation')}#{I18n.t('format_number_header', [get_chap, @chapter.equation(node.id).number])}#{I18n.t('caption_prefix')}#{escape(node.caption)}</p>\n)
                         else
                           %Q(<p class="caption">#{I18n.t('equation')}#{I18n.t('format_number_header', [get_chap, @chapter.equation(node.id).number])}</p>\n)
                         end
                       elsif node.caption?
                         %Q(<p class="caption">#{I18n.t('equation')}#{I18n.t('format_number_header_without_chapter', [@chapter.equation(node.id).number])}#{I18n.t('caption_prefix')}#{escape(node.caption)}</p>\n)
                       else
                         %Q(<p class="caption">#{I18n.t('equation')}#{I18n.t('format_number_header_without_chapter', [@chapter.equation(node.id).number])}</p>\n)
                       end

        caption_top_html = caption_top?('equation') ? caption_html : ''
        caption_bottom_html = caption_top?('equation') ? '' : caption_html

        equation_body_html = render_texequation_body(content, math_format)

        %Q(<div#{id_attr} class="caption-equation">\n#{caption_top_html}#{equation_body_html}#{caption_bottom_html}</div>\n)
      end

      # Render equation body with appropriate format (matches HTMLBuilder's texequation_body)
      def render_texequation_body(content, math_format)
        result = %Q(<div class="equation">\n)

        result += case math_format
                  when 'mathjax'
                    # Use $$ for display mode like HTMLBuilder
                    "$$#{content.gsub('<', '\lt{}').gsub('>', '\gt{}').gsub('&', '&amp;')}$$\n"
                  when 'mathml'
                    # TODO: MathML support would require math_ml gem
                    # For now, fallback to plain text
                    %Q(<pre>#{escape(content)}\n</pre>\n)
                  when 'imgmath'
                    # TODO: Image-based math would require imgmath support
                    # For now, fallback to plain text
                    %Q(<pre>#{escape(content)}\n</pre>\n)
                  else
                    # Fallback: render as preformatted text
                    %Q(<pre>#{escape(content)}\n</pre>\n)
                  end

        result + "</div>\n"
      end

      # Get equation number for texequation blocks
      def get_equation_number(equation_id)
        if @chapter && @chapter.equation_index
          begin
            equation_number = @chapter.equation_index.number(equation_id)
            if @chapter.number
              "#{@chapter.number}.#{equation_number}"
            else
              equation_number.to_s
            end
          rescue StandardError
            # Fallback if equation not found in index
            '??'
          end
        else
          '??'
        end
      end

      # Render AST to HTML body content only (without template).
      # This method is useful for testing and comparison purposes.
      #
      # @param ast_root [Object] The root AST node to render
      # @return [String] HTML body content only
      def render_body(ast_root)
        visit(ast_root)
      end

      # Overrides Base#render to generate a complete HTML document with template.
      #
      # @return [String] Complete HTML document with template applied
      def render(ast_root)
        @body = render_body(ast_root)

        # Set up template variables like HTMLBuilder
        @title = strip_html(compile_inline(@chapter&.title || ''))
        @language = @config['language'] || 'ja'
        @stylesheets = @config['stylesheet'] || []
        @next = @chapter&.next_chapter
        @prev = @chapter&.prev_chapter
        @next_title = @next ? compile_inline(@next.title) : ''
        @prev_title = @prev ? compile_inline(@prev.title) : ''

        # Handle MathJax configuration like HTMLBuilder
        if @config['math_format'] == 'mathjax'
          @javascripts.push(%Q(<script>MathJax = { tex: { inlineMath: [['\\\\(', '\\\\)']] }, svg: { fontCache: 'global' } };</script>))
          @javascripts.push(%Q(<script type="text/javascript" id="MathJax-script" async="true" src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js"></script>))
        end

        # Render template
        ReVIEW::Template.load(layoutfile).result(binding)
      end

      def layoutfile
        # Determine layout file like HTMLBuilder
        if @config.maker == 'webmaker'
          htmldir = 'web/html'
          localfilename = 'layout-web.html.erb'
        else
          htmldir = 'html'
          localfilename = 'layout.html.erb'
        end

        htmlfilename = if @config['htmlversion'] == 5 || @config['htmlversion'].nil?
                         File.join(htmldir, 'layout-html5.html.erb')
                       else
                         File.join(htmldir, 'layout-xhtml1.html.erb')
                       end

        layout_file = File.join(@book&.basedir || '.', 'layouts', localfilename)

        # Check for custom layout file
        if File.exist?(layout_file)
          # Respect safe mode like HTMLBuilder
          if ENV['REVIEW_SAFE_MODE'].to_i & 4 > 0
            warn 'user\'s layout is prohibited in safe mode. ignored.'
            layout_file = File.expand_path(htmlfilename, ReVIEW::Template::TEMPLATE_DIR)
          end
        else
          # Use default template
          layout_file = File.expand_path(htmlfilename, ReVIEW::Template::TEMPLATE_DIR)
        end

        layout_file
      end

      protected

      # Render footnote content (must be protected for InlineElementRenderer access)
      # This method is called with explicit receiver from InlineElementRenderer
      def render_footnote_content(footnote_node)
        if footnote_node && footnote_node.respond_to?(:children)
          render_children(footnote_node)
        else
          escape(footnote_node&.content || '')
        end
      end

      private

      def render_children(node)
        return '' unless node.children

        # Special handling for CodeBlockNode - preserve line breaks
        if node.instance_of?(::ReVIEW::AST::CodeBlockNode)
          node.children.map { |child| visit(child) }.join("\n")
        else
          node.children.map { |child| visit(child) }.join
        end
      end

      def visit_reference(node)
        # Handle ReferenceNode - simply render the content
        node.content || ''
      end

      def visit_footnote(node)
        # Handle FootnoteNode - render as footnote definition
        if node.id && node.content
          %Q(<div class="footnote" id="fn-#{node.id}">#{node.content}</div>)
        else
          ''
        end
      end

      def visit_embed(node)
        # Handle embed blocks and raw commands
        case node.embed_type
        when :raw, :inline
          # Process raw embed content
          process_raw_embed(node)
        else
          # Handle legacy embed blocks
          if node.arg
            # Parse target formats from argument like Builder base class
            builders = node.arg.gsub(/^\s*\|/, '').gsub(/\|\s*$/, '').gsub(/\s/, '').split(',')
            target = target_name

            # Only output if this renderer's target is in the list
            if builders.include?(target)
              content = node.lines.join("\n")
              # For HTML output, ensure XHTML compliance for self-closing tags
              content = ensure_xhtml_compliance(content)
              return content + "\n"
            else
              return ''
            end
          else
            # No format specified, output for all formats
            content = node.lines.join("\n")
            # For HTML output, ensure XHTML compliance for self-closing tags
            content = ensure_xhtml_compliance(content)
            return content + "\n"
          end
        end
      end

      def visit_generic(node)
        method_name = derive_visit_method_name_string(node)
        raise NotImplementedError, "HTMLRenderer does not support generic visitor. Implement #{method_name} for #{node.class.name}"
      end

      def render_inline_element(type, content, node)
        require 'review/renderer/html_renderer/inline_element_renderer'
        # Always create a new inline renderer with current rendering context
        # This ensures that context changes are properly reflected
        inline_renderer = InlineElementRenderer.new(
          self,
          book: @book,
          chapter: @chapter,
          rendering_context: @rendering_context
        )
        inline_renderer.render(type, content, node)
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

      def render_quote_block(node)
        id_attr = node.id ? %Q( id="#{normalize_id(node.id)}") : ''
        content = render_children(node)
        %Q(<blockquote#{id_attr}>#{content}</blockquote>)
      end

      def render_comment_block(node)
        # ブロックcomment - draft設定時のみ表示
        return '' unless @book&.config&.[]('draft')

        content_lines = []

        # 引数があれば最初に追加
        if node.args && node.args.first && !node.args.first.empty?
          content_lines << escape(node.args.first)
        end

        # 本文を追加
        if node.content && !node.content.empty?
          body_content = render_children(node)
          content_lines << body_content unless body_content.empty?
        end

        return '' if content_lines.empty?

        content_str = content_lines.join('<br />')
        %Q(<div class="draft-comment">#{content_str}</div>)
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

        %Q(<div class="#{escape(node.block_type)}"#{id_attr}>#{content}</div>)
      end

      def render_inline_b(content, _node)
        "<b>#{content}</b>"
      end

      def render_inline_strong(content, _node)
        "<strong>#{content}</strong>"
      end

      def render_inline_i(content, _node)
        "<i>#{content}</i>"
      end

      def render_inline_em(content, _node)
        "<em>#{content}</em>"
      end

      def render_inline_code(content, _node)
        %Q(<code class="inline-code tt">#{content}</code>)
      end

      def render_inline_tt(content, _node)
        %Q(<code class="tt">#{content}</code>)
      end

      def render_chap(content, _node)
        %Q(<span class="chap-ref">#{content}</span>)
      end

      def render_title(content, _node)
        %Q(<span class="title-ref">#{content}</span>)
      end

      def render_chapref(content, _node)
        %Q(<span class="chapref-ref">#{content}</span>)
      end

      def render_list(content, _node)
        # Generate proper list reference exactly like HTMLBuilder's inline_list method
        list_id = content

        begin
          # Use exactly the same logic as HTMLBuilder's inline_list method
          chapter, extracted_id = extract_chapter_id(list_id)

          # Generate list number using the same pattern as Builder base class
          list_number = if get_chap(chapter)
                          %Q(#{I18n.t('list')}#{I18n.t('format_number', [get_chap(chapter), chapter.list(extracted_id).number])})
                        else
                          %Q(#{I18n.t('list')}#{I18n.t('format_number_without_chapter', [chapter.list(extracted_id).number])})
                        end

          # Generate href exactly like HTMLBuilder with chapterlink check
          if @book&.config&.[]('chapterlink')
            %Q(<span class="listref"><a href="./#{chapter.id}#{extname}##{normalize_id(extracted_id)}">#{list_number}</a></span>)
          else
            %Q(<span class="listref">#{list_number}</span>)
          end
        rescue KeyError
          # Use app_error for consistency with HTMLBuilder error handling
          app_error("unknown list: #{list_id}")
        end
      end

      def render_img(content, _node)
        # Generate proper image reference exactly like HTMLBuilder's inline_img method
        img_id = content

        begin
          # Use exactly the same logic as HTMLBuilder's inline_img method
          chapter, extracted_id = extract_chapter_id(img_id)

          # Generate image number using the same pattern as Builder base class
          image_number = if get_chap(chapter)
                           %Q(#{I18n.t('image')}#{I18n.t('format_number', [get_chap(chapter), chapter.image(extracted_id).number])})
                         else
                           %Q(#{I18n.t('image')}#{I18n.t('format_number_without_chapter', [chapter.image(extracted_id).number])})
                         end

          # Generate href exactly like HTMLBuilder with chapterlink check
          if @book&.config&.[]('chapterlink')
            %Q(<span class="imgref"><a href="./#{chapter.id}#{extname}##{normalize_id(extracted_id)}">#{image_number}</a></span>)
          else
            %Q(<span class="imgref">#{image_number}</span>)
          end
        rescue KeyError
          # Use app_error for consistency with HTMLBuilder error handling
          app_error("unknown image: #{img_id}")
        end
      end

      def render_inline_table(content, _node)
        # Generate proper table reference exactly like HTMLBuilder's inline_table method
        table_id = content

        begin
          # Use exactly the same logic as HTMLBuilder's inline_table method
          chapter, extracted_id = extract_chapter_id(table_id)

          # Generate table number using the same pattern as Builder base class
          table_number = if get_chap(chapter)
                           %Q(#{I18n.t('table')}#{I18n.t('format_number', [get_chap(chapter), chapter.table(extracted_id).number])})
                         else
                           %Q(#{I18n.t('table')}#{I18n.t('format_number_without_chapter', [chapter.table(extracted_id).number])})
                         end

          # Generate href exactly like HTMLBuilder with chapterlink check
          if @book&.config&.[]('chapterlink')
            %Q(<span class="tableref"><a href="./#{chapter.id}#{extname}##{normalize_id(extracted_id)}">#{table_number}</a></span>)
          else
            %Q(<span class="tableref">#{table_number}</span>)
          end
        rescue KeyError
          # Use app_error for consistency with HTMLBuilder error handling
          app_error("unknown table: #{table_id}")
        end
      end

      def render_footnote(content, node)
        # HTMLでは常にspan要素として出力
        # FootnoteCollectorは使用しないが、一貫性のためRenderingContextを認識
        if node.args && node.args.first
          footnote_id = node.args.first.to_s
          if @chapter && @chapter.footnote_index
            begin
              index_item = @chapter.footnote_index[footnote_id]
              footnote_content = if index_item.footnote_node?
                                   render_footnote_content(index_item.footnote_node)
                                 else
                                   escape(index_item.content || '')
                                 end
              %Q(<span class="footnote">#{footnote_content}</span>)
            rescue StandardError
              %Q(<span class="footnote">#{footnote_id}</span>)
            end
          else
            %Q(<span class="footnote">#{footnote_id}</span>)
          end
        else
          %Q(<span class="footnote">#{content}</span>)
        end
      end

      def render_keyword(content, node)
        # Handle multiple arguments like HTMLBuilder
        if node.args && node.args.length >= 2
          # First argument is the keyword, second is the reading/definition
          word = escape(node.args[0])
          _reading = escape(node.args[1])
        else
          # Single argument or fallback
          word = content
        end

        # Add index comment like HTMLBuilder
        %Q(<b class="kw">#{word}</b><!-- IDX:#{word} -->)
      end

      def render_bou(content, _node)
        %Q(<span class="bou">#{content}</span>)
      end

      def render_ami(content, _node)
        %Q(<span class="ami">#{content}</span>)
      end

      def render_ruby(content, node)
        # Handle ruby annotations like HTMLBuilder
        if node.args && node.args.length >= 2
          base = escape(node.args[0])
          ruby = escape(node.args[1])
          # Use I18n for bracket consistency with HTMLBuilder
          prefix = ReVIEW::I18n.t('ruby_prefix')
          postfix = ReVIEW::I18n.t('ruby_postfix')
          %Q(<ruby>#{base}<rp>#{prefix}</rp><rt>#{ruby}</rt><rp>#{postfix}</rp></ruby>)
        else
          # Fallback for malformed ruby
          content
        end
      end

      def render_math(content, node)
        # Mathematical expressions like HTMLBuilder
        math_content = if node.args && node.args.first
                         escape(node.args.first)
                       else
                         escape(content)
                       end
        %Q(<span class="equation">#{math_content}</span>)
      end

      def render_idx(content, node)
        # Index entries like HTMLBuilder - visible text + index comment
        index_term = if node.args && node.args.first
                       escape(node.args.first)
                     else
                       escape(content)
                     end
        %Q(#{index_term}<!-- IDX:#{index_term} -->)
      end

      # Line numbering for code blocks like HTMLBuilder
      def firstlinenum(num)
        @first_line_num = num.to_i
      end

      def line_num
        return 1 unless @first_line_num

        line_n = @first_line_num
        @first_line_num = nil
        line_n
      end

      def render_hidx(content, node)
        # Hidden index entries like HTMLBuilder - only index comment
        index_term = if node.args && node.args.first
                       escape(node.args.first)
                     else
                       escape(content)
                     end
        %Q(<!-- IDX:#{index_term} -->)
      end

      def render_comment(content, _node)
        # Inline comments like HTMLBuilder - conditionally render based on draft mode
        if @book&.config&.[]('draft')
          %Q(<span class="draft-comment">#{escape(content)}</span>)
        else
          '' # Don't render in non-draft mode
        end
      end

      def render_href(content, node)
        args = node.args || []
        if args.length >= 2
          url = escape(args[0])
          text = args[1]
          %Q(<a href="#{url}" class="link">#{text}</a>)
        else
          %Q(<a href="#{content}" class="link">#{content}</a>)
        end
      end

      def render_url(content, _node)
        %Q(<a href="#{escape(content)}">#{content}</a>)
      end

      def escape(str)
        # Use EscapeUtils for consistency
        escape_content(str.to_s)
      end

      # Process code lines exactly like HTMLBuilder does
      def process_code_lines_like_builder(lines_content, lang = nil)
        # HTMLBuilder uses: lines.inject('') { |i, j| i + detab(j) + "\n" }
        # We need to emulate this exact behavior to match Builder output

        lines = lines_content.split("\n")

        # Use inject pattern exactly like HTMLBuilder for consistency
        body = lines.inject('') { |i, j| i + detab(j) + "\n" }

        # Apply highlighting if enabled, otherwise return processed body
        highlight(body: body, lexer: lang, format: 'html')
      end

      # Add line numbers like HTMLBuilder's emlistnum method
      def add_line_numbers_like_emlistnum(content, lang = nil)
        # HTMLBuilder processes lines with detab first, then adds line numbers
        lines = content.split("\n")
        # Remove last empty line if present to match HTMLBuilder behavior
        lines.pop if lines.last && lines.last.empty?

        # Use inject pattern exactly like HTMLBuilder for consistency
        body = lines.inject('') { |i, j| i + detab(j) + "\n" }
        first_line_number = 1 # Default line number start

        if highlight?
          # Use highlight with line numbers like HTMLBuilder
          highlight(body: body, lexer: lang, format: 'html', linenum: true, options: { linenostart: first_line_number })
        else
          # Fallback: manual line numbering like HTMLBuilder does when highlight is off
          lines.map.with_index(first_line_number) do |line, i|
            " #{i.to_s.rjust(2)}: #{detab(line)}"
          end.join("\n") + "\n"
        end
      end

      # Add line numbers like HTMLBuilder's listnum method
      def add_line_numbers_like_listnum(content, lang = nil)
        # HTMLBuilder processes lines with detab first, then adds line numbers
        lines = content.split("\n")
        # Remove last empty line if present to match HTMLBuilder behavior
        lines.pop if lines.last && lines.last.empty?

        # Use inject pattern exactly like HTMLBuilder for consistency
        body = lines.inject('') { |i, j| i + detab(j) + "\n" }
        first_line_number = line_num || 1 # Use line_num like HTMLBuilder

        hs = highlight(body: body, lexer: lang, format: 'html', linenum: true,
                       options: { linenostart: first_line_number })

        if highlight?
          hs
        else
          # Fallback: manual line numbering like HTMLBuilder does when highlight is off
          lines.map.with_index(first_line_number) do |line, i|
            i.to_s.rjust(2) + ': ' + detab(line)
          end.join("\n") + "\n"
        end
      end

      # Tab conversion like HTMLBuilder's detab method
      def detab(str, ts = 8)
        add = 0
        len = nil
        str.gsub("\t") do
          len = ts - (($`.size + add) % ts)
          add += len - 1
          ' ' * len
        end
      end

      # Check if highlight is enabled like HTMLBuilder
      def highlight?
        highlighter.highlight?('html')
      end

      # Highlight code using the new Highlighter class
      def highlight(body:, lexer: nil, format: 'html', linenum: false, options: {}, location: nil)
        highlighter.highlight(
          body: body,
          lexer: lexer,
          format: format,
          linenum: linenum,
          options: options,
          location: location
        )
      end

      # Generate headline prefix and anchor like HTMLBuilder
      def headline_prefix(level)
        return [nil, nil] unless @sec_counter

        @sec_counter.inc(level)
        anchor = @sec_counter.anchor(level)
        prefix = @sec_counter.prefix(level, @book&.config&.[]('secnolevel'))
        [prefix, anchor]
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
      def image_image_html(id, caption, _metric, id_attr)
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

      # Context-aware version of image_image_html
      def image_image_html_with_context(id, caption, _metric, id_attr, caption_context)
        caption_html = if caption
                         image_header_html_with_context(id, caption, caption_context)
                       else
                         ''
                       end

        begin
          image_path = @chapter.image(id).path.sub(%r{\A\./}, '')
          caption_content = caption ? render_children_with_context(caption, caption_context) : ''

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
          image_dummy_html_with_context(id, caption, [], id_attr, caption_context)
        end
      end

      def image_dummy_html(id, caption, lines, id_attr)
        caption_html = image_header_html(id, caption)

        # Generate dummy image content exactly like HTMLBuilder
        # HTMLBuilder puts each line and adds newlines via 'puts'
        lines_content = if lines.empty?
                          "\n" # Empty image block just has one newline
                        else
                          "\n" + lines.map { |line| escape(line) }.join("\n") + "\n"
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

      # Context-aware version of image_dummy_html
      def image_dummy_html_with_context(id, caption, lines, id_attr, caption_context)
        caption_html = if caption
                         image_header_html_with_context(id, caption, caption_context)
                       else
                         ''
                       end

        # Generate dummy image content exactly like HTMLBuilder
        lines_content = if lines.empty?
                          "\n" # Empty image block just has one newline
                        else
                          "\n" + lines.map { |line| escape(line) }.join("\n") + "\n"
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

        image_number = if get_chap
                         %Q(#{I18n.t('image')}#{I18n.t('format_number_header', [get_chap, image_item.number])})
                       else
                         %Q(#{I18n.t('image')}#{I18n.t('format_number_header_without_chapter', [image_item.number])})
                       end

        %Q(<p class="caption">
#{image_number}#{I18n.t('caption_prefix')}#{caption_content}
</p>
)
      end

      # Context-aware version of image_header_html
      def image_header_html_with_context(id, caption, caption_context)
        return '' unless caption

        caption_content = render_children_with_context(caption, caption_context)

        # Generate image number like HTMLBuilder using chapter image index
        image_item = @chapter&.image(id)
        unless image_item && image_item.number
          raise KeyError, "image '#{id}' not found"
        end

        image_number = if get_chap
                         %Q(#{I18n.t('image')}#{I18n.t('format_number_header', [get_chap, image_item.number])})
                       else
                         %Q(#{I18n.t('image')}#{I18n.t('format_number_header_without_chapter', [image_item.number])})
                       end

        %Q(<p class="caption">
#{image_number}#{I18n.t('caption_prefix')}#{caption_content}
</p>
)
      end

      def caption_top?(type)
        @book&.config&.[]('caption_position')&.[](type) == 'top' # rubocop:disable Style/SafeNavigationChainLength
      end

      # Generate list header like HTMLBuilder's list_header method
      def generate_list_header(id, caption)
        list_item = @chapter.list(id)
        list_num = list_item.number
        chapter_num = @chapter.number

        if chapter_num
          "#{I18n.t('list')}#{I18n.t('format_number_header', [chapter_num, list_num])}#{I18n.t('caption_prefix')}#{caption}"
        else
          "#{I18n.t('list')}#{I18n.t('format_number_header_without_chapter', [list_num])}#{I18n.t('caption_prefix')}#{caption}"
        end
      rescue KeyError
        raise NotImplementedError, "no such list: #{id}"
      end

      # Generate indexes using AST::Indexer for Renderer (builder-independent)
      def generate_ast_indexes(ast_node)
        return if @ast_indexes_generated

        if @chapter
          # Use AST::Indexer to generate indexes directly from AST
          @ast_indexer = ReVIEW::AST::Indexer.new(@chapter)
          @ast_indexer.build_indexes(ast_node)
        end

        # Generate book-level indexes if book is available
        # This handles bib files and chapter index creation
        if @book && @book.respond_to?(:generate_indexes)
          @book.generate_indexes
        end

        @ast_indexes_generated = true
      end

      def highlighter
        @highlighter ||= ReVIEW::Highlighter.new(@book&.config || {})
      end

      # Helper methods for template variables
      def strip_html(content)
        content.to_s.gsub(/<[^>]*>/, '')
      end

      def compile_inline(content)
        # Simple inline compilation for template use
        return '' if content.nil? || content.empty?

        content.to_s
      end

      def render_inline_raw(content, node)
        # Handle inline raw elements - delegate to visit_embed for EmbedNode
        if node.respond_to?(:embed_type) && (node.embed_type == :inline || node.embed_type == :raw)
          return visit_embed(node)
        end

        # Legacy fallback for old-style inline raw
        if node.args && node.args.first
          raw_content = node.args.first
          # Parse target formats from argument like Builder base class
          if raw_content.start_with?('|') && raw_content.include?('|')
            # Format: |html|<content>
            parts = raw_content.split('|', 3)
            if parts.size >= 3
              target_format = parts[1]
              actual_content = parts[2]

              # Only output if this renderer's target matches
              if target_format == target_name
                return actual_content
              else
                return ''
              end
            end
          end
        end

        # Fallback to content if no format specified
        content
      end

      # Process raw embed content (//raw and @<raw>)
      def process_raw_embed(node)
        # Check if content should be output for this renderer
        return '' unless node.targeted_for?('html')

        # Get processed content and convert \\n to actual newlines
        content = node.content || ''
        processed_content = content.gsub('\\n', "\n")

        # Apply XHTML compliance for HTML output
        ensure_xhtml_compliance(processed_content)
      end

      # Ensure XHTML compliance for self-closing tags
      def ensure_xhtml_compliance(content)
        content.gsub(/<hr(\s[^>]*)?>/, '<hr\1 />').
          gsub(/<br(\s[^>]*)?>/, '<br\1 />').
          gsub(%r{<img([^>]*[^/])>}, '<img\1 />').
          gsub(%r{<input([^>]*[^/])>}, '<input\1 />')
      end

      # Builder compatibility - return target name for embed blocks
      def target_name
        'html'
      end

      # Render children with specific rendering context
      def render_children_with_context(node, context)
        old_context = @rendering_context
        @rendering_context = context
        result = render_children(node)
        @rendering_context = old_context
        result
      end

      # Visit node with specific rendering context
      def visit_with_context(node, context)
        old_context = @rendering_context
        @rendering_context = context
        result = visit(node)
        @rendering_context = old_context
        result
      end

      # Generate HTML footnotes from collected footnotes
      # @param collector [FootnoteCollector] the footnote collector
      # @return [String] HTML footnote output
      def generate_footnotes_from_collector(collector)
        return '' unless collector.any?

        footnote_items = collector.map do |entry|
          content = render_footnote_content(entry.node)
          %Q(<div class="footnote" id="fn#{entry.number}">#{content}</div>)
        end

        %Q(<div class="footnotes">#{footnote_items.join("\n")}</div>)
      end

      # Render headline reference
      def render_headline_ref(content, _node)
        %Q(<span class="headline-ref">#{escape_content(content)}</span>)
      end

      # Render section reference
      def render_section_ref(content, _node)
        %Q(<span class="section-ref">#{escape_content(content)}</span>)
      end

      # Render label reference
      def render_label_ref(content, _node)
        %Q(<span class="label-ref">#{escape_content(content)}</span>)
      end
    end
  end
end
