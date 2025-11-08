# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/ast/caption_node'
require 'review/ast/table_column_width_parser'
require 'review/latexutils'
require 'review/sec_counter'
require 'review/i18n'
require 'review/textutils'
require_relative 'base'
require_relative 'rendering_context'
require_relative 'text_formatter'
require_relative 'latex/inline_context'
require_relative 'latex/inline_element_handler'

module ReVIEW
  module Renderer
    class LatexRenderer < Base
      include ReVIEW::LaTeXUtils
      include ReVIEW::TextUtils

      attr_reader :chapter, :book, :rendering_context

      def initialize(chapter)
        super

        # For AST rendering, we need to set up indexing properly
        # The indexing will be done when we process the AST
        @ast_indexer = nil
        @ast_compiler = nil
        @list_structure_normalizer = nil

        I18n.setup(config['language'] || 'ja')

        # Initialize LaTeX character escaping
        initialize_metachars(config['texcommand'])

        # Initialize section counter like LATEXBuilder
        @sec_counter = SecCounter.new(5, @chapter) if @chapter

        # Initialize RenderingContext for cleaner state management
        @rendering_context = RenderingContext.new(:document)

        # Initialize LaTeX-specific inline context and inline element handler
        @inline_context = Latex::InlineContext.new(
          config: config,
          book: book,
          chapter: chapter,
          renderer: self
        )
        @inline_element_handler = Latex::InlineElementHandler.new(@inline_context)
      end

      # Format type for this renderer
      # @return [Symbol] Format type :latex
      def format_type
        :latex
      end

      def visit_document(node)
        # Generate content with proper separation between document-level elements
        content = render_document_children(node)

        # Wrap Part documents with reviewpart environment
        if should_wrap_part_with_reviewpart?
          content = "\\begin{reviewpart}\n" + content + "\\end{reviewpart}\n"
        end

        # Add any remaining collected footnotetext commands
        if @rendering_context.footnote_collector.any?
          content += generate_footnotetext_from_collector(@rendering_context.footnote_collector)
          @rendering_context.footnote_collector.clear
        end

        # Ensure content ends with single newline if it contains content
        # Remove all trailing newlines and add exactly one back
        if content && !content.empty?
          content.sub(/\n+\z/, '') + "\n"
        else
          content || ''
        end
      end

      def visit_headline(node)
        level = node.level
        caption = render_children(node.caption_node) if node.caption_node

        # Handle special headline options (nonum, notoc, nodisp)
        # These do NOT increment the section counter (matching LATEXBuilder behavior)
        if node.nodisp?
          # nodisp: Only add TOC entry, no visible heading
          return generate_toc_entry(level, caption)
        elsif node.nonum?
          # nonum: Unnumbered section that appears in TOC
          return generate_nonum_headline(level, caption, node)
        elsif node.notoc?
          # notoc: Unnumbered section that does NOT appear in TOC
          return generate_notoc_headline(level, caption, node)
        end

        # Update section counter like LATEXBuilder (only for regular numbered headlines)
        if @sec_counter
          @sec_counter.inc(level)
        end

        # Regular headline processing
        section_command = headline_name(level)

        # Format with exact newlines like LATEXBuilder to match expected format
        result = []
        result << "\\#{section_command}{#{caption}}"

        # Add \addcontentsline for unnumbered sections within toclevel
        # Match LATEXBuilder logic: only add to TOC if level is within toclevel
        if (level > config['secnolevel'] || (@chapter.number.to_s.empty? && level > 1)) &&
           level <= config['toclevel'].to_i
          # Get the base section name for TOC entry
          toc_section_name = get_base_section_name(level)
          result << "\\addcontentsline{toc}{#{toc_section_name}}{#{caption}}"
        end

        # Generate labels like LATEXBuilder - add both automatic and custom labels
        if level == 1 && @chapter
          result << "\\label{chap:#{@chapter.id}}"
        elsif @sec_counter && level >= 2
          # Generate section labels like LATEXBuilder (sec:x-y format)
          anchor = @sec_counter.anchor(level)
          result << "\\label{sec:#{anchor}}"
          # Add custom label if specified (only for level > 1, matching LATEXBuilder)
          if node.label && !node.label.empty?
            result << "\\label{#{escape(node.label)}}"
          end
        end

        result.join("\n") + "\n\n"
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

      # Process caption for code blocks with proper context management
      # @param node [CodeBlockNode] The code block node
      # @return [Array<String, Object>] [caption, caption_collector]
      def process_code_block_caption(node)
        caption = nil
        caption_collector = nil

        if node.caption_node
          @rendering_context.with_child_context(:caption) do |caption_context|
            caption = render_children_with_context(node.caption_node, caption_context)
            caption_collector = caption_context.footnote_collector
          end
        end

        [caption, caption_collector]
      end

      # Add footnotetext commands from collector to result
      # @param result [String] The rendered result
      # @param caption_collector [Object] The footnote collector
      # @return [String] Result with footnotetext commands appended
      def append_footnotetext_from_collector(result, caption_collector)
        if caption_collector && caption_collector.any?
          result += generate_footnotetext_from_collector(caption_collector)
          caption_collector.clear
        end
        result
      end

      # Visit list code block
      def visit_code_block_list(node)
        caption, caption_collector = process_code_block_caption(node)
        content = render_children(node)
        result = visit_list_block(node, content, caption)
        append_footnotetext_from_collector(result, caption_collector)
      end

      # Visit listnum code block (list with line numbers)
      def visit_code_block_listnum(node)
        caption, caption_collector = process_code_block_caption(node)
        content = render_children(node)
        result = visit_list_block(node, add_line_numbers(content, node), caption)
        append_footnotetext_from_collector(result, caption_collector)
      end

      # Visit emlist code block
      def visit_code_block_emlist(node)
        caption, caption_collector = process_code_block_caption(node)
        content = render_children(node)
        result = visit_emlist_block(node, content, caption)
        append_footnotetext_from_collector(result, caption_collector)
      end

      # Visit emlistnum code block (emlist with line numbers)
      def visit_code_block_emlistnum(node)
        caption, caption_collector = process_code_block_caption(node)
        content = render_children(node)
        result = visit_emlist_block(node, add_line_numbers(content, node), caption)
        append_footnotetext_from_collector(result, caption_collector)
      end

      # Visit cmd code block
      def visit_code_block_cmd(node)
        caption, caption_collector = process_code_block_caption(node)
        content = render_children(node)
        result = visit_cmd_block(node, content, caption)
        append_footnotetext_from_collector(result, caption_collector)
      end

      # Visit source code block
      def visit_code_block_source(node)
        caption, caption_collector = process_code_block_caption(node)
        content = render_children(node)
        result = visit_source_block(node, content, caption)
        append_footnotetext_from_collector(result, caption_collector)
      end

      def visit_code_line(node)
        # Render children (TextNode and InlineNode) to process inline elements properly
        content = render_children(node)
        # Add proper newline for LaTeX code line formatting
        "#{content}\n"
      end

      def visit_table(node)
        # Process caption with proper context management and collect footnotes
        caption = nil
        caption_collector = nil

        if node.caption_node
          @rendering_context.with_child_context(:caption) do |caption_context|
            caption = render_children_with_context(node.caption_node, caption_context)
            # Save the collector for later processing
            caption_collector = caption_context.footnote_collector
          end
        end

        table_type = node.table_type

        # Handle imgtable specially - it should be rendered as an image
        if table_type == :imgtable
          result = visit_imgtable(node, caption)
          # Add collected footnotetext commands from caption context for imgtable
          if caption_collector && caption_collector.any?
            result += generate_footnotetext_from_collector(caption_collector)
            caption_collector.clear
          end
          return result
        end

        # Process table content with table context
        table_context = nil
        table_content = @rendering_context.with_child_context(:table) do |ctx|
          table_context = ctx

          # Get column specification from TableNode (set by TsizeProcessor)
          # or use default values if not set
          col_spec = node.col_spec || node.default_col_spec
          cellwidth = node.cellwidth || node.default_cellwidth

          # Store cellwidth temporarily for visit_table_cell_with_index to access
          # This is needed because cell rendering happens in nested visitor calls
          @current_table_cellwidth = cellwidth

          # Get all rows for processing
          all_rows = node.header_rows + node.body_rows

          result = []

          # Only output \begin{table} if caption is present (like LATEXBuilder)
          if caption.present?
            result << if node.id?
                        "\\begin{table}%%#{node.id}"
                      else
                        '\\begin{table}%%'
                      end
          end

          # Process caption and label
          if caption.present?
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
          all_rows.each do |row|
            row_content = visit_with_context(row, table_context)
            result << "#{row_content} \\\\  \\hline"
          end

          result << '\\end{reviewtable}'

          # Only output \end{table} if caption is present (like LATEXBuilder)
          if caption.present?
            result << '\\end{table}'
          end

          result.join("\n") + "\n"
        end

        # Add collected footnotetext commands from caption context
        if caption_collector && caption_collector.any?
          table_content += generate_footnotetext_from_collector(caption_collector)
          caption_collector.clear
        end

        # Add collected footnotetext commands from table context
        if table_context && table_context.footnote_collector.any?
          table_content += generate_footnotetext_from_collector(table_context.footnote_collector)
          table_context.footnote_collector.clear
        end

        table_content.chomp + "\n\n"
      end

      def visit_imgtable(node, caption)
        # imgtable is rendered as table with image inside (like LATEXBuilder)
        result = []

        # Check if image is bound like LATEXBuilder does
        unless node.id? && @chapter && @chapter.image_bound?(node.id)
          # No ID or chapter, or image not bound - return dummy
          result << '\\begin{reviewdummyimage}'
          result << "% image not bound: #{node.id}" if node.id?
          result << '\\end{reviewdummyimage}'
          return result.join("\n") + "\n"
        end

        # Get image path - image is bound, so this should succeed
        image_path = @chapter.image(node.id).path

        # Generate table structure with image like LATEXBuilder
        # Start table environment if caption exists (line 911)
        if caption && !caption.empty?
          result << "\\begin{table}[h]%%#{node.id}"

          # Add caption and label at top if caption_top?
          if caption_top?('table')
            result << "\\reviewimgtablecaption{#{caption}}"
          end

          # Add table label (line 919) - this needs table index
          begin
            result << "\\label{table:#{@chapter.id}:#{node.id}}"
          rescue ReVIEW::KeyError
            # If table lookup fails, still continue
          end
        end

        # Add image inside reviewimage environment (lines 937-949)
        result << "\\begin{reviewimage}%%#{node.id}"

        # Parse metric option like LATEXBuilder
        metrics = parse_metric('latex', node.metric)
        command = 'reviewincludegraphics'

        # Use metric if provided, otherwise use default width
        result << if metrics.present?
                    "\\#{command}[#{metrics}]{#{image_path}}"
                  else
                    "\\#{command}[width=\\maxwidth]{#{image_path}}"
                  end

        result << '\\end{reviewimage}'

        # Close table if caption exists
        if caption.present?
          # Add caption at bottom if not caption_top?
          unless caption_top?('table')
            result << "\\reviewimgtablecaption{#{caption}}"
          end

          result << '\\end{table}'
        end

        result.join("\n") + "\n\n"
      end

      def visit_table_row(node)
        # Process all cells in the row using visitor pattern while maintaining table context
        # Note: table context should already be set by visit_table
        cells = node.children.map.with_index do |cell, col_index|
          visit_table_cell_with_index(cell, col_index)
        end
        cells.join(' & ')
      end

      def visit_table_cell(node)
        # Fallback method if called without index
        visit_table_cell_with_index(node, 0)
      end

      def visit_table_cell_with_index(node, col_index)
        # Process cell content while maintaining table context to collect footnotes
        # Note: table context should already be set by visit_table
        content = render_children(node)

        # Get cellwidth for this column from current table's cellwidth array
        cellwidth = @current_table_cellwidth && @current_table_cellwidth[col_index] ? @current_table_cellwidth[col_index] : 'l'

        # Check if content contains line breaks (from @<br>{})
        # Like LATEXBuilder: use \newline{} for fixed-width cells (p{...}), otherwise use \shortstack
        if /\\\\/.match?(content)
          # Check if cellwidth is fixed-width format (contains `{`)
          if AST::TableColumnWidthParser.fixed_width?(cellwidth)
            # Fixed-width cell: replace \\\n with \newline{}
            content = content.gsub("\\\\\n", '\\newline{}')
            if node.cell_type == :th
              "\\reviewth{#{content}}"
            else
              content
            end
          elsif node.cell_type == :th
            # Non-fixed-width cell: use \shortstack[l] like LATEXBuilder does
            "\\reviewth{\\shortstack[l]{#{content}}}"
          else
            "\\shortstack[l]{#{content}}"
          end
        elsif node.cell_type == :th
          # No line breaks - standard formatting
          "\\reviewth{#{content}}"
        else
          content
        end
      end

      def visit_image(node)
        # Process caption with proper context management
        caption = nil
        caption_collector = nil

        if node.caption_node
          @rendering_context.with_child_context(:caption) do |caption_context|
            caption = render_children_with_context(node.caption_node, caption_context)
            # Save the collector for later processing
            caption_collector = caption_context.footnote_collector
          end
        end

        image_type = node.image_type

        result = case image_type
                 when :indepimage, :numberlessimage
                   visit_indepimage(node, caption)
                 else
                   visit_regular_image(node, caption)
                 end

        # Add collected footnotetext commands from caption context
        if caption_collector && caption_collector.any?
          result += generate_footnotetext_from_collector(caption_collector)
          caption_collector.clear
        end

        result
      end

      def visit_regular_image(node, caption)
        image_path = find_image_path(node.id)

        if image_path
          render_existing_image(node, image_path, caption, with_label: true)
        else
          render_dummy_image(node, caption, double_escape_id: false, with_label: true)
        end
      end

      def visit_indepimage(node, caption)
        image_path = find_image_path(node.id)

        if image_path
          render_existing_indepimage(node, image_path, caption)
        else
          render_dummy_image(node, caption, double_escape_id: true, with_label: false)
        end
      end

      def visit_list(node)
        case node.list_type
        when :ul
          # Unordered list - generate LaTeX itemize environment
          items = node.children.map { |item| "\\item #{render_children(item)}" }.join("\n")
          "\n\\begin{itemize}\n#{items}\n\\end{itemize}\n\n"
        when :ol
          # Ordered list - generate LaTeX enumerate environment
          items = node.children.map { |item| "\\item #{render_children(item)}" }.join("\n")

          # Check if this list has start_number
          if node.start_number && node.start_number != 1
            # Generate enumerate with setcounter for non-default start
            start_num = node.start_number - 1 # LaTeX counter is 0-based
            "\n\\begin{enumerate}\n\\setcounter{enumi}{#{start_num}}\n#{items}\n\\end{enumerate}\n\n"
          else
            "\n\\begin{enumerate}\n#{items}\n\\end{enumerate}\n\n"
          end
        when :dl
          # Definition list - generate LaTeX description environment like LATEXBuilder
          visit_definition_list(node)
        else
          raise NotImplementedError, "Unsupported list type: #{node.list_type}"
        end
      end

      def visit_list_item(node)
        raise NotImplementedError, 'List item processing should be handled by visit_list, not as standalone items'
      end

      # Visit quote block
      def visit_block_quote(node)
        content = render_children(node)
        result = "\n\\begin{quote}\n#{content.chomp}\\end{quote}\n\n"
        apply_noindent_if_needed(node, result)
      end

      # Visit source block (code block without caption)
      def visit_block_source(node)
        content = render_children(node)
        "\\begin{reviewcmd}\n#{content}\\end{reviewcmd}\n"
      end

      # Visit lead block (lead paragraph)
      def visit_block_lead(node)
        content = render_children(node)
        result = "\n\\begin{quotation}\n#{content.chomp}\\end{quotation}\n\n"
        apply_noindent_if_needed(node, result)
      end

      # Visit olnum block (set ordered list counter)
      def visit_block_olnum(node)
        # olnum is now handled as metadata in list processing
        # If we encounter it here, it means there was no following ordered list
        # In this case, we should still generate the setcounter command for compatibility
        if node.args.first
          num = node.args.first.to_i
          "\\setcounter{enumi}{#{num - 1}}\n"
        else
          "\\setcounter{enumi}{0}\n"
        end
      end

      # Visit footnote block
      def visit_block_footnote(node)
        # Handle footnote blocks - generate \footnotetext LaTeX command
        if node.args.length >= 2
          footnote_id = node.args[0]
          footnote_content = escape(node.args[1])
          # Generate footnote number like LaTeXBuilder does
          if @chapter && @chapter.footnote_index
            begin
              footnote_number = @chapter.footnote_index.number(footnote_id)
              "\\footnotetext[#{footnote_number}]{#{footnote_content}}\n"
            rescue ReVIEW::KeyError => e
              raise NotImplementedError, "Footnote block processing failed for #{footnote_id}: #{e.message}"
            end
          else
            raise NotImplementedError, 'Footnote processing requires chapter context but none provided'
          end
        else
          raise NotImplementedError, 'Malformed footnote block: insufficient arguments'
        end
      end

      # Visit tsize block (table size control)
      def visit_block_tsize(_node)
        # tsize is now processed by TsizeProcessor during AST compilation
        # The tsize block nodes are removed from AST by TsizeProcessor,
        # so this case should not be reached. Return empty string for safety.
        ''
      end

      # Visit texequation block (mathematical equation)
      def visit_block_texequation(node)
        content = render_children(node)
        # Handle mathematical equation blocks - output content directly
        # without LaTeX environment wrapping since content is raw LaTeX math
        content.strip.empty? ? '' : "\n#{content}\n\n"
      end

      # Visit comment block
      def visit_block_comment(node)
        # Handle comment blocks - only output in draft mode
        visit_comment_block(node)
      end

      # Visit beginchild block (child nesting control)
      def visit_block_beginchild(_node)
        # Child nesting control commands - produce no output
        ''
      end

      # Visit endchild block (child nesting control)
      def visit_block_endchild(_node)
        # Child nesting control commands - produce no output
        ''
      end

      # Visit centering block (center alignment)
      def visit_block_centering(node)
        content = render_children(node)
        "\n\\begin{center}\n#{content.chomp}\\end{center}\n\n"
      end

      # Visit flushright block (right alignment)
      def visit_block_flushright(node)
        content = render_children(node)
        "\n\\begin{flushright}\n#{content.chomp}\\end{flushright}\n\n"
      end

      # Visit address block (similar to flushright)
      def visit_block_address(node)
        content = render_children(node)
        "\n\\begin{flushright}\n#{content.chomp}\\end{flushright}\n\n"
      end

      # Visit talk block (dialog/conversation)
      def visit_block_talk(node)
        content = render_children(node)
        "#{content}\n"
      end

      # Visit read block (reading material)
      def visit_block_read(node)
        content = render_children(node)
        "\n\\begin{quotation}\n#{content.chomp}\\end{quotation}\n\n"
      end

      # Visit blockquote block
      def visit_block_blockquote(node)
        content = render_children(node)
        "\n\\begin{quote}\n#{content.chomp}\\end{quote}\n\n"
      end

      # Visit printendnotes block (print collected endnotes)
      def visit_block_printendnotes(_node)
        "\n\\theendnotes\n\n"
      end

      # Visit label block (create label)
      def visit_block_label(node)
        if node.args.first
          label_id = node.args.first
          "\\label{#{escape(label_id)}}\n"
        else
          ''
        end
      end

      # Visit blankline block (control command)
      def visit_block_blankline(_node)
        ''
      end

      # Visit noindent block (control command)
      def visit_block_noindent(_node)
        ''
      end

      # Visit pagebreak block (control command)
      def visit_block_pagebreak(_node)
        ''
      end

      # Visit endnote block (control command)
      def visit_block_endnote(_node)
        ''
      end

      # Visit hr block (control command)
      def visit_block_hr(_node)
        ''
      end

      # Visit bpo block (control command)
      def visit_block_bpo(_node)
        ''
      end

      # Visit parasep block (control command)
      def visit_block_parasep(_node)
        ''
      end

      # Visit bibpaper block (bibliography paper)
      def visit_block_bibpaper(node)
        visit_bibpaper(node)
      end

      def visit_minicolumn(node)
        # Process caption with proper context management and collect footnotes
        caption = nil
        caption_collector = nil

        if node.caption_node
          @rendering_context.with_child_context(:caption) do |caption_context|
            caption = render_children_with_context(node.caption_node, caption_context)
            # Save the collector for later processing
            caption_collector = caption_context.footnote_collector
          end
        end

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
        result << '' # blank line after begin
        result << content.chomp
        result << "\\end{#{env_name}}"

        output = result.join("\n") + "\n\n"

        # Add collected footnotetext commands from caption context
        if caption_collector && caption_collector.any?
          output += generate_footnotetext_from_collector(caption_collector)
          caption_collector.clear
        end

        output
      end

      def visit_caption(node)
        render_children(node)
      end

      def visit_comment_block(node)
        # block comment - only display in draft mode
        return '' unless config['draft']

        content_lines = []

        # add argument if it exists
        if node.args.first&.then { |arg| !arg.empty? }
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
        caption = render_children(node.caption_node) if node.caption_node

        # Generate column label for hypertarget (using auto_id from Compiler)
        column_label = generate_column_label(node, caption)
        hypertarget = "\\hypertarget{#{column_label}}{}"

        # Process column content with :column context to collect footnotes
        column_context = nil
        content = @rendering_context.with_child_context(:column) do |ctx|
          column_context = ctx
          render_children_with_context(node, column_context)
        end

        result = []
        result << '' # blank line before column

        # support Re:VIEW Version 3+ format only
        caption_part = caption ? "[#{caption}#{hypertarget}]" : "[#{hypertarget}]"
        result << "\\begin{reviewcolumn}#{caption_part}"

        # Add TOC entry if within toclevel
        if node.level && caption && node.level <= config['toclevel'].to_i
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
        result << '\\end{reviewcolumn}'
        result << ''  # blank line after column

        output = result.join("\n") + "\n"

        # Add collected footnotetext commands from column context
        if column_context && column_context.footnote_collector.any?
          output += generate_footnotetext_from_collector(column_context.footnote_collector)
          column_context.footnote_collector.clear
        end

        output
      end

      def visit_embed(node)
        # All embed types now use unified processing
        process_raw_embed(node)
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
              captionstr = "\\reviewlistcaption{#{text_formatter.format_caption('list', chapter_num, list_num, caption)}}"
              result << captionstr
            rescue ReVIEW::KeyError
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
        result.join("\n") + "\n\n"
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
        result.join("\n") + "\n\n"
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
        result.join("\n") + "\n\n"
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
        result.join("\n") + "\n\n"
      end

      def visit_tex_equation(node)
        # Handle LaTeX mathematical equation blocks
        # Output the LaTeX content directly without escaping since it's raw LaTeX
        content = node.content

        if node.id? && node.caption?
          # Equation with ID and caption - use reviewequationblock like traditional compiler
          equation_num = get_equation_number(node.id)
          caption_content = render_children(node.caption_node)
          result = []
          result << '\\begin{reviewequationblock}'
          result << "\\reviewequationcaption{#{escape("式#{equation_num}: #{caption_content}")}}"
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
        result.join("\n") + "\n\n"
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
          rescue ReVIEW::KeyError
            # Fallback if equation not found in index
            '??'
          end
        else
          '??'
        end
      end

      def visit_bibpaper(node)
        # Extract bibliography arguments
        if node.args.length >= 2
          bib_id = node.args[0]
          bib_caption = node.args[1]

          # Process content
          content = render_children(node)

          # Generate bibliography entry like LATEXBuilder
          result = []

          # Header with number and caption
          if @book.bibpaper_index
            begin
              bib_number = @book.bibpaper_index.number(bib_id)
              result << "[#{bib_number}] #{escape(bib_caption)}"
            rescue ReVIEW::KeyError => e
              # Fallback if not found in index
              warn "Bibpaper #{bib_id} not found in index: #{e.message}" if $DEBUG
              result << "[??] #{escape(bib_caption)}"
            end
          elsif @ast_indexer && @ast_indexer.bibpaper_index
            # Try to get from AST indexer if chapter index not available
            begin
              bib_number = @ast_indexer.bibpaper_index.number(bib_id)
              result << "[#{bib_number}] #{escape(bib_caption)}"
            rescue ReVIEW::KeyError
              result << "[??] #{escape(bib_caption)}"
            end
          else
            result << "[??] #{escape(bib_caption)}"
          end

          # Add label for cross-references
          result << "\\label{bib:#{escape(bib_id)}}"
          result << ''

          # Add content - process paragraphs
          result << if config['join_lines_by_lang']
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
      def add_line_numbers(content, node = nil)
        lines = content.split("\n")
        numbered_lines = []

        # Use node.first_line_num if set, otherwise start from 1
        start_num = node&.first_line_num || 1

        lines.each_with_index do |line, i|
          next if line.strip.empty? && i == lines.length - 1 # Skip last empty line

          numbered_lines << sprintf('%2d: %s', start_num + i, line)
        end

        numbered_lines.join("\n")
      end

      # Render footnote content for footnotetext
      # This method processes the footnote node's children to properly handle
      # inline markup like @<b>{text} within footnotes
      def render_footnote_content(footnote_node)
        render_children(footnote_node)
      end

      # Render inline elements from caption_node
      # @param caption_node [CaptionNode] Caption node to render
      # @return [String] Rendered inline elements
      def render_caption_inline(caption_node)
        caption_node ? render_children(caption_node) : ''
      end

      private

      # Get image path, returning nil if image doesn't exist
      def find_image_path(id)
        path = @chapter.image(id).path
        path && !path.empty? ? path : nil
      rescue StandardError
        nil
      end

      # Render existing image (for regular //image)
      def render_existing_image(node, image_path, caption, with_label:)
        result = []
        result << if node.id?
                    "\\begin{reviewimage}%%#{node.id}"
                  else
                    '\\begin{reviewimage}'
                  end

        metrics = parse_metric('latex', node.metric)
        command = 'reviewincludegraphics'

        result << if metrics && !metrics.empty?
                    "\\#{command}[#{metrics}]{#{image_path}}"
                  else
                    "\\#{command}[width=\\maxwidth]{#{image_path}}"
                  end

        result << "\\reviewimagecaption{#{caption}}" if caption && !caption.empty?

        if with_label && node.id?
          result << if @chapter
                      "\\label{image:#{@chapter.id}:#{node.id}}"
                    else
                      "\\label{image:test:#{node.id}}"
                    end
        end

        result << '\\end{reviewimage}'
        result.join("\n") + "\n"
      end

      # Render existing indepimage (for //indepimage)
      def render_existing_indepimage(node, image_path, caption)
        result = []
        result << "\\begin{reviewimage}%%#{node.id}"

        if caption_top?('image') && caption && !caption.empty?
          caption_str = "\\reviewindepimagecaption{#{text_formatter.format_numberless_image}#{text_formatter.format_caption_prefix}#{caption}}"
          result << caption_str
        end

        metrics = parse_metric('latex', node.metric)
        command = 'reviewincludegraphics'

        result << if metrics && !metrics.empty?
                    "\\#{command}[#{metrics}]{#{image_path}}"
                  else
                    "\\#{command}[width=\\maxwidth]{#{image_path}}"
                  end

        if !caption_top?('image') && caption && !caption.empty?
          caption_str = "\\reviewindepimagecaption{#{text_formatter.format_numberless_image}#{text_formatter.format_caption_prefix}#{caption}}"
          result << caption_str
        end

        result << '\\end{reviewimage}'
        result.join("\n") + "\n"
      end

      # Render dummy image for missing images
      def render_dummy_image(node, caption, double_escape_id:, with_label:)
        result = []
        result << '\\begin{reviewdummyimage}'

        if node.id?
          # For regular images: single escape, for indepimage: double escape (like Builder)
          result << if double_escape_id
                      escape_latex("--[[path = #{escape_latex(node.id)} (not exist)]]--")
                    else
                      escape_latex("--[[path = #{node.id} (not exist)]]--")
                    end
        end

        if with_label && node.id?
          result << if @chapter
                      "\\label{image:#{@chapter.id}:#{node.id}}"
                    else
                      "\\label{image:test:#{node.id}}"
                    end
        end

        if caption && !caption.empty?
          result << if double_escape_id
                      # indepimage uses reviewindepimagecaption
                      "\\reviewindepimagecaption{#{text_formatter.format_numberless_image}#{text_formatter.format_caption_prefix}#{caption}}"
                    else
                      # regular image uses reviewimagecaption
                      "\\reviewimagecaption{#{caption}}"
                    end
        end

        result << '\\end{reviewdummyimage}'
        result.join("\n") + "\n"
      end

      def ast_compiler
        @ast_compiler ||= ReVIEW::AST::Compiler.for_chapter(@chapter)
      end

      # Render definition list with proper footnote handling
      # Footnotes in definition terms require special handling in LaTeX:
      # they must use \protect\footnotemark{} in the term and \footnotetext
      # after the description environment
      def visit_definition_list(node)
        dl_context = nil
        items_content = @rendering_context.with_child_context(:dl) do |ctx|
          dl_context = ctx
          # Temporarily set the renderer's context to the dl context
          old_context = @rendering_context
          @rendering_context = dl_context

          items = node.children.map do |item|
            render_definition_item(item, dl_context)
          end.join("\n")

          # Restore the previous context
          @rendering_context = old_context
          items
        end

        # Build output
        result = "\n\\begin{description}\n#{items_content}\n\\end{description}\n\n"

        # Add collected footnotetext commands from dt contexts (transferred to dl_context)
        if dl_context && dl_context.footnote_collector.any?
          result += generate_footnotetext_from_collector(dl_context.footnote_collector)
          dl_context.footnote_collector.clear
        end

        result
      end

      # Render a single definition list item
      def render_definition_item(item, dl_context)
        # Render term with :dt context like LATEXBuilder does (latexbuilder.rb:361-382)
        term = render_definition_term(item, dl_context)

        # Escape square brackets in terms like LATEXBuilder does
        term = term.gsub('[', '\\lbrack{}').gsub(']', '\\rbrack{}')

        # Handle definition content (all children are definition content)
        if item.children && !item.children.empty?
          definition_parts = item.children.map do |child|
            result = visit(child) # Use visit instead of render_children for individual nodes
            # Strip all trailing whitespace and newlines
            # LATEXBuilder's dd() joins lines with "\n", so we need single newlines between paragraphs
            result.rstrip
          end
          # Join with single newline to match LATEXBuilder dd() behavior (lines.map(&:chomp).join("\n"))
          definition = definition_parts.join("\n")

          # Use exact LATEXBuilder format: \item[term] \mbox{} \\
          "\\item[#{term}] \\mbox{} \\\\\n#{definition}"
        else
          # No definition content - term only
          "\\item[#{term}] \\mbox{} \\\\"
        end
      end

      # Render definition term with proper footnote collection
      def render_definition_term(item, dl_context)
        term = nil
        dt_footnote_collector = nil

        @rendering_context.with_child_context(:dt) do |dt_context|
          # Temporarily set renderer's context to dt context for term rendering
          old_dt_context = @rendering_context
          @rendering_context = dt_context

          term = if item.term_children&.any?
                   # Render term children (which contain inline elements)
                   item.term_children.map { |child| visit(child) }.join
                 else
                   ''
                 end

          @rendering_context = old_dt_context

          # Save dt_context's footnote collector to transfer footnotes to dl_context
          dt_footnote_collector = dt_context.footnote_collector
        end

        # Transfer footnotes from dt_context to dl_context
        if dt_footnote_collector && dt_footnote_collector.any?
          dt_footnote_collector.each do |entry|
            dl_context.collect_footnote(entry.node, entry.number)
          end
          dt_footnote_collector.clear
        end

        term
      end

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

        if level > config['secnolevel'] || (@chapter.number.to_s.empty? && level > 1)
          "#{name}*"
        else
          name
        end
      end

      def render_inline_element(type, content, node)
        # Delegate to inline element handler
        method_name = "render_inline_#{type}"
        if @inline_element_handler.respond_to?(method_name, true)
          @inline_element_handler.send(method_name, type, content, node)
        else
          raise NotImplementedError, "Unknown inline element: #{type}"
        end
      end

      def visit_reference(node)
        if node.resolved?
          format_resolved_reference(node.resolved_data)
        else
          # Reference resolution was skipped or disabled
          # Return content as fallback
          escape(node.content || '')
        end
      end

      # Format resolved reference based on ResolvedData
      # Uses TextFormatter for centralized text formatting
      def format_resolved_reference(data)
        text_formatter.format_reference(data.reference_type, data)
      end

      # Render document children with proper separation
      def render_document_children(node)
        results = []
        node.children.each_with_index do |child, _index|
          result = visit(child)
          next if result.nil? || result.empty?

          # Add proper separation after raw embeds
          if child.is_a?(ReVIEW::AST::EmbedNode) && child.embed_type == :raw && !result.end_with?("\n")
            result += "\n"
          end

          results << result
        end

        content = results.join

        # Post-process to fix consecutive minicolumn blocks spacing like LATEXBuilder's solve_nest
        # When minicolumn blocks are consecutive, remove extra blank line between them
        # Pattern: \end{reviewnote}\n\n\begin{reviewnote} should become \end{reviewnote}\n\begin{reviewnote}
        content.gsub!(/\\end\{(reviewnote|reviewmemo|reviewtip|reviewinfo|reviewwarning|reviewimportant|reviewcaution|reviewnotice)\}\n\n\\begin\{(reviewnote|reviewmemo|reviewtip|reviewinfo|reviewwarning|reviewimportant|reviewcaution|reviewnotice)\}/,
                      "\\\\end{\\1}\n\\\\begin{\\2}")

        content
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

      def visit_footnote(_node)
        # FootnoteNode represents a footnote definition (//footnote[id][content])
        # In AST rendering, footnote definitions do not produce direct output.
        # Instead, footnotes are rendered via:
        # 1. @<fn>{id} inline references produce \footnotemark or \footnote
        # 2. Collected footnotes (from captions/tables) are output as \footnotetext
        #    by the parent node (code_block, table, image) after processing
        ''
      end

      # Check caption position configuration
      def caption_top?(type)
        unless %w[top bottom].include?(config.dig('caption_position', type))
          # Default to top if not configured
          return true
        end

        config['caption_position'][type] != 'bottom'
      end

      # This method calls super to use the base implementation, then applies LaTeX-specific logic
      def parse_metric(type, metric)
        s = super
        # If use_original_image_size is enabled and result is empty and no metric provided
        if config&.dig('pdfmaker', 'use_original_image_size') && s.empty? && !metric&.present?
          return ' ' # pass empty space to \reviewincludegraphics to use original size
        end

        s
      end

      # Handle individual metric transformations (like scale to width conversion)
      def handle_metric(str)
        # Check if image_scale2width is enabled and metric is scale
        if config&.dig('pdfmaker', 'image_scale2width') && str =~ /\Ascale=([\d.]+)\Z/
          return "width=#{$1}\\maxwidth"
        end

        str
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
      def generate_nonum_headline(level, caption, _node)
        section_command = get_base_section_name(level) + '*'

        # Add TOC entry
        toc_type = case level
                   when 1
                     'chapter'
                   when 2
                     'section'
                   else
                     'subsection'
                   end

        "\\#{section_command}{#{caption}}\n\\addcontentsline{toc}{#{toc_type}}{#{caption}}\n\n"
      end

      # Generate unnumbered headline without TOC entry (for notoc headlines)
      def generate_notoc_headline(level, caption, _node)
        section_command = get_base_section_name(level) + '*'

        "\\#{section_command}{#{caption}}\n\n"
      end

      # Get base section name without star
      def get_base_section_name(level)
        if @chapter.is_a?(ReVIEW::Book::Part) && level == 1
          'part'
        else
          HEADLINE[level] || raise(CompileError, "Unsupported headline level: #{level}")
        end
      end

      # Generate column label for hypertarget (matches LATEXBuilder behavior)
      def generate_column_label(node, _caption)
        # Use column_number directly instead of parsing auto_id
        num = node.column_number || 'unknown'

        "column:#{@chapter&.id || 'unknown'}:#{num}"
      end

      # Process //raw command with LATEXBuilder-compatible behavior
      def process_raw_embed(node)
        # Check if this embed is targeted for LaTeX builder
        unless node.targeted_for?('latex')
          return ''
        end

        # Get content
        content = node.content || ''

        # Process \n based on embed type
        case node.embed_type
        when :inline, :raw
          # For inline and raw embeds, convert \\n to actual newlines
          content = content.gsub('\\n', "\n")
        end

        # For block embeds, add trailing newline
        node.embed_type == :block ? content + "\n" : content
      end
    end
  end
end
