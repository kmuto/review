# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/renderer/base'
require 'review/latexutils'
require 'review/sec_counter'

module ReVIEW
  module Renderer
    class LATEXRenderer < Base
      include ReVIEW::LaTeXUtils

      attr_reader :chapter, :book

      def initialize(config: {}, options: {})
        @config = config
        super
        @chapter = options[:chapter]
        @book = options[:book] || @chapter&.book

        # Generate indexes like LATEXBuilder does
        if @chapter
          @chapter.generate_indexes
        end
        if @book
          @book.generate_indexes
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
      end

      def visit_document(node)
        # Generate content directly without complex post-processing
        content = render_children(node)

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

        # Update section counter like LATEXBuilder
        if @sec_counter
          @sec_counter.inc(level)
        end

        # LaTeX section commands - match LATEXBuilder behavior
        section_command = case level
                          when 1
                            'chapter'
                          when 2
                            'section'
                          when 3
                            'subsection*' # LATEXBuilder uses subsection* for level 3
                          when 4
                            'subsubsection*' # LATEXBuilder uses subsubsection* for level 4
                          when 5
                            'paragraph*' # LATEXBuilder uses paragraph* for level 5
                          when 6
                            'subparagraph'
                          else
                            raise NotImplementedError, "Unsupported headline level: #{level}. LaTeX only supports levels 1-6"
                          end

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
        if level == 3
          result << "\\addcontentsline{toc}{subsection}{#{caption}}"
        end

        unless label_part.empty?
          result << label_part
        end

        result.join("\n") + "\n"
      end

      def visit_paragraph(node)
        content = render_children(node)

        # Add single newline for paragraph end
        "#{content}\n"
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
                   # Default to emlist for unknown or nil code types
                   visit_emlist_block(node, content, caption)
                 end

        # Add footnotetext commands for footnotes used in caption
        @foottext.each do |footnote_id, footnote_number|
          next unless @chapter && @chapter.footnote_index

          begin
            footnote_content = @chapter.footnote_index.fetch(footnote_id).content
            result += "\\footnotetext[#{footnote_number}]{#{escape(footnote_content)}}\n"
          rescue StandardError => e
            raise NotImplementedError, "Footnote not found in index: #{footnote_id} (#{e.message})"
          end
        end
        @foottext.clear

        result
      end

      def visit_code_line(node)
        # Use original_text to preserve exact formatting including empty lines
        content = node.original_text
        # Apply LaTeX escaping to match Builder behavior while preserving structure
        escaped_content = escape(content)
        # Add proper newline for LaTeX code line formatting
        "#{escaped_content}\n"
      end

      def visit_table(node)
        caption = render_children(node.caption) if node.caption
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
        result << if node.id && !node.id.empty?
                    "\\begin{table}%%#{node.id}"
                  else
                    '\\begin{table}%%'
                  end

        if caption && !caption.empty?
          # emtable uses reviewtablecaption* (with asterisk)
          caption_command = table_type == :emtable ? 'reviewtablecaption*' : 'reviewtablecaption'
          result << "\\#{caption_command}{#{caption}}"
        end

        if node.id && !node.id.empty?
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
          # Skip separator row (contains only ----)
          if row.children.length == 1 && row.children.first.respond_to?(:children) &&
             row.children.first.children.any? { |child| child.respond_to?(:content) && child.content.strip == '----' }
            next
          end

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
            footnote_content = @chapter.footnote_index.fetch(footnote_id).content
            table_result += "\\footnotetext[#{footnote_number}]{#{escape(footnote_content)}}\n"
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
        raise NotImplementedError, "Image rendering not fully implemented for image ID: #{node.id}"

        if node.id && !node.id.empty?
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
        result << '\\begin{reviewimage}'

        if caption && !caption.empty?
          result << "\\reviewimagecaption{#{caption}}"
        end

        if node.id && !node.id.empty?
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
            footnote_content = @chapter.footnote_index.fetch(footnote_id).content
            image_result += "\\footnotetext[#{footnote_number}]{#{escape(footnote_content)}}\n"
          rescue StandardError => e
            raise NotImplementedError, "Footnote not found in index: #{footnote_id} (#{e.message})"
          end
        end
        @foottext.clear

        image_result
      end

      def visit_indepimage(node, caption)
        result = []
        # indepimage/numberlessimage uses different structure (no label, different caption)
        result << '\\begin{reviewdummyimage}'
        raise NotImplementedError, "Image rendering not fully implemented for image ID: #{node.id}"

        # No label for indepimage/numberlessimage

        if caption && !caption.empty?
          # indepimage uses reviewindepimagecaption which adds "図: " prefix like LATEXBuilder
          result << "\\reviewindepimagecaption{図: #{caption}}"
        end

        result << '\\end{reviewdummyimage}'

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
          if node.respond_to?(:olnum_start) && node.olnum_start
            # Generate enumerate with setcounter for olnum
            start_num = node.olnum_start - 1 # LaTeX counter is 0-based
            "\n\\begin{enumerate}\n\\setcounter{enumi}{#{start_num}}\n#{items}\n\\end{enumerate}\n"
          else
            "\n\\begin{enumerate}\n#{items}\n\\end{enumerate}\n"
          end
        when :dl
          # Definition list - generate LaTeX description environment like LATEXBuilder
          items = node.children.map do |item|
            if item.children && item.children.length >= 2
              # Handle definition term (first child)
              term_node = item.children[0]
              # Debug: Check if term_node is InlineNode
              term = if term_node.class.name.include?('InlineNode')
                       visit_inline(term_node)
                     else
                       render_children(term_node)
                     end

              # Handle definition content (rest of children)
              definition_parts = item.children[1..-1].map do |child|
                if child.class.name.include?('TextNode')
                  child.content.to_s
                else
                  render_children(child)
                end
              end
              definition = definition_parts.join(' ').strip
              # Use exact LATEXBuilder format: \item[term] \mbox{} \\
              "\\item[#{term}] \\mbox{} \\\\\n#{definition}"
            else
              "\\item[#{render_children(item)}] "
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

      def visit_block(node)
        content = render_children(node)
        block_type = node.block_type.to_s

        case block_type
        when 'quote'
          "\n\\begin{quote}\n#{content}\\end{quote}\n"
        when 'source'
          # Source code block without caption
          "\\begin{reviewcmd}\n#{content}\\end{reviewcmd}\n"
        when 'lead'
          # Lead paragraph - use standard quotation environment like LATEXBuilder
          "\\begin{quotation}\n#{content}\\end{quotation}\n"
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
        when 'beginchild', 'endchild'
          # Child nesting control commands - produce no output
          ''
        when 'blankline', 'noindent', 'pagebreak', 'tsize', 'endnote', 'label', 'printendnotes', 'hr', 'bpo', 'parasep'
          # Control commands that should not generate LaTeX environment blocks
          ''
        else
          raise NotImplementedError, "Unsupported block type: #{block_type}"
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

        # Column is rendered as a minicolumn-like environment
        result = []
        result << '\\begin{reviewcolumn}'
        result << ''  # blank line
        result << content.chomp
        result << ''  # blank line
        result << '\\end{reviewcolumn}'

        result.join("\n") + "\n"
      end

      def visit_embed(node)
        # Embed blocks are typically raw content that should be passed through
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
          if node.id && !node.id.empty?
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

      def render_inline_element(type, content, node)
        case type
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
        when 'code'
          "\\reviewcode{#{content}}"
        when 'u', 'underline'
          "\\reviewunderline{#{content}}"
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
            footnote_id = node.args.first.to_s
            # Handle footnotes in table context like LATEXBuilder
            if @doc_status[:table] || @doc_status[:caption] || @doc_status[:column]
              if @chapter && @chapter.footnote_index
                begin
                  footnote_number = @chapter.footnote_index.number(footnote_id)
                  @foottext[footnote_id] = footnote_number
                  '\\protect\\footnotemark'
                rescue StandardError => e
                  raise NotImplementedError, "Footnote inline processing failed for #{footnote_id}: #{e.message}"
                end
              else
                '\\protect\\footnotemark'
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
          if node.args && node.args.first
            # Use Re:VIEW list reference like LATEXBuilder
            list_id = node.args.first
            if @chapter && @chapter.list_index
              begin
                list_item = @chapter.list_index.number(list_id)
                if @chapter.number
                  "\\reviewlistref{#{@chapter.number}.#{list_item}}"
                else
                  "\\reviewlistref{#{list_item}}"
                end
              rescue StandardError => e
                raise NotImplementedError, "List reference failed for #{list_id}: #{e.message}"
              end
            else
              "\\ref{#{escape(list_id)}}"
            end
          else
            content
          end
        when 'table', 'tableref'
          if node.args && node.args.first
            # Use Re:VIEW table reference like LATEXBuilder
            table_id = node.args.first
            if @chapter && @chapter.table_index
              begin
                table_item = @chapter.table_index.number(table_id)
                table_label = "table:#{@chapter.id}:#{table_id}"
                if @chapter.number
                  "\\reviewtableref{#{@chapter.number}.#{table_item}}{#{table_label}}"
                else
                  "\\reviewtableref{#{table_item}}{#{table_label}}"
                end
              rescue StandardError => e
                raise NotImplementedError, "Table reference failed for #{table_id}: #{e.message}"
              end
            else
              "\\ref{#{escape(table_id)}}"
            end
          else
            content
          end
        when 'img', 'imgref'
          if node.args && node.args.first
            # Use Re:VIEW image reference like LATEXBuilder
            image_id = node.args.first.to_s
            if @chapter && @chapter.image_index
              begin
                image_item = @chapter.image_index.number(image_id)
                "\\reviewimageref{#{@chapter.number}.#{image_item}}{image:#{@chapter.id}:#{image_id}}"
              rescue StandardError => e
                raise NotImplementedError, "Image reference failed for #{image_id}: #{e.message}"
              end
            else
              # Don't escape underscores in ref labels
              "\\ref{#{image_id}}"
            end
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
        else
          raise NotImplementedError, "Unsupported inline element type: #{inline_type}"
        end
      end

      def render_children(node)
        return '' unless node.children

        node.children.map { |child| visit(child) }.join
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
    end
  end
end
