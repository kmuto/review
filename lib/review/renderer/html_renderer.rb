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

        # Generate body content only
        render_children(node)
      end

      def visit_headline(node)
        level = node.level
        caption = render_children(node.caption) if node.caption

        if node.nonum? || node.notoc? || node.nodisp?
          @nonum_counter ||= 0
          @nonum_counter += 1

          id = if node.label
                 normalize_id(node.label)
               else
                 # Auto-generate ID like HTMLBuilder: test_nonum1, test_nonum2, etc.
                 chapter_name = @chapter&.name || 'test'
                 normalize_id("#{chapter_name}_nonum#{@nonum_counter}")
               end

          spacing_before = level > 1 ? "\n" : ''

          if node.nodisp?
            a_tag = %Q(<a id="#{id}" />)
            %Q(#{spacing_before}#{a_tag}<h#{level} id="#{id}" hidden="true">#{caption}</h#{level}>\n)
          elsif node.notoc?
            %Q(#{spacing_before}<h#{level} id="#{id}" notoc="true">#{caption}</h#{level}>\n)
          else
            %Q(#{spacing_before}<h#{level} id="#{id}">#{caption}</h#{level}>\n)
          end
        else
          prefix, anchor = headline_prefix(level)

          anchor_html = anchor ? %Q(<a id="h#{anchor}"></a>) : ''
          secno_html = prefix ? %Q(<span class="secno">#{prefix}</span>) : ''
          spacing_before = level > 1 ? "\n" : ''

          if node.label
            label_id = normalize_id(node.label)
            %Q(#{spacing_before}<h#{level} id="#{label_id}">#{anchor_html}#{secno_html}#{caption}</h#{level}>\n)
          else
            "#{spacing_before}<h#{level}>#{anchor_html}#{secno_html}#{caption}</h#{level}>\n"
          end
        end
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
          # Definition list item - use term_children for term like LaTeXRenderer
          term = if node.term_children&.any?
                   node.term_children.map { |child| visit(child) }.join
                 else
                   ''
                 end

          # Children contain the definition content
          # Join all children into a single dd like HTMLBuilder does with join_lines_to_paragraph
          if node.children.empty?
            # Only term, no definition - add empty dd like HTMLBuilder
            "<dt>#{term}</dt><dd></dd>"
          else
            # Render all child content and join together
            definition_parts = node.children.map { |child| visit(child) }
            # Join multiple paragraphs/text into single dd content, removing <p> tags
            definition_content = definition_parts.map { |part| part.gsub(%r{</?p[^>]*>}, '').strip }.join
            "<dt>#{term}</dt><dd>#{definition_content}</dd>"
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
        when :source
          # Source block - like HTMLBuilder's source
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

          processed_content = process_code_lines_like_builder(lines_content, node.lang)
          # HTMLBuilder doesn't add language class to source blocks
          %Q(<div#{id_attr} class="source-code">\n#{caption_html}<pre class="source">#{processed_content}</pre>\n#{caption_bottom_html}</div>\n)
        when :cmd
          # Cmd block - like HTMLBuilder's cmd
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

          processed_content = process_code_lines_like_builder(lines_content, node.lang)
          %Q(<div#{id_attr} class="cmd-code">\n#{caption_html}<pre class="cmd">#{processed_content}</pre>\n#{caption_bottom_html}</div>\n)
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
        # Check if this is an imgtable - handle as image like HTMLBuilder
        if node.table_type == :imgtable
          return render_imgtable(node)
        end

        id_attr = node.id ? %Q( id="#{normalize_id(node.id)}") : ''

        # Process caption with proper context management
        caption_html = if node.caption
                         @rendering_context.with_child_context(:caption) do |caption_context|
                           caption_content = render_children_with_context(node.caption, caption_context)
                           # Generate table number like HTMLBuilder using chapter table index
                           table_number = if node.id
                                            generate_table_header(node.id, caption_content)
                                          else
                                            # No ID - just use caption without numbering
                                            caption_content
                                          end
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
        # HTMLBuilder uses column counter for anchor IDs
        @column_counter ||= 0
        @column_counter += 1

        id_attr = node.label ? %Q( id="#{normalize_id(node.label)}") : ''
        anchor_id = %Q(<a id="column-#{@column_counter}"></a>)

        # HTMLBuilder uses h4 tag for column headers
        caption_html = if node.caption
                         caption_content = render_children(node.caption)
                         if node.label
                           %Q(<h4#{id_attr}>#{anchor_id}#{caption_content}</h4>)
                         else
                           %Q(<h4>#{anchor_id}#{caption_content}</h4>)
                         end
                       else
                         node.label ? anchor_id : ''
                       end

        content = render_children(node)

        %Q(<div class="column">\n#{caption_html}#{content}</div>)
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

        %Q(<div class="#{type}"#{id_attr}>\n#{caption_html}#{content_html}</div>\n)
      end

      def visit_image(node)
        id_attr = node.id ? %Q( id="#{normalize_id(node.id)}") : ''

        # Process image with caption context management
        if node.caption
          @rendering_context.with_child_context(:caption) do |caption_context|
            # Check if image is bound like HTMLBuilder does
            if @chapter&.image_bound?(node.id)
              image_image_html_with_context(node.id, node.caption, nil, id_attr, caption_context, node.image_type)
            else
              # For dummy images, ImageNode doesn't have lines, so use empty array
              image_dummy_html_with_context(node.id, node.caption, [], id_attr, caption_context, node.image_type)
            end
          end
        elsif @chapter&.image_bound?(node.id)
          # No caption, no special context needed
          image_image_html(node.id, node.caption, nil, id_attr, node.image_type)
        else
          image_dummy_html(node.id, node.caption, [], id_attr, node.image_type)
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
        when 'firstlinenum'
          # Set line number for next code block, no HTML output
          render_firstlinenum_block(node)
        when 'blankline'
          # Blank line control - no HTML output in most contexts
          ''
        when 'pagebreak'
          # Page break - for HTML, output a div that can be styled
          %Q(<div class="pagebreak"></div>\n)
        when 'label'
          # Label creates an anchor
          render_label_block(node)
        when 'tsize'
          # Table size control - output as div for styling
          render_tsize_block(node)
        when 'printendnotes'
          # Print collected endnotes
          render_printendnotes_block(node)
        when 'flushright'
          # Right-align text like HTMLBuilder
          render_flushright_block(node)
        when 'centering'
          # Center-align text like HTMLBuilder
          render_centering_block(node)
        else
          render_generic_block(node)
        end
      end

      def visit_tex_equation(node)
        content = node.content

        math_format = config['math_format']

        return render_texequation_body(content, math_format) unless node.id?

        id_attr = %Q( id="#{normalize_id(node.id)}")
        caption_html = if get_chap
                         if node.caption?
                           caption_content = render_children(node.caption)
                           %Q(<p class="caption">#{I18n.t('equation')}#{I18n.t('format_number_header', [get_chap, @chapter.equation(node.id).number])}#{I18n.t('caption_prefix')}#{caption_content}</p>\n)
                         else
                           %Q(<p class="caption">#{I18n.t('equation')}#{I18n.t('format_number_header', [get_chap, @chapter.equation(node.id).number])}</p>\n)
                         end
                       elsif node.caption?
                         caption_content = render_children(node.caption)
                         %Q(<p class="caption">#{I18n.t('equation')}#{I18n.t('format_number_header_without_chapter', [@chapter.equation(node.id).number])}#{I18n.t('caption_prefix')}#{caption_content}</p>\n)
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
                  when 'imgmath' # rubocop:disable Lint/DuplicateBranch
                    # TODO: Image-based math would require imgmath support
                    # For now, fallback to plain text
                    %Q(<pre>#{escape(content)}\n</pre>\n)
                  else # rubocop:disable Lint/DuplicateBranch
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
        @language = config['language'] || 'ja'
        @stylesheets = config['stylesheet'] || []
        @next = @chapter&.next_chapter
        @prev = @chapter&.prev_chapter
        @next_title = @next ? compile_inline(@next.title) : ''
        @prev_title = @prev ? compile_inline(@prev.title) : ''

        # Handle MathJax configuration like HTMLBuilder
        if config['math_format'] == 'mathjax'
          @javascripts.push(%Q(<script>MathJax = { tex: { inlineMath: [['\\\\(', '\\\\)']] }, svg: { fontCache: 'global' } };</script>))
          @javascripts.push(%Q(<script type="text/javascript" id="MathJax-script" async="true" src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js"></script>))
        end

        # Render template
        ReVIEW::Template.load(layoutfile).result(binding)
      end

      def layoutfile
        # Determine layout file like HTMLBuilder
        if config.maker == 'webmaker'
          htmldir = 'web/html'
          localfilename = 'layout-web.html.erb'
        else
          htmldir = 'html'
          localfilename = 'layout.html.erb'
        end

        htmlfilename = if config['htmlversion'] == 5 || config['htmlversion'].nil?
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

      # Render footnote content (must be protected for InlineElementRenderer access)
      # This method is called with explicit receiver from InlineElementRenderer
      def render_footnote_content(footnote_node)
        render_children(footnote_node)
      end

      # Public methods for inline element rendering
      # These methods need to be accessible from InlineElementRenderer

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
          if config['chapterlink']
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
          if config['chapterlink']
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
          if config['chapterlink']
            %Q(<span class="tableref"><a href="./#{chapter.id}#{extname}##{normalize_id(extracted_id)}">#{table_number}</a></span>)
          else
            %Q(<span class="tableref">#{table_number}</span>)
          end
        rescue KeyError
          # Use app_error for consistency with HTMLBuilder error handling
          app_error("unknown table: #{table_id}")
        end
      end

      # Configuration accessor - returns book config or empty hash for nil safety
      # This follows the Builder pattern of accessing @book.config directly
      def config
        @book&.config || {}
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
        content = node.content || ''
        # Debug: Check what content is being rendered for list references
        if content.include?('pre01') || content == 'pre01'
          warn "DEBUG visit_reference: content = '#{content.inspect}', resolved = #{node.resolved?}, ref_id = '#{node.ref_id}', context_id = '#{node.context_id}'"
        end
        content
      end

      def visit_footnote(node)
        # Handle FootnoteNode - render as footnote or endnote definition
        # Note: This renders the footnote/endnote definition block at document level.
        # For inline footnote references (@<fn>{id}), see render_footnote method.
        footnote_content = render_children(node)

        # Check if this is a footnote or endnote based on footnote_type attribute
        if node.footnote_type == :endnote
          # Endnote - skip rendering here, will be rendered by printendnotes
          return ''
        end

        # Match HTMLBuilder's footnote output format
        footnote_number = @chapter&.footnote(node.id)&.number || '??'

        # Check epubversion for consistent output with HTMLBuilder
        if config['epubversion'].to_i == 3
          # EPUB3 version with epub:type attributes
          # Only add back link if epubmaker/back_footnote is configured (like HTMLBuilder)
          back_link = ''
          if config['epubmaker'] && config['epubmaker']['back_footnote']
            back_link = %Q(<a href="#fnb-#{normalize_id(node.id)}">#{I18n.t('html_footnote_backmark')}</a>)
          end
          %Q(<div class="footnote" epub:type="footnote" id="fn-#{normalize_id(node.id)}"><p class="footnote">#{back_link}#{I18n.t('html_footnote_textmark', footnote_number)}#{footnote_content}</p></div>)
        else
          # Non-EPUB version
          footnote_back_link = %Q(<a href="#fnb-#{normalize_id(node.id)}">*#{footnote_number}</a>)
          %Q(<div class="footnote" id="fn-#{normalize_id(node.id)}"><p class="footnote">[#{footnote_back_link}] #{footnote_content}</p></div>)
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
        return '' unless config['draft']

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

        %Q(<div class="#{type}"#{id_attr}>\n#{caption_html}#{content}</div>)
      end

      def render_generic_block(node)
        id_attr = node.id ? %Q( id="#{normalize_id(node.id)}") : ''
        content = render_children(node)

        %Q(<div class="#{escape(node.block_type)}"#{id_attr}>#{content}</div>)
      end

      # Render firstlinenum control block
      def render_firstlinenum_block(node)
        # Extract line number from args (first arg is the line number)
        line_num = node.args&.first&.to_i || 1
        firstlinenum(line_num)
        '' # No HTML output
      end

      # Render label control block
      def render_label_block(node)
        # Extract label from args
        label = node.args&.first
        return '' unless label

        %Q(<a id="#{normalize_id(label)}"></a>)
      end

      # Render tsize control block
      def render_tsize_block(_node)
        # Table size control - HTMLBuilder outputs nothing for HTML
        # tsize is only used for LaTeX/PDF output
        ''
      end

      # Render printendnotes control block
      def render_printendnotes_block(_node)
        # Render collected endnotes like HTMLBuilder's printendnotes method
        return '' unless @chapter
        return '' unless @chapter.endnotes

        # Check if there are any endnotes using size
        return '' if @chapter.endnotes.size == 0

        # Mark that we've shown endnotes (like Builder base class)
        @shown_endnotes = true

        # Begin endnotes block
        result = %Q(<div class="endnotes">\n)

        # Render each endnote like HTMLBuilder's endnote_item
        @chapter.endnotes.each do |en|
          back = ''
          if config['epubmaker'] && config['epubmaker']['back_footnote']
            back = %Q(<a href="#endnoteb-#{normalize_id(en.id)}">#{I18n.t('html_footnote_backmark')}</a>)
          end
          result += %Q(<div class="endnote" id="endnote-#{normalize_id(en.id)}"><p class="endnote">#{back}#{I18n.t('html_endnote_textmark', @chapter.endnote(en.id).number)}#{compile_inline(@chapter.endnote(en.id).content)}</p></div>\n)
        end

        # End endnotes block
        result + %Q(</div>\n)
      end

      # Render flushright block like HTMLBuilder's flushright method
      def render_flushright_block(node)
        # Render children (which produces <p> tags)
        content = render_children(node)
        # Replace <p> with <p class="flushright"> like HTMLBuilder
        content.gsub('<p>', %Q(<p class="flushright">))
      end

      # Render centering block like HTMLBuilder's centering method
      def render_centering_block(node)
        # Render children (which produces <p> tags)
        content = render_children(node)
        # Replace <p> with <p class="center"> like HTMLBuilder
        content.gsub('<p>', %Q(<p class="center">))
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
        first_line_number = line_num || 1 # Use line_num like HTMLBuilder (supports firstlinenum)

        if highlight?
          # Use highlight with line numbers like HTMLBuilder
          highlight(body: body, lexer: lang, format: 'html', linenum: true, options: { linenostart: first_line_number })
        else
          # Fallback: manual line numbering like HTMLBuilder does when highlight is off
          lines.map.with_index(first_line_number) do |line, i|
            "#{i.to_s.rjust(2)}: #{detab(line)}"
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
        prefix = @sec_counter.prefix(level, config['secnolevel'])
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
        if config['secnolevel'] && config['secnolevel'] > 0 &&
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
        ".#{config['htmlext'] || 'html'}"
      end

      # Image helper methods matching HTMLBuilder's implementation
      def image_image_html(id, caption, _metric, id_attr, image_type = :image)
        caption_html = image_header_html(id, caption, image_type)

        begin
          image_path = @chapter.image(id).path.sub(%r{\A\./}, '')
          caption_content = caption ? render_children(caption) : ''

          img_html = %Q(<img src="#{image_path}" alt="#{escape(caption_content)}" />)

          # Check caption positioning like HTMLBuilder
          if caption_top?('image') && caption
            %Q(<div#{id_attr} class="image">\n#{caption_html}#{img_html}\n</div>\n)
          else
            %Q(<div#{id_attr} class="image">\n#{img_html}\n#{caption_html}</div>\n)
          end
        rescue StandardError
          # If image loading fails, fall back to dummy
          image_dummy_html(id, caption, [], id_attr, image_type)
        end
      end

      # Context-aware version of image_image_html
      def image_image_html_with_context(id, caption, _metric, id_attr, caption_context, image_type = :image)
        caption_html = if caption
                         image_header_html_with_context(id, caption, caption_context, image_type)
                       else
                         ''
                       end

        begin
          image_path = @chapter.image(id).path.sub(%r{\A\./}, '')
          caption_content = caption ? render_children_with_context(caption, caption_context) : ''

          img_html = %Q(<img src="#{image_path}" alt="#{escape(caption_content)}" />)

          # Check caption positioning like HTMLBuilder
          if caption_top?('image') && caption
            %Q(<div#{id_attr} class="image">\n#{caption_html}#{img_html}\n</div>\n)
          else
            %Q(<div#{id_attr} class="image">\n#{img_html}\n#{caption_html}</div>\n)
          end
        rescue StandardError
          # If image loading fails, fall back to dummy
          image_dummy_html_with_context(id, caption, [], id_attr, caption_context, image_type)
        end
      end

      def image_dummy_html(id, caption, lines, id_attr, image_type = :image)
        caption_html = image_header_html(id, caption, image_type)

        # Generate dummy image content exactly like HTMLBuilder
        # HTMLBuilder puts each line and adds newlines via 'puts'
        lines_content = if lines.empty?
                          "\n" # Empty image block just has one newline
                        else
                          "\n" + lines.map { |line| escape(line) }.join("\n") + "\n"
                        end

        # Check caption positioning like HTMLBuilder
        if caption_top?('image') && caption
          %Q(<div#{id_attr} class="image">\n#{caption_html}<pre class="dummyimage">#{lines_content}</pre>\n</div>\n)
        else
          %Q(<div#{id_attr} class="image">\n<pre class="dummyimage">#{lines_content}</pre>\n#{caption_html}</div>\n)
        end
      end

      # Context-aware version of image_dummy_html
      def image_dummy_html_with_context(id, caption, lines, id_attr, caption_context, image_type = :image)
        caption_html = if caption
                         image_header_html_with_context(id, caption, caption_context, image_type)
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
          %Q(<div#{id_attr} class="image">\n#{caption_html}<pre class="dummyimage">#{lines_content}</pre>\n</div>\n)
        else
          %Q(<div#{id_attr} class="image">\n<pre class="dummyimage">#{lines_content}</pre>\n#{caption_html}</div>\n)
        end
      end

      def image_header_html(id, caption, image_type = :image)
        return '' unless caption

        caption_content = render_children(caption)

        # For indepimage (numberless image), use numberless_image label like HTMLBuilder
        if image_type == :indepimage || image_type == :numberlessimage
          image_number = I18n.t('numberless_image')
        else
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
        end

        %Q(<p class="caption">\n#{image_number}#{I18n.t('caption_prefix')}#{caption_content}\n</p>\n)
      end

      # Context-aware version of image_header_html
      def image_header_html_with_context(id, caption, caption_context, image_type = :image)
        return '' unless caption

        caption_content = render_children_with_context(caption, caption_context)

        # For indepimage (numberless image), use numberless_image label like HTMLBuilder
        if image_type == :indepimage || image_type == :numberlessimage
          image_number = I18n.t('numberless_image')
        else
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
        end

        %Q(<p class="caption">\n#{image_number}#{I18n.t('caption_prefix')}#{caption_content}\n</p>\n)
      end

      def caption_top?(type)
        config['caption_position'] && config['caption_position'][type] == 'top'
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

      # Generate table header like HTMLBuilder's table_header method
      def generate_table_header(id, caption)
        table_item = @chapter.table(id)
        table_num = table_item.number
        chapter_num = @chapter.number

        if chapter_num
          "#{I18n.t('table')}#{I18n.t('format_number_header', [chapter_num, table_num])}#{I18n.t('caption_prefix')}#{caption}"
        else
          "#{I18n.t('table')}#{I18n.t('format_number_header_without_chapter', [table_num])}#{I18n.t('caption_prefix')}#{caption}"
        end
      rescue KeyError
        raise NotImplementedError, "no such table: #{id}"
      end

      # Render imgtable (table as image) like HTMLBuilder's imgtable method
      def render_imgtable(node)
        id = node.id
        caption = node.caption

        # Check if image is bound like HTMLBuilder does
        unless @chapter&.image_bound?(id)
          warn "image not bound: #{id}"
          # For dummy images, use empty array for lines (no lines in TableNode)
          return render_imgtable_dummy(id, caption, [])
        end

        id_attr = id ? %Q( id="#{normalize_id(id)}") : ''

        # Generate table caption HTML if caption exists
        caption_html = if caption
                         caption_content = render_children(caption)
                         # Use table_header format for imgtable like HTMLBuilder
                         table_caption = generate_table_header(id, caption_content)
                         %Q(<p class="caption">#{table_caption}</p>\n)
                       else
                         ''
                       end

        # Render image tag
        begin
          image_path = @chapter.image(id).path.sub(%r{\A\./}, '')
          alt_text = caption ? escape(render_children(caption)) : ''
          img_html = %Q(<img src="#{image_path}" alt="#{alt_text}" />\n)

          # Check caption positioning like HTMLBuilder (uses 'table' type for imgtable)
          if caption_top?('table') && caption
            %Q(<div#{id_attr} class="imgtable image">\n#{caption_html}#{img_html}</div>\n)
          else
            %Q(<div#{id_attr} class="imgtable image">\n#{img_html}#{caption_html}</div>\n)
          end
        rescue KeyError
          app_error "no such table: #{id}"
        end
      end

      # Render dummy imgtable when image is not found
      def render_imgtable_dummy(id, caption, lines)
        id_attr = id ? %Q( id="#{normalize_id(id)}") : ''

        # Generate table caption HTML if caption exists
        caption_html = if caption
                         caption_content = render_children(caption)
                         # Use table_header format for imgtable like HTMLBuilder
                         table_caption = generate_table_header(id, caption_content)
                         %Q(<p class="caption">#{table_caption}</p>\n)
                       else
                         ''
                       end

        # Generate dummy content like image_dummy_html
        lines_content = if lines.empty?
                          "\n"
                        else
                          "\n" + lines.map { |line| escape(line) }.join("\n") + "\n"
                        end

        # Check caption positioning like HTMLBuilder
        if caption_top?('table') && caption
          %Q(<div#{id_attr} class="imgtable image">\n#{caption_html}<pre class="dummyimage">#{lines_content}</pre>\n</div>\n)
        else
          %Q(<div#{id_attr} class="imgtable image">\n<pre class="dummyimage">#{lines_content}</pre>\n#{caption_html}</div>\n)
        end
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
        @highlighter ||= ReVIEW::Highlighter.new(config)
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
