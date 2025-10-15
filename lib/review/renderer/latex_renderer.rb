# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/renderer/base'
require 'review/renderer/rendering_context'
require 'review/latexutils'
require 'review/sec_counter'
require 'review/i18n'
require 'review/textutils'

module ReVIEW
  module Renderer
    class LatexRenderer < Base
      include ReVIEW::LaTeXUtils
      include ReVIEW::TextUtils

      attr_reader :chapter, :book

      def initialize(chapter)
        super

        # For AST rendering, we need to set up indexing properly
        # The indexing will be done when we process the AST
        @ast_indexer = nil

        # Initialize I18n if not already setup
        if @book && @book.config['language']
          I18n.setup(@book.config['language'])
        else
          I18n.setup('ja') # Default to Japanese
        end

        # Initialize LaTeX character escaping
        initialize_metachars('')

        # Initialize section counter like LATEXBuilder
        @sec_counter = SecCounter.new(5, @chapter) if @chapter

        # Initialize first line number state like LATEXBuilder
        @first_line_num = nil

        # Initialize RenderingContext for cleaner state management
        @rendering_context = RenderingContext.new(:document)

        # Initialize Part environment tracking for reviewpart wrapper
        @part_env_opened = false
      end

      def visit_document(node)
        # Build indexes using AST::Indexer for proper footnote support
        if @chapter && !@ast_indexer
          require 'review/ast/indexer'
          @ast_indexer = ReVIEW::AST::Indexer.new(@chapter)
          @ast_indexer.build_indexes(node)
        end

        # Generate content with proper separation between document-level elements
        content = render_document_children(node)

        # Close the reviewpart environment if it was opened
        if @part_env_opened
          content += "\\end{reviewpart}\n"
        end

        # Add any remaining collected footnotetext commands
        if @rendering_context.footnote_collector.any?
          content += generate_footnotetext_from_collector(@rendering_context.footnote_collector)
          @rendering_context.footnote_collector.clear
        end

        # Ensure content ends with single newline if it contains content
        if content && !content.empty?
          content.chomp + "\n"
        else
          content || ''
        end
      end

      def visit_headline(node)
        level = node.level
        caption = render_children(node.caption) if node.caption

        # For Part documents with legacy configuration, open reviewpart environment
        # on first level 1 headline (matching LATEXBuilder behavior)
        prefix = ''
        if should_wrap_part_with_reviewpart? && level == 1 && !@part_env_opened
          @part_env_opened = true
          prefix = "\\begin{reviewpart}\n"
        end

        # Update section counter like LATEXBuilder
        if @sec_counter
          @sec_counter.inc(level)
        end

        # Handle special headline options (nonum, notoc, nodisp)
        if node.nodisp?
          # nodisp: Only add TOC entry, no visible heading
          return prefix + generate_toc_entry(level, caption)
        elsif node.nonum?
          # nonum: Unnumbered section that appears in TOC
          return prefix + generate_nonum_headline(level, caption, node)
        elsif node.notoc?
          # notoc: Unnumbered section that does NOT appear in TOC
          return prefix + generate_notoc_headline(level, caption, node)
        end

        # Regular headline processing
        section_command = headline_name(level)

        # Generate labels like LATEXBuilder
        label_part = if level == 1 && @chapter
                       "\\label{chap:#{@chapter.id}}"
                     elsif @sec_counter && level >= 2
                       # Generate section labels like LATEXBuilder (sec:x-y format)
                       anchor = @sec_counter.anchor(level)
                       "\\label{sec:#{anchor}}"
                     elsif node.label
                       "\\label{#{escape(node.label)}}"
                     else
                       ''
                     end

        # Format with exact newlines like LATEXBuilder to match expected format
        result = []
        result << "\\#{section_command}{#{caption}}"

        # Add \addcontentsline for subsection* (level 3)
        if level > @book.config['secnolevel'] || (@chapter.number.to_s.empty? && level > 1)
          result << "\\addcontentsline{toc}{subsection}{#{caption}}"
        end

        unless label_part.empty?
          result << label_part
        end

        prefix + result.join("\n") + "\n"
      end

      def visit_paragraph(node)
        content = render_children(node)

        # Check for noindent attribute
        if node.attribute?(:noindent)
          # Add \noindent command like LATEXBuilder
          "\\noindent\n#{content}\n\n"
        else
          # Add double newline for paragraph separation (LaTeX standard)
          "#{content}\n\n"
        end
      end

      def visit_text(node)
        content = node.content.to_s
        # Preserve newlines and escape content properly
        # Don't escape newlines so they are preserved in the output
        escape(content)
      end

      def visit_inline(node)
        content = render_children(node)
        render_inline_element(node.inline_type, content, node)
      end

      def visit_code_block(node)
        # Process caption with proper context management
        caption = if node.caption
                    @rendering_context.with_child_context(:caption) do |caption_context|
                      render_children_with_context(node.caption, caption_context)
                    end
                  end

        # Process children to get properly escaped content while preserving structure
        content = render_children(node)
        code_type = node.code_type.to_s if node.respond_to?(:code_type)

        result = case code_type
                 when 'list'
                   visit_list_block(node, content, caption)
                 when 'listnum'
                   # listnum uses same environment as list but with line numbers in content
                   visit_list_block(node, add_line_numbers(content), caption)
                 when 'emlist'
                   visit_emlist_block(node, content, caption)
                 when 'emlistnum'
                   # emlistnum uses same environment as emlist but with line numbers in content
                   visit_emlist_block(node, add_line_numbers(content), caption)
                 when 'cmd'
                   visit_cmd_block(node, content, caption)
                 when 'source'
                   visit_source_block(node, content, caption)
                 else
                   raise NotImplementedError, "Unknown code block type: #{code_type}"
                 end

        # Add collected footnotetext commands
        if @rendering_context.footnote_collector.any?
          result += generate_footnotetext_from_collector(@rendering_context.footnote_collector)
          @rendering_context.footnote_collector.clear
        end

        result
      end

      def visit_code_line(node)
        # Render children (TextNode and InlineNode) to process inline elements properly
        content = render_children(node)
        # Add proper newline for LaTeX code line formatting
        "#{content}\n"
      end

      def visit_table(node)
        # Process caption with proper context management
        caption = if node.caption
                    @rendering_context.with_child_context(:caption) do |caption_context|
                      render_children_with_context(node.caption, caption_context)
                    end
                  end

        table_type = node.respond_to?(:table_type) ? node.table_type : :table

        # Handle imgtable specially - it should be rendered as an image
        if table_type == :imgtable
          return visit_imgtable(node, caption)
        end

        # Process table content with table context
        table_context = nil
        table_content = @rendering_context.with_child_context(:table) do |ctx|
          table_context = ctx
          # Temporarily set the renderer's context to the table context
          old_context = @rendering_context
          @rendering_context = table_context

          # Calculate column count from first row
          all_rows = node.header_rows + node.body_rows
          col_count = all_rows.first ? all_rows.first.children.length : 1

          # Generate column specification with borders (like LATEXBuilder)
          col_spec = '|' + ('l|' * col_count)

          result = []
          # Use Re:VIEW table structure like LATEXBuilder
          result << if node.id?
                      "\\begin{table}%%#{node.id}"
                    else
                      '\\begin{table}%%'
                    end

          if caption && !caption.empty?
            # emtable uses reviewtablecaption* (with asterisk)
            caption_command = table_type == :emtable ? 'reviewtablecaption*' : 'reviewtablecaption'
            result << "\\#{caption_command}{#{caption}}"
          end

          if node.id?
            # Generate label like LATEXBuilder: table:chapter:id
            # Don't escape underscores in labels - they're allowed in LaTeX label names
            result << if @chapter
                        "\\label{table:#{@chapter.id}:#{node.id}}"
                      else
                        "\\label{table:test:#{node.id}}"
                      end
          end

          result << "\\begin{reviewtable}{#{col_spec}}"
          result << '\\hline'

          # Process all rows using visitor pattern with table context
          # table_context is now the current @rendering_context within this block
          all_rows.each do |row|
            row_content = visit(row)
            result << "#{row_content} \\\\  \\hline"
          end

          result << '\\end{reviewtable}'
          result << '\\end{table}'

          # Restore the previous context
          @rendering_context = old_context
          result.join("\n") + "\n"
        end

        # Add collected footnotetext commands from table context
        if table_context && table_context.footnote_collector.any?
          table_content += generate_footnotetext_from_collector(table_context.footnote_collector)
          table_context.footnote_collector.clear
        end

        table_content
      end

      def visit_imgtable(node, caption)
        # imgtable should be rendered as an image, not as a table (like LATEXBuilder)
        result = []
        result << '\\begin{reviewdummyimage}'

        if node.id?
          # Generate label like LATEXBuilder: image:chapter:id
          # Don't escape underscores in labels - they're allowed in LaTeX label names
          result << if @chapter
                      "\\label{image:#{@chapter.id}:#{node.id}}"
                    else
                      "\\label{image:test:#{node.id}}"
                    end
        end

        if caption && !caption.empty?
          result << "\\reviewimagecaption{#{caption}}"
        end

        result << '\\end{reviewdummyimage}'

        result.join("\n") + "\n"
      end

      def visit_table_row(node)
        # Process all cells in the row using visitor pattern while maintaining table context
        # Note: table context should already be set by visit_table
        cells = node.children.map { |cell| visit(cell) }
        cells.join(' & ')
      end

      def visit_table_cell(node)
        # Process cell content while maintaining table context to collect footnotes
        # Note: table context should already be set by visit_table
        content = render_children(node)
        # Use cell_type to determine LaTeX formatting
        if node.cell_type == :th
          "\\reviewth{#{content}}"
        else
          content
        end
      end

      def visit_image(node)
        # Process caption with proper context management
        caption = if node.caption
                    @rendering_context.with_child_context(:caption) do |caption_context|
                      render_children_with_context(node.caption, caption_context)
                    end
                  end

        image_type = node.respond_to?(:image_type) ? node.image_type : :image

        case image_type
        when :indepimage, :numberlessimage
          visit_indepimage(node, caption)
        else
          visit_regular_image(node, caption)
        end
      end

      def visit_regular_image(node, caption)
        result = []
        # Use Re:VIEW image structure like LATEXBuilder
        result << if node.id?
                    "\\begin{reviewimage}%%#{node.id}"
                  else
                    '\\begin{reviewimage}'
                  end

        # Add includegraphics command like LATEXBuilder
        if node.id? && @chapter
          begin
            image_path = @chapter.image(node.id).path
            # Use reviewincludegraphics with default width like LATEXBuilder
            result << "\\reviewincludegraphics[width=\\maxwidth]{#{image_path}}"
          rescue KeyError
            # Image not found - skip includegraphics command like LATEXBuilder would use image_dummy
            # But for regular image nodes, we still generate the structure without the includegraphics
          end
        end

        if caption && !caption.empty?
          result << "\\reviewimagecaption{#{caption}}"
        end

        if node.id?
          # Generate label like LATEXBuilder: image:chapter:id
          # Don't escape underscores in labels - they're allowed in LaTeX label names
          result << if @chapter
                      "\\label{image:#{@chapter.id}:#{node.id}}"
                    else
                      "\\label{image:test:#{node.id}}"
                    end
        end

        result << '\\end{reviewimage}'

        image_result = result.join("\n") + "\n"

        # Add collected footnotetext commands from caption context
        if @rendering_context.footnote_collector.any?
          image_result += generate_footnotetext_from_collector(@rendering_context.footnote_collector)
          @rendering_context.footnote_collector.clear
        end

        image_result
      end

      def visit_indepimage(node, caption)
        result = []

        # Get image path
        image_path = @chapter.image(node.id).path if @chapter&.image(node.id)

        if image_path
          result << "\\begin{reviewimage}%%#{node.id}"

          # Add caption at top if configured
          if caption_top?('image') && caption && !caption.empty?
            caption_str = "\\reviewindepimagecaption{#{I18n.t('numberless_image')}#{I18n.t('caption_prefix')}#{caption}}"
            result << caption_str
          end

          # Add image
          command = @book&.config&.check_version('2', exception: false) ? 'includegraphics' : 'reviewincludegraphics'

          # Apply metrics if available
          metrics_str = build_metrics_string(node.metrics) if node.respond_to?(:metrics) && node.metrics
          options = metrics_str ? "[#{metrics_str}]" : ''

          result << "\\#{command}#{options}{#{image_path}}"

          # Add caption at bottom if not at top
          if !caption_top?('image') && caption && !caption.empty?
            caption_str = "\\reviewindepimagecaption{#{I18n.t('numberless_image')}#{I18n.t('caption_prefix')}#{caption}}"
            result << caption_str
          end

          result << '\\end{reviewimage}'
        else
          # Fallback for missing image
          result << "\\begin{reviewdummyimage}%%#{node.id}"
          result << "% Image file not found: #{node.id}"

          if caption && !caption.empty?
            caption_str = "\\reviewindepimagecaption{#{I18n.t('numberless_image')}#{I18n.t('caption_prefix')}#{caption}}"
            result << caption_str
          end

          result << '\\end{reviewdummyimage}'
        end

        result.join("\n") + "\n"
      end

      def visit_list(node)
        case node.list_type
        when :ul
          # Unordered list - generate LaTeX itemize environment
          items = node.children.map { |item| "\\item #{render_children(item)}" }.join("\n")
          "\n\\begin{itemize}\n#{items}\n\\end{itemize}\n"
        when :ol
          # Ordered list - generate LaTeX enumerate environment
          items = node.children.map { |item| "\\item #{render_children(item)}" }.join("\n")

          # Check if this list has olnum start number
          if node.attribute?(:start_number)
            # Generate enumerate with setcounter for olnum
            start_num = node.fetch_attribute(:start_number) - 1 # LaTeX counter is 0-based
            "\n\\begin{enumerate}\n\\setcounter{enumi}{#{start_num}}\n#{items}\n\\end{enumerate}\n"
          else
            "\n\\begin{enumerate}\n#{items}\n\\end{enumerate}\n"
          end
        when :dl
          # Definition list - generate LaTeX description environment like LATEXBuilder
          items = node.children.map do |item|
            # Handle definition term - use term_children if available (new AST structure)
            term = if item.respond_to?(:term_children) && item.term_children && !item.term_children.empty?
                     # Render term children (which contain inline elements)
                     item.term_children.map { |child| visit(child) }.join
                   elsif item.content
                     # Fallback to item content (raw text)
                     item.content.to_s
                   else
                     ''
                   end

            # Escape square brackets in terms like LATEXBuilder does
            term = term.gsub('[', '\\lbrack{}').gsub(']', '\\rbrack{}')

            # Handle definition content (all children are definition content)
            if item.children && !item.children.empty?
              definition_parts = item.children.map do |child|
                visit(child) # Use visit instead of render_children for individual nodes
              end
              definition = definition_parts.join(' ').strip

              # Use exact LATEXBuilder format: \item[term] \mbox{} \\
              "\\item[#{term}] \\mbox{} \\\\\n#{definition}"
            else
              # No definition content - term only
              "\\item[#{term}] \\mbox{} \\\\"
            end
          end.join("\n")
          "\n\\begin{description}\n#{items}\n\\end{description}\n"
        else
          raise NotImplementedError, "Unsupported list type: #{node.list_type}"
        end
      end

      def visit_list_item(node)
        raise NotImplementedError, 'List item processing should be handled by visit_list, not as standalone items'
      end

      def visit_block(node) # rubocop:disable Metrics/CyclomaticComplexity
        content = render_children(node)
        block_type = node.block_type.to_s

        case block_type
        when 'quote'
          result = "\n\\begin{quote}\n#{content}\\end{quote}\n"
          apply_noindent_if_needed(node, result)
        when 'source'
          # Source code block without caption
          "\\begin{reviewcmd}\n#{content}\\end{reviewcmd}\n"
        when 'lead'
          # Lead paragraph - use standard quotation environment like LATEXBuilder
          result = "\\begin{quotation}\n#{content}\\end{quotation}\n"
          apply_noindent_if_needed(node, result)
        when 'olnum'
          # olnum is now handled as metadata in list processing
          # If we encounter it here, it means there was no following ordered list
          # In this case, we should still generate the setcounter command for compatibility
          if node.respond_to?(:args) && node.args && node.args.first
            num = node.args.first.to_i
            "\\setcounter{enumi}{#{num - 1}}\n"
          else
            "\\setcounter{enumi}{0}\n"
          end
        when 'footnote'
          # Handle footnote blocks - generate \footnotetext LaTeX command
          if node.respond_to?(:args) && node.args && node.args.length >= 2
            footnote_id = node.args[0]
            footnote_content = escape(node.args[1])
            # Generate footnote number like LaTeXBuilder does
            if @chapter && @chapter.footnote_index
              begin
                footnote_number = @chapter.footnote_index.number(footnote_id)
                "\\footnotetext[#{footnote_number}]{#{footnote_content}}\n"
              rescue StandardError => e
                raise NotImplementedError, "Footnote block processing failed for #{footnote_id}: #{e.message}"
              end
            else
              raise NotImplementedError, 'Footnote processing requires chapter context but none provided'
            end
          else
            raise NotImplementedError, 'Malformed footnote block: insufficient arguments'
          end
        when 'firstlinenum'
          # firstlinenum sets the starting line number for subsequent listnum blocks
          # Store the value in @first_line_num like LaTeXBuilder does
          if node.respond_to?(:args) && node.args && node.args.first
            @first_line_num = node.args.first.to_i
          end
          # firstlinenum itself produces no output
          ''
        when 'texequation'
          # Handle mathematical equation blocks - output content directly
          # without LaTeX environment wrapping since content is raw LaTeX math
          content.strip.empty? ? '' : "#{content}\n"
        when 'comment'
          # Handle comment blocks - only output in draft mode
          visit_comment_block(node)
        when 'beginchild', 'endchild'
          # Child nesting control commands - produce no output
          ''
        when 'centering'
          # Center alignment
          "\\begin{center}\n#{content}\\end{center}\n"
        when 'flushright'
          # Right alignment
          "\\begin{flushright}\n#{content}\\end{flushright}\n"
        when 'address' # rubocop:disable Lint/DuplicateBranch
          # Address block - similar to flushright
          "\\begin{flushright}\n#{content}\\end{flushright}\n"
        when 'talk'
          # Dialog/conversation block
          "#{content}\n"
        when 'read'
          # Reading material block - use quotation environment
          "\\begin{quotation}\n#{content}\\end{quotation}\n"
        when 'blockquote'
          # Block quotation - same as quote but different semantic meaning
          "\\begin{quote}\n#{content}\\end{quote}\n"
        when 'blankline', 'noindent', 'pagebreak', 'tsize', 'endnote', 'label', 'printendnotes', 'hr', 'bpo', 'parasep' # rubocop:disable Lint/DuplicateBranch
          # Control commands that should not generate LaTeX environment blocks
          ''
        when 'bibpaper'
          # Bibliography paper - delegate to specialized handler
          visit_bibpaper(node)
        else
          raise NotImplementedError, "Unknown block type: #{block_type}"
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
        result << content.chomp
        result << ''  # blank line
        result << "\\end{#{env_name}}"

        result.join("\n") + "\n"
      end

      def visit_caption(node)
        render_children(node)
      end

      def visit_comment_block(node)
        # block comment - only display in draft mode
        return '' unless @book&.config&.[]('draft')

        content_lines = []

        # add argument if it exists
        if node.args && node.args.first && !node.args.first.empty?
          content_lines << escape(node.args.first)
        end

        # add body content
        if node.content && !node.content.empty?
          body_content = render_children(node)
          content_lines << body_content unless body_content.empty?
        end

        return '' if content_lines.empty?

        # use pdfcomment macro in LaTeX
        content_str = content_lines.join('\\par ')
        "\\pdfcomment{#{content_str}}\n"
      end

      def visit_column(node)
        content = render_children(node)
        caption = render_children(node.caption) if node.caption

        # Generate column label for hypertarget
        column_label = generate_column_label(node, caption)
        hypertarget = "\\hypertarget{#{column_label}}{}"

        result = []
        result << '' # blank line before column

        # support Re:VIEW Version 3+ format only
        caption_part = caption ? "[#{caption}#{hypertarget}]" : "[#{hypertarget}]"
        result << "\\begin{reviewcolumn}#{caption_part}"

        # Add TOC entry if within toclevel
        if node.level && caption && node.level <= @book.config['toclevel'].to_i
          toc_level = case node.level
                      when 1
                        'chapter'
                      when 2
                        'section'
                      when 3
                        'subsection'
                      when 4
                        'subsubsection'
                      else # rubocop:disable Lint/DuplicateBranch
                        'subsection' # fallback
                      end
          result << "\\addcontentsline{toc}{#{toc_level}}{#{caption}}"
        end

        result << ''  # blank line after header
        result << content.chomp
        result << ''  # blank line before end
        result << '\\end{reviewcolumn}'
        result << ''  # blank line after column

        result.join("\n") + "\n"
      end

      def visit_embed(node)
        # Handle different embed types
        if node.respond_to?(:embed_type) && (node.embed_type == :raw || node.embed_type == :inline)
          # Handle //raw command or inline @<raw> command
          return process_raw_embed(node)
        end

        # Default embed processing for other types
        if node.respond_to?(:lines) && node.lines
          node.lines.join("\n") + "\n"
        elsif node.respond_to?(:arg) && node.arg
          # Single line embed
          "#{node.arg}\n"
        else
          raise NotImplementedError, 'Unknown embed structure or missing argument'
        end
      end

      def visit_generic(node)
        method_name = derive_visit_method_name_string(node)
        raise NotImplementedError, "LaTeXRenderer does not support generic visitor. Implement #{method_name} for #{node.class.name}"
      end

      # Code block type handlers
      def visit_list_block(node, content, caption)
        result = []
        result << '\\begin{reviewlistblock}'

        if caption && !caption.empty?
          # Use LATEXBuilder logic for list caption with proper numbering
          if node.id?
            # For list blocks with ID, generate numbered caption like LATEXBuilder
            begin
              list_item = @chapter.list(node.id)
              list_num = list_item.number
              chapter_num = @chapter.number
              captionstr = if chapter_num
                             "\\reviewlistcaption{#{I18n.t('list')}#{I18n.t('format_number_header', [chapter_num, list_num])}#{I18n.t('caption_prefix')}#{caption}}"
                           else
                             "\\reviewlistcaption{#{I18n.t('list')}#{I18n.t('format_number_header_without_chapter', [list_num])}#{I18n.t('caption_prefix')}#{caption}}"
                           end
              result << captionstr
            rescue KeyError
              raise NotImplementedError, "no such list: #{node.id}"
            end
          else
            # For list blocks without ID, use simple caption
            result << "\\reviewlistcaption{#{caption}}"
          end
        end

        result << '\\begin{reviewlist}'
        result << content.chomp
        result << '\\end{reviewlist}'
        result << '\\end{reviewlistblock}'

        result.join("\n") + "\n"
      end

      def visit_emlist_block(_node, content, caption)
        result = []
        result << '\\begin{reviewlistblock}'

        if caption && !caption.empty?
          result << "\\reviewemlistcaption{#{caption}}"
        end

        result << '\\begin{reviewemlist}'
        result << content.chomp
        result << '\\end{reviewemlist}'

        result << '\\end{reviewlistblock}'
        result.join("\n") + "\n"
      end

      def visit_cmd_block(_node, content, caption)
        result = []
        result << '\\begin{reviewlistblock}'

        if caption && !caption.empty?
          result << "\\reviewcmdcaption{#{caption}}"
        end

        result << '\\begin{reviewcmd}'
        result << content.chomp
        result << '\\end{reviewcmd}'
        result << '\\end{reviewlistblock}'

        result.join("\n") + "\n"
      end

      def visit_source_block(_node, content, caption)
        result = []
        result << '\\begin{reviewlistblock}'

        if caption && !caption.empty?
          result << "\\reviewsourcecaption{#{caption}}"
        end

        result << '\\begin{reviewsource}'
        result << content.chomp
        result << '\\end{reviewsource}'
        result << '\\end{reviewlistblock}'

        result.join("\n") + "\n"
      end

      def visit_tex_equation(node)
        # Handle LaTeX mathematical equation blocks
        # Output the LaTeX content directly without escaping since it's raw LaTeX
        content = node.content

        if node.id? && node.caption?
          # Equation with ID and caption - use reviewequationblock like traditional compiler
          equation_num = get_equation_number(node.id)
          result = []
          result << '\\begin{reviewequationblock}'
          result << "\\reviewequationcaption{#{escape("式#{equation_num}: #{node.caption}")}}"
          result << '\\begin{equation*}'
          result << content
          result << '\\end{equation*}'
          result << '\\end{reviewequationblock}'
        elsif node.id?
          # Equation with ID only - still use reviewequationblock for consistency
          equation_num = get_equation_number(node.id)
          result = []
          result << '\\begin{reviewequationblock}'
          result << "\\reviewequationcaption{#{escape("式#{equation_num}")}}"
          result << '\\begin{equation*}'
          result << content
          result << '\\end{equation*}'
          result << '\\end{reviewequationblock}'
        else
          # Equation without ID - use equation* environment (no numbering)
          result = []
          result << '\\begin{equation*}'
          result << content
          result << '\\end{equation*}'
        end

        result.join("\n") + "\n"
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

      def visit_bibpaper(node)
        # Extract bibliography arguments
        if node.args && node.args.length >= 2
          bib_id = node.args[0]
          bib_caption = node.args[1]

          # Process content
          content = render_children(node)

          # Generate bibliography entry like LATEXBuilder
          result = []

          # Header with number and caption
          if @chapter && @chapter.bibpaper_index
            begin
              bib_number = @chapter.bibpaper_index.number(bib_id)
              result << "[#{bib_number}] #{escape(bib_caption)}"
            rescue StandardError => e
              # Fallback if not found in index
              warn "Bibpaper #{bib_id} not found in index: #{e.message}" if $DEBUG
              result << "[??] #{escape(bib_caption)}"
            end
          elsif @ast_indexer && @ast_indexer.bibpaper_index
            # Try to get from AST indexer if chapter index not available
            begin
              bib_number = @ast_indexer.bibpaper_index.number(bib_id)
              result << "[#{bib_number}] #{escape(bib_caption)}"
            rescue StandardError
              result << "[??] #{escape(bib_caption)}"
            end
          else
            result << "[??] #{escape(bib_caption)}"
          end

          # Add label for cross-references
          result << "\\label{bib:#{escape(bib_id)}}"
          result << ''

          # Add content - process paragraphs
          result << if @book.config['join_lines_by_lang']
                      split_paragraph(content).join("\n\n")
                    else
                      content
                    end

          result.join("\n") + "\n"
        else
          raise NotImplementedError, 'Malformed bibpaper block: insufficient arguments'
        end
      end

      # Add line numbers to content like LATEXBuilder does
      def add_line_numbers(content)
        lines = content.split("\n")
        numbered_lines = []

        # Use @first_line_num if set, otherwise start from 1
        start_num = @first_line_num || 1

        lines.each_with_index do |line, i|
          next if line.strip.empty? && i == lines.length - 1 # Skip last empty line

          numbered_lines << sprintf('%2d: %s', start_num + i, line)
        end

        # Clear @first_line_num after use like LaTeXBuilder does
        @first_line_num = nil

        numbered_lines.join("\n")
      end

      # Render footnote content for footnotetext
      # This method processes the footnote node's children to properly handle
      # inline markup like @<b>{text} within footnotes
      def render_footnote_content(footnote_node)
        if footnote_node.children&.any?
          render_children(footnote_node)
        else
          # Fallback for nodes without children (shouldn't happen in normal cases)
          escape(footnote_node&.content || '')
        end
      end

      private

      # Generate LaTeX footnotetext commands from collected footnotes
      # @param collector [FootnoteCollector] the footnote collector
      # @return [String] LaTeX footnotetext commands
      def generate_footnotetext_from_collector(collector)
        return '' unless collector.any?

        footnotetext_commands = []
        collector.each do |entry|
          content = render_footnote_content(entry.node)
          footnotetext_commands << "\\footnotetext[#{entry.number}]{#{content}}"
        end

        footnotetext_commands.join("\n") + "\n"
      end

      HEADLINE = { # rubocop:disable Lint/UselessConstantScoping
        1 => 'chapter',
        2 => 'section',
        3 => 'subsection',
        4 => 'subsubsection',
        5 => 'paragraph',
        6 => 'subparagraph'
      }.freeze

      def headline_name(level)
        name = if @chapter.is_a?(ReVIEW::Book::Part) && level == 1
                 'part'
               else
                 HEADLINE[level] || raise(CompileError, "Unsupported headline level: #{level}. LaTeX only supports levels 1-6")
               end

        if level > @book.config['secnolevel'] || (@chapter.number.to_s.empty? && level > 1)
          "#{name}*"
        else
          name
        end
      end

      def render_inline_element(type, content, node)
        require 'review/renderer/latex_renderer/inline_element_renderer'
        # Always create a new inline renderer with current rendering context
        # This ensures that context changes (like table context) are properly reflected
        inline_renderer = InlineElementRenderer.new(
          self,
          book: @book,
          chapter: @chapter,
          rendering_context: @rendering_context
        )
        inline_renderer.render(type, content, node)
      end

      def render_children(node)
        return '' unless node.children

        node.children.map { |child| visit(child) }.join
      end

      def visit_reference(node)
        # Handle ReferenceNode - simply render the content
        escape(node.content || '')
      end

      # Render document children with proper separation
      def render_document_children(node)
        return '' unless node.children

        results = []
        node.children.each_with_index do |child, _index|
          result = visit(child)
          next if result.nil? || result.empty?

          # Add proper separation after raw embeds
          if child.respond_to?(:embed_type) && child.embed_type == :raw && !result.end_with?("\n")
            result += "\n"
          end

          results << result
        end

        results.join
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

      def normalize_id(id)
        # LaTeX-safe ID normalization
        id.gsub(/[^a-zA-Z0-9_-]/, '_')
      end

      # Check if content looks like list item content
      # @param content [String] Text content to check
      # @return [Boolean] True if content appears to be a list item
      def list_item_content?(content)
        content = content.strip
        # Check for unordered list (starts with *)
        # Check for ordered list (starts with number followed by .)
        # Check for definition list (starts with word followed by :)
        content.match?(/\A\*\s/) || content.match?(/\A\d+\.\s/) || content.match?(/\A\w.*:\s/)
      end

      def visit_footnote(_node)
        # FootnoteNode represents a footnote definition (//footnote[id][content])
        # These should not be rendered in the output - they only define the content
        # Footnotes are rendered when referenced via @<fn>{id} (InlineNode)
        ''
      end

      # Check caption position configuration
      def caption_top?(type)
        unless %w[top bottom].include?(@book&.config&.dig('caption_position', type))
          # Default to top if not configured
          return true
        end

        @book.config['caption_position'][type] != 'bottom'
      end

      # Build metrics string for images (width, height, etc.)
      def build_metrics_string(metrics)
        return nil unless metrics && metrics.is_a?(Hash)

        parts = []
        if metrics['scale']
          parts << "scale=#{metrics['scale']}"
        end
        if metrics['width']
          parts << "width=#{metrics['width']}"
        end
        if metrics['height']
          parts << "height=#{metrics['height']}"
        end

        parts.empty? ? nil : parts.join(',')
      end

      # Apply noindent if the node has the noindent attribute
      def apply_noindent_if_needed(node, content)
        if node.attribute?(:noindent)
          "\\noindent\n#{content}"
        else
          content
        end
      end

      # Check if Part document should be wrapped with reviewpart environment
      def should_wrap_part_with_reviewpart?
        @chapter.is_a?(ReVIEW::Book::Part)
      end

      # Generate TOC entry only (for nodisp headlines)
      def generate_toc_entry(level, caption)
        toc_type = case level
                   when 1
                     'chapter'
                   when 2
                     'section'
                   else
                     'subsection'
                   end
        "\\addcontentsline{toc}{#{toc_type}}{#{caption}}\n"
      end

      # Generate unnumbered headline with TOC entry (for nonum headlines)
      def generate_nonum_headline(level, caption, node)
        section_command = get_base_section_name(level) + '*'
        label_part = generate_label_for_node(level, node)

        result = []
        result << "\\#{section_command}{#{caption}}"

        # Add TOC entry
        toc_type = case level
                   when 1
                     'chapter'
                   when 2
                     'section'
                   else
                     'subsection'
                   end
        result << "\\addcontentsline{toc}{#{toc_type}}{#{caption}}"

        unless label_part.empty?
          result << label_part
        end

        result.join("\n") + "\n"
      end

      # Generate unnumbered headline without TOC entry (for notoc headlines)
      def generate_notoc_headline(level, caption, node)
        section_command = get_base_section_name(level) + '*'
        label_part = generate_label_for_node(level, node)

        result = []
        result << "\\#{section_command}{#{caption}}"

        unless label_part.empty?
          result << label_part
        end

        result.join("\n") + "\n"
      end

      # Get base section name without star
      def get_base_section_name(level)
        if @chapter.is_a?(ReVIEW::Book::Part) && level == 1
          'part'
        else
          HEADLINE[level] || raise(CompileError, "Unsupported headline level: #{level}")
        end
      end

      # Generate label for headline node
      def generate_label_for_node(level, node)
        if level == 1 && @chapter
          "\\label{chap:#{@chapter.id}}"
        elsif @sec_counter && level >= 2
          anchor = @sec_counter.anchor(level)
          "\\label{sec:#{anchor}}"
        elsif node.label
          "\\label{#{escape(node.label)}}"
        else
          ''
        end
      end

      # Generate column label for hypertarget (matches LATEXBuilder behavior)
      def generate_column_label(node, caption)
        # Use explicit label if provided, otherwise use caption
        id = node.label || caption || 'column'

        # Get column number from chapter's column index
        if @chapter && @chapter.respond_to?(:column_index) && @chapter.column_index
          begin
            column_item = @chapter.column_index[id]
            num = column_item ? column_item.number : 1
          rescue StandardError
            num = 1
          end
        else
          num = 1
        end

        "column:#{@chapter&.id || 'unknown'}:#{num}"
      end

      # Process //raw command with LATEXBuilder-compatible behavior
      def process_raw_embed(node)
        # Check if this embed is targeted for LaTeX builder
        unless node.targeted_for?('latex')
          return ''
        end

        # Get processed content - use content if available, otherwise parse arg
        content = if node.content
                    node.content
                  elsif node.arg
                    # Fallback: parse arg directly if content is not set
                    if matched = node.arg.match(/\A\|(.*?)\|(.*)/)
                      matched[2] # Extract content part after |builder|
                    else
                      node.arg
                    end
                  else
                    ''
                  end

        # Convert \n to actual newlines
        content.gsub('\\n', "\n")
      end
    end
  end
end
