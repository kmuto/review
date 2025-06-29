# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/renderer/base'
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

        # Initialize document status tracking like LATEXBuilder
        @doc_status = { table: false, caption: false, column: false }
        @foottext = {}

        # Initialize Part environment tracking for reviewpart wrapper
        @part_env_opened = false
      end

      def visit_document(node)
        # Build indexes using AST::Indexer for proper footnote support
        if @chapter && !@ast_indexer
          require 'review/ast/indexer'
          @ast_indexer = ReVIEW::AST::Indexer.new(@chapter)
          @ast_indexer.build_indexes(node)

          # Make indexes available to chapter and book
          @chapter.instance_variable_set(:@footnote_index, @ast_indexer.footnote_index)
          @chapter.instance_variable_set(:@endnote_index, @ast_indexer.endnote_index)
          @chapter.instance_variable_set(:@list_index, @ast_indexer.list_index)
          @chapter.instance_variable_set(:@table_index, @ast_indexer.table_index)
          @chapter.instance_variable_set(:@equation_index, @ast_indexer.equation_index)
          @chapter.instance_variable_set(:@image_index, @ast_indexer.image_index)
          @chapter.instance_variable_set(:@icon_index, @ast_indexer.icon_index)
          @chapter.instance_variable_set(:@numberless_image_index, @ast_indexer.numberless_image_index)
          @chapter.instance_variable_set(:@indepimage_index, @ast_indexer.indepimage_index)
          @chapter.instance_variable_set(:@headline_index, @ast_indexer.headline_index)
          @chapter.instance_variable_set(:@column_index, @ast_indexer.column_index)
          @chapter.instance_variable_set(:@bibpaper_index, @ast_indexer.bibpaper_index)

          # Build book-wide indexes for cross-chapter references if book is available
          ReVIEW::AST::Indexer.build_book_indexes(@book) if @book
        end

        # Generate content with proper separation between document-level elements
        content = render_document_children(node)

        # Close the reviewpart environment if it was opened
        if @part_env_opened
          content += "\\end{reviewpart}\n"
        end

        # Add remaining footnotetext commands if needed
        # Always output remaining footnotetext entries (they were already marked for separation)
        unless @foottext.empty?
          @foottext.each do |footnote_id, footnote_number|
            next unless @chapter && @chapter.footnote_index

            begin
              index_item = @chapter.footnote_index[footnote_id]
              footnote_content = if index_item.footnote_node?
                                   render_footnote_ast(index_item.footnote_node)
                                 else
                                   escape(index_item.content || '')
                                 end
              content += "\\footnotetext[#{footnote_number}]{#{footnote_content}}\n"
            rescue StandardError => e
              raise NotImplementedError, "Footnote not found in index: #{footnote_id} (#{e.message})"
            end
          end
          @foottext.clear
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
        # Set caption context for footnote processing
        @doc_status[:caption] = true if node.caption
        caption = render_children(node.caption) if node.caption
        @doc_status[:caption] = false

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

        # Add footnotetext commands for footnotes used in caption
        @foottext.each do |footnote_id, footnote_number|
          next unless @chapter && @chapter.footnote_index

          begin
            index_item = @chapter.footnote_index[footnote_id]
            # Try to get FootnoteNode for proper AST rendering
            footnote_content = if index_item.footnote_node?
                                 # Render the footnote AST children properly
                                 render_footnote_ast(index_item.footnote_node)
                               else
                                 # Fallback to text content
                                 escape(index_item.content || '')
                               end
            result += "\\footnotetext[#{footnote_number}]{#{footnote_content}}\n"
          rescue StandardError => e
            raise NotImplementedError, "Footnote not found in index: #{footnote_id} (#{e.message})"
          end
        end
        @foottext.clear

        result
      end

      def visit_code_line(node)
        # Render children (TextNode and InlineNode) to process inline elements properly
        content = render_children(node)
        # Add proper newline for LaTeX code line formatting
        "#{content}\n"
      end

      def visit_table(node)
        # Set caption context for footnote processing
        @doc_status[:caption] = true if node.caption
        caption = render_children(node.caption) if node.caption
        @doc_status[:caption] = false

        table_type = node.respond_to?(:table_type) ? node.table_type : :table

        # Handle imgtable specially - it should be rendered as an image
        if table_type == :imgtable
          return visit_imgtable(node, caption)
        end

        # Set table context for footnote processing
        @doc_status[:table] = true

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

        # Process all rows using visitor pattern
        all_rows = node.header_rows + node.body_rows
        all_rows.each do |row|
          row_content = visit(row)
          result << "#{row_content} \\\\  \\hline"
        end

        result << '\\end{reviewtable}'
        result << '\\end{table}'

        # Clear table context and add footnotetext commands for table footnotes
        @doc_status[:table] = false
        table_result = result.join("\n") + "\n"

        # Add footnotetext commands for footnotes used in table
        @foottext.each do |footnote_id, footnote_number|
          next unless @chapter && @chapter.footnote_index

          begin
            footnote_item = @chapter.footnote_index[footnote_id]
            if footnote_item
              # Try to get FootnoteNode for proper AST rendering
              footnote_content = if footnote_item.footnote_node?
                                   # Render the footnote AST children properly
                                   render_footnote_ast(footnote_item.footnote_node)
                                 else
                                   # Fallback to text content
                                   escape(footnote_item.content || '')
                                 end
              table_result += "\\footnotetext[#{footnote_number}]{#{footnote_content}}\n"
            else
              raise NotImplementedError, "Footnote not found in index: #{footnote_id}"
            end
          rescue StandardError => e
            raise NotImplementedError, "Footnote not found in index: #{footnote_id} (#{e.message})"
          end
        end
        @foottext.clear

        table_result
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
        # Process all cells in the row using visitor pattern
        cells = node.children.map { |cell| visit(cell) }
        cells.join(' & ')
      end

      def visit_table_cell(node)
        content = render_children(node)
        # Use cell_type to determine LaTeX formatting
        if node.cell_type == :th
          "\\reviewth{#{content}}"
        else
          content
        end
      end

      def visit_image(node)
        # Set caption context for footnote processing
        @doc_status[:caption] = true if node.caption
        caption = render_children(node.caption) if node.caption
        @doc_status[:caption] = false

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

        # Add footnotetext commands for footnotes used in caption
        @foottext.each do |footnote_id, footnote_number|
          next unless @chapter && @chapter.footnote_index

          begin
            index_item = @chapter.footnote_index[footnote_id]
            # Try to get FootnoteNode for proper AST rendering
            footnote_content = if index_item.footnote_node?
                                 # Render the footnote AST children properly
                                 render_footnote_ast(index_item.footnote_node)
                               else
                                 # Fallback to text content
                                 escape(index_item.content || '')
                               end
            image_result += "\\footnotetext[#{footnote_number}]{#{footnote_content}}\n"
          rescue StandardError => e
            raise NotImplementedError, "Footnote not found in index: #{footnote_id} (#{e.message})"
          end
        end
        @foottext.clear

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
          # Comment blocks should not produce any output in final document
          ''
        when 'beginchild', 'endchild' # rubocop:disable Lint/DuplicateBranch
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

      private

      HEADLINE = {
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

      def render_inline_element(type, content, node) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
        case type.to_s
        when 'b'
          "\\reviewbold{#{content}}"
        when 'strong'
          "\\reviewstrong{#{content}}"
        when 'i'
          "\\reviewit{#{content}}"
        when 'em'
          "\\reviewem{#{content}}"
        when 'tt'
          "\\reviewtt{#{content}}"
        when 'ttb'
          "\\reviewttb{#{content}}"
        when 'tti'
          "\\reviewtti{#{content}}"
        when 'code'
          "\\reviewcode{#{content}}"
        when 'u', 'underline'
          "\\reviewunderline{#{content}}"
        when 'href'
          if node.args && node.args.length >= 2
            url = escape_url(node.args[0])
            text = escape(node.args[1])
            "\\href{#{url}}{#{text}}"
          else
            # For single argument href, get raw text from first text child to avoid double escaping
            raw_url = if node.children && node.children.first.respond_to?(:content)
                        node.children.first.content
                      else
                        raise NotImplementedError, "URL is invalid: #{content}"
                      end
            url_content = escape_url(raw_url)
            "\\url{#{url_content}}"
          end
        when 'fn'
          if node.args && node.args.first
            footnote_id = node.args.first.to_s
            # Handle footnotes based on config or context like LATEXBuilder
            # For AST renderer, always use footnotetext separation for problematic contexts
            use_footnotetext = (@book&.config&.key?('footnotetext') && @book.config['footnotetext']) ||
                               @doc_status[:table] || @doc_status[:caption] || @doc_status[:column]

            if use_footnotetext
              if @chapter && @chapter.footnote_index
                begin
                  footnote_number = @chapter.footnote_index.number(footnote_id)
                  @foottext[footnote_id] = footnote_number
                  '\\protect\\footnotemark'
                rescue StandardError => e # rubocop:disable Metrics/BlockNesting
                  raise NotImplementedError, "Footnote inline processing failed for #{footnote_id}: #{e.message}"
                end
              else
                '\\protect\\footnotemark'
              end
            elsif @chapter && @chapter.footnote_index
              # Get footnote content from index
              begin
                index_item = @chapter.footnote_index[footnote_id]

                # Try to get FootnoteNode for proper AST rendering
                footnote_content = if index_item.footnote_node?
                                     # Render the footnote AST children properly
                                     render_footnote_ast(index_item.footnote_node)
                                   else
                                     # Fallback to text content
                                     escape(index_item.content || '')
                                   end

                "\\footnote{#{footnote_content}}"
              rescue StandardError => _e
                # Fallback to footnote ID if content not found
                "\\footnote{#{footnote_id}}"
              end
            else
              "\\footnote{#{footnote_id}}"
            end
          else
            "\\footnote{#{content}}"
          end
        when 'kw'
          if node.args && node.args.length >= 2
            term = escape(node.args[0])
            description = escape(node.args[1])
            "\\reviewkw{#{term}}（#{description}）"
          else
            "\\reviewkw{#{content}}"
          end
        when 'chap'
          if node.args && node.args.first
            # Use Re:VIEW chapter number reference like LATEXBuilder
            chapter_id = node.args.first
            if @book && @book.chapter_index
              begin
                chapter_number = @book.chapter_index.number(chapter_id)
                "\\reviewchapref{#{chapter_number}}{chap:#{chapter_id}}"
              rescue StandardError => e
                raise NotImplementedError, "Chapter reference failed for #{chapter_id}: #{e.message}"
              end
            else
              "\\reviewchapref{#{escape(chapter_id)}}{chap:#{escape(chapter_id)}}"
            end
          else
            content
          end
        when 'chapref'
          if node.args && node.args.first
            # Use Re:VIEW chapter title reference like LATEXBuilder
            chapter_id = node.args.first
            if @book && @book.chapter_index
              begin
                title = @book.chapter_index.display_string(chapter_id)
                "\\reviewchapref{#{escape(title)}}{chap:#{chapter_id}}"
              rescue StandardError => e
                raise NotImplementedError, "Chapter title reference failed for #{chapter_id}: #{e.message}"
              end
            else
              "\\reviewchapref{#{escape(chapter_id)}}{chap:#{escape(chapter_id)}}"
            end
          else
            content
          end
        when 'list', 'listref'
          if node.args && !node.args.empty?

            if node.args.length == 2
              # Cross-chapter reference: [chapter_id, list_id]
              chapter_id, list_id = node.args

              # Find the target chapter
              target_chapter = @book&.contents&.detect { |chap| chap.id == chapter_id }
              unless target_chapter
                raise NotImplementedError, "Cross-chapter list reference failed: chapter '#{chapter_id}' not found"
              end

              # Ensure the target chapter has list index - this should already be built by build_book_indexes
              unless target_chapter.list_index
                raise NotImplementedError, "Cross-chapter list reference failed: no list index for chapter '#{chapter_id}'"
              end

              begin
                list_item = target_chapter.list_index.number(list_id)
                if target_chapter.number
                  "\\reviewlistref{#{target_chapter.number}.#{list_item}}"
                else
                  "\\reviewlistref{#{list_item}}"
                end
              rescue StandardError => e
                raise NotImplementedError, "Cross-chapter list reference failed for #{chapter_id}|#{list_id}: #{e.message}"
              end
            elsif node.args.length == 1
              # Same-chapter reference
              list_ref = node.args.first.to_s
              if @chapter && @chapter.list_index
                begin
                  list_item = @chapter.list_index.number(list_ref)
                  if @chapter.number
                    "\\reviewlistref{#{@chapter.number}.#{list_item}}"
                  else
                    "\\reviewlistref{#{list_item}}"
                  end
                rescue StandardError => e
                  raise NotImplementedError, "List reference failed for #{list_ref}: #{e.message}"
                end
              else
                "\\ref{#{escape(list_ref)}}"
              end
            else
              content
            end
          else
            content
          end
        when 'table', 'tableref'
          if node.args && !node.args.empty?
            if node.args.length == 2
              # Cross-chapter reference: [chapter_id, table_id]
              chapter_id, table_id = node.args

              # Find the target chapter
              target_chapter = @book&.contents&.detect { |chap| chap.id == chapter_id }
              unless target_chapter
                raise NotImplementedError, "Cross-chapter table reference failed: chapter '#{chapter_id}' not found"
              end

              # Ensure the target chapter has table index - this should already be built by build_book_indexes
              unless target_chapter.table_index
                raise NotImplementedError, "Cross-chapter table reference failed: no table index for chapter '#{chapter_id}'"
              end

              begin
                table_item = target_chapter.table_index.number(table_id)
                table_label = "table:#{chapter_id}:#{table_id}"
                if target_chapter.number
                  "\\reviewtableref{#{target_chapter.number}.#{table_item}}{#{table_label}}"
                else
                  "\\reviewtableref{#{table_item}}{#{table_label}}"
                end
              rescue StandardError => e
                raise NotImplementedError, "Cross-chapter table reference failed for #{chapter_id}|#{table_id}: #{e.message}"
              end
            elsif node.args.length == 1
              # Same-chapter reference
              table_ref = node.args.first.to_s
              if @chapter && @chapter.table_index
                begin
                  table_item = @chapter.table_index.number(table_ref)
                  table_label = "table:#{@chapter.id}:#{table_ref}"
                  if @chapter.number
                    "\\reviewtableref{#{@chapter.number}.#{table_item}}{#{table_label}}"
                  else
                    "\\reviewtableref{#{table_item}}{#{table_label}}"
                  end
                rescue StandardError => e
                  raise NotImplementedError, "Table reference failed for #{table_ref}: #{e.message}"
                end
              else
                "\\ref{#{escape(table_ref)}}"
              end
            else
              content
            end
          else
            content
          end
        when 'img', 'imgref'
          if node.args && !node.args.empty?
            if node.args.length == 2
              # Cross-chapter reference: [chapter_id, image_id]
              chapter_id, image_id = node.args

              # Find the target chapter
              target_chapter = @book&.contents&.detect { |chap| chap.id == chapter_id }
              unless target_chapter
                raise NotImplementedError, "Cross-chapter image reference failed: chapter '#{chapter_id}' not found"
              end

              # Ensure the target chapter has image index - this should already be built by build_book_indexes
              unless target_chapter.image_index
                raise NotImplementedError, "Cross-chapter image reference failed: no image index for chapter '#{chapter_id}'"
              end

              begin
                image_item = target_chapter.image_index.number(image_id)
                image_label = "image:#{chapter_id}:#{image_id}"
                if target_chapter.number
                  "\\reviewimageref{#{target_chapter.number}.#{image_item}}{#{image_label}}"
                else
                  "\\reviewimageref{#{image_item}}{#{image_label}}"
                end
              rescue StandardError => e
                raise NotImplementedError, "Cross-chapter image reference failed for #{chapter_id}|#{image_id}: #{e.message}"
              end
            elsif node.args.length == 1
              # Same-chapter reference
              image_ref = node.args.first.to_s
              if @chapter && @chapter.image_index
                begin
                  image_item = @chapter.image_index.number(image_ref)
                  image_label = "image:#{@chapter.id}:#{image_ref}"
                  if @chapter.number
                    "\\reviewimageref{#{@chapter.number}.#{image_item}}{#{image_label}}"
                  else
                    "\\reviewimageref{#{image_item}}{#{image_label}}"
                  end
                rescue StandardError => e
                  raise NotImplementedError, "Image reference failed for #{image_ref}: #{e.message}"
                end
              else
                # Don't escape underscores in ref labels
                "\\ref{#{image_ref}}"
              end
            else
              content
            end
          else
            content
          end
        when 'eq', 'eqref'
          if node.args && node.args.first
            # Use Re:VIEW equation reference like LATEXBuilder
            equation_id = node.args.first
            if @chapter && @chapter.equation_index
              begin
                equation_item = @chapter.equation_index.number(equation_id)
                if @chapter.number
                  "\\reviewequationref{#{@chapter.number}.#{equation_item}}"
                else
                  "\\reviewequationref{#{equation_item}}"
                end
              rescue StandardError => e
                raise NotImplementedError, "Equation reference failed for #{equation_id}: #{e.message}"
              end
            else
              raise NotImplementedError, 'Equation reference requires chapter context but none provided'
            end
          else
            content
          end
        when 'bib', 'bibref'
          if node.args && node.args.first
            # Don't escape underscores in bibliography keys - they're allowed in LaTeX cite commands
            bib_key = node.args.first.to_s
            "\\cite{#{bib_key}}"
          else
            content
          end
        when 'm'
          # Mathematical expressions - don't escape content
          "$#{node.args&.first || content}$"
        when 'sup', 'superscript'
          "\\textsuperscript{#{content}}"
        when 'sub', 'subscript'
          "\\textsubscript{#{content}}"
        when 'del', 'strike'
          "\\reviewstrike{#{content}}"
        when 'ins', 'insert'
          "\\reviewinsert{#{content}}"
        when 'uchar'
          # Unicode character handling like LATEXBuilder
          if node.args && node.args.first
            char_code = node.args.first
            "\\UTF{#{escape(char_code)}}"
          else
            content
          end
        when 'br'
          "\\\\\n"
        when 'idx'
          if node.args && node.args.first
            # Index entry like LATEXBuilder
            "\\index{#{escape(node.args.first)}}"
          else
            content
          end
        when 'hidx'
          if node.args && node.args.first
            # Hidden index entry like LATEXBuilder
            "\\index{#{escape(node.args.first)}}#{content}"
          else
            content
          end
        when 'ruby'
          if node.args && node.args.length >= 2
            base_text = escape(node.args[0])
            ruby_text = escape(node.args[1])
            "\\ruby{#{base_text}}{#{ruby_text}}"
          else
            content
          end
        when 'icon'
          if node.args && node.args.first
            icon_id = node.args.first
            if @chapter&.image(icon_id)&.path
              command = @book&.config&.check_version('2', exception: false) ? 'includegraphics' : 'reviewicon'
              "\\#{command}{#{@chapter.image(icon_id).path}}"
            else
              # Fallback for missing image
              "\\verb|--[[path = #{icon_id}]]--|"
            end
          else
            content
          end
        when 'ami'
          "\\reviewami{#{content}}"
        when 'w', 'wb'
          # Word expansion - pass through content
          content
        when 'hd'
          if node.args && node.args.first
            # Heading reference - handle both simple and chapter|heading format
            heading_ref = node.args.first
            handle_heading_reference(heading_ref) do |section_number, section_label, section_title|
              "\\reviewsecref{「#{section_number} #{escape(section_title)}」}{#{section_label}}"
            end
          else
            content
          end
        when 'labelref', 'ref'
          if node.args && node.args.first
            ref_id = node.args.first
            "\\ref{#{escape(ref_id)}}"
          else
            content
          end
        when 'title'
          if node.args && node.args.first
            # Book/chapter title reference
            chapter_id = node.args.first
            if @book && @book.chapter_index
              begin
                title = @book.chapter_index.title(chapter_id)
                if @book.config['chapterlink']
                  "\\reviewchapref{#{escape(title)}}{chap:#{chapter_id}}"
                else
                  escape(title)
                end
              rescue StandardError => e
                raise NotImplementedError, "Chapter title reference failed for #{chapter_id}: #{e.message}"
              end
            else
              "\\reviewtitle{#{escape(chapter_id)}}"
            end
          else
            content
          end
        when 'sec'
          if node.args && node.args.first
            # Section reference - use Re:VIEW section reference like LATEXBuilder
            heading_ref = node.args.first
            handle_heading_reference(heading_ref) do |section_number, section_label, _section_title|
              "\\reviewsecref{#{section_number}}{#{section_label}}"
            end
          else
            content
          end
        when 'secref' # rubocop:disable Lint/DuplicateBranch
          if node.args && node.args.first
            # Section reference with full title - use Re:VIEW section reference like LATEXBuilder
            heading_ref = node.args.first
            handle_heading_reference(heading_ref) do |section_number, section_label, section_title|
              "\\reviewsecref{「#{section_number} #{escape(section_title)}」}{#{section_label}}"
            end
          else
            content
          end
        when 'sectitle'
          if node.args && node.args.first
            # Section title only - use Re:VIEW section reference like LATEXBuilder
            heading_ref = node.args.first
            handle_heading_reference(heading_ref) do |_section_number, section_label, section_title|
              "\\reviewsecref{#{escape(section_title)}}{#{section_label}}"
            end
          else
            content
          end
        when 'bou'
          # Boudou (emphasis)
          "\\reviewbou{#{content}}"
        when 'balloon'
          # Balloon annotation - content contains the balloon text
          "\\reviewballoon{#{content}}"
        when 'endnote'
          if node.args && node.args.first
            # Endnote reference
            ref_id = node.args.first
            if @chapter && @chapter.endnote_index
              begin
                endnote_number = @chapter.endnote_index.number(ref_id)
                "\\endnotemark[#{endnote_number}]"
              rescue StandardError => _e
                "\\endnote{#{escape(ref_id)}}"
              end
            else
              "\\endnote{#{escape(ref_id)}}"
            end
          else
            content
          end
        when 'pageref'
          if node.args && node.args.first
            # Page reference
            ref_id = node.args.first
            "\\pageref{#{escape(ref_id)}}"
          else
            content
          end
        when 'raw'
          if node.args && node.args.first
            # Raw content for specific format
            format = node.args.first
            if ['latex', 'tex'].include?(format)
              content
            else
              '' # Ignore raw content for other formats
            end
          else
            content
          end
        when 'embed' # rubocop:disable Lint/DuplicateBranch
          # Embedded content - pass through
          content
        else # rubocop:disable Lint/DuplicateBranch
          # Fallback: treat unknown inline elements as plain text
          # This is more forgiving than raising an error
          content
        end
      end

      def render_children(node)
        return '' unless node.children

        node.children.map { |child| visit(child) }.join
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

      # Check if a newline should be added before this child element
      # @param child [AST::Node] Child node to check
      # @return [Boolean] True if newline should be added
      def should_add_newline_before?(child)
        # For TextNodes, check if content indicates a new line
        if child.class.name.include?('TextNode')
          content = child.content.to_s
          # Add newline before content that starts a new logical line
          # This includes list items and standalone text that would be on its own line
          return list_item_content?(content) ||
                 content.match?(/\A[A-Z]/) || # Starts with capital letter (new sentence)
                 content.match?(/\A\w+:/) # Starts with word followed by colon
        end

        false
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
        # Debug: print node details
        # puts "DEBUG process_raw_embed: arg=#{node.arg.inspect}, target_builders=#{node.target_builders.inspect}, content=#{node.content.inspect}"

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

      # Render footnote AST children
      def render_footnote_ast(footnote_node)
        return '' unless footnote_node.respond_to?(:children) && footnote_node.children

        # Render all children and join the result
        footnote_node.children.map { |child| visit(child) }.join
      end

      # Handle heading references with cross-chapter support
      def handle_heading_reference(heading_ref, fallback_format = '\\ref{%s}')
        if heading_ref.include?('|')
          # Cross-chapter reference format: chapter|heading or chapter|section|subsection
          parts = heading_ref.split('|')
          chapter_id = parts[0]
          heading_parts = parts[1..-1]

          # Try to find the target chapter and its headline
          target_chapter = @book.chapters.find { |ch| ch.id == chapter_id } if @book

          if target_chapter && target_chapter.headline_index
            # Build the hierarchical heading ID like IndexBuilder does
            heading_id = heading_parts.join('|')

            begin
              headline_item = target_chapter.headline_index[heading_id]
              if headline_item
                # Get the section number from the target chapter
                section_number = target_chapter.headline_index.number(heading_id)
                section_label = "sec:#{chapter_id}-#{section_number.tr('.', '-')}"
                yield(section_number, section_label, headline_item.caption || heading_id)
              else
                # Fallback when heading not found in target chapter
                fallback_format % "#{chapter_id}-#{heading_parts.join('-')}"
              end
            rescue StandardError
              # Fallback on any error
              fallback_format % "#{chapter_id}-#{heading_parts.join('-')}"
            end
          else
            # Fallback when target chapter not found or no headline index
            fallback_format % "#{chapter_id}-#{heading_parts.join('-')}"
          end
        elsif @chapter && @chapter.headline_index
          # Simple heading reference within current chapter
          begin
            headline_item = @chapter.headline_index[heading_ref]
            if headline_item
              # Generate section number and label like LATEXBuilder
              section_number = @chapter.headline_index.number(heading_ref)
              section_label = "sec:#{section_number.tr('.', '-')}"
              yield(section_number, section_label, headline_item.caption || heading_ref)
            else
              # Fallback if headline not found in index
              fallback_format % escape(heading_ref)
            end
          rescue StandardError
            # Fallback on any error
            fallback_format % escape(heading_ref)
          end
        else
          # Fallback when no headline index available
          fallback_format % escape(heading_ref)
        end
      end
    end
  end
end
