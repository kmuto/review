# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/renderer/latex_renderer'
require 'review/latexutils'
require 'review/textutils'

module ReVIEW
  module Renderer
    class LatexRenderer < Base
      # Inline element renderer for LaTeX output
      class InlineElementRenderer
        include ReVIEW::LaTeXUtils
        include ReVIEW::TextUtils

        def initialize(renderer, book:, chapter:, rendering_context:)
          @renderer = renderer
          @book = book
          @chapter = chapter
          @rendering_context = rendering_context

          # Initialize LaTeX character escaping
          # Use texcommand config like LATEXBuilder does to properly configure character escaping
          texcommand = @book.config['texcommand']
          initialize_metachars(texcommand)
        end

        def render(type, content, node)
          method_name = "render_inline_#{type}"
          if respond_to?(method_name, true)
            send(method_name, type, content, node)
          else
            raise NotImplementedError, "Unknwon inline element: #{type}"
          end
        end

        private

        def render_inline_b(_type, content, _node)
          "\\reviewbold{#{content}}"
        end

        def render_inline_i(_type, content, _node)
          "\\reviewit{#{content}}"
        end

        def render_inline_em(_type, content, _node)
          "\\reviewem{#{content}}"
        end

        def render_inline_tt(_type, content, _node)
          "\\reviewtt{#{content}}"
        end

        def render_inline_ttb(_type, content, _node)
          "\\reviewttb{#{content}}"
        end

        def render_inline_tti(_type, content, _node)
          "\\reviewtti{#{content}}"
        end

        def render_inline_code(_type, content, _node)
          "\\reviewcode{#{content}}"
        end

        def render_inline_u(_type, content, _node)
          "\\reviewunderline{#{content}}"
        end

        def render_inline_strong(_type, content, _node)
          "\\reviewstrong{#{content}}"
        end

        def render_inline_underline(type, content, node)
          render_inline_u(type, content, node)
        end

        def render_inline_href(_type, content, node)
          if node.args.length >= 2
            url = node.args[0]
            text = node.args[1]
            # Handle internal references (URLs starting with #)
            if url.start_with?('#')
              anchor = url.sub(/\A#/, '')
              "\\hyperref[#{escape_latex(anchor)}]{#{escape_latex(text)}}"
            elsif /\A[a-z]+:/.match?(url)
              # External URL with scheme
              "\\href{#{escape_url(url)}}{#{escape_latex(text)}}"
            else
              # Plain reference without scheme
              "\\ref{#{escape_latex(url)}}"
            end
          else
            # For single argument href, get raw text from first text child to avoid double escaping
            raw_url = if node.children.first.respond_to?(:content)
                        node.children.first.content
                      else
                        raise NotImplementedError, "URL is invalid: #{content}"
                      end
            # Handle internal references (URLs starting with #)
            if raw_url.start_with?('#')
              anchor = raw_url.sub(/\A#/, '')
              "\\hyperref[#{escape_latex(anchor)}]{#{escape_latex(raw_url)}}"
            elsif /\A[a-z]+:/.match?(raw_url)
              # External URL with scheme
              url_content = escape_url(raw_url)
              "\\url{#{url_content}}"
            else
              # Plain reference without scheme
              "\\ref{#{escape_latex(raw_url)}}"
            end
          end
        end

        def render_inline_fn(_type, content, node)
          if node.args.first
            footnote_id = node.args.first.to_s

            # Get footnote info from chapter index
            unless @chapter && @chapter.footnote_index
              return "\\footnote{#{footnote_id}}"
            end

            begin
              footnote_number = @chapter.footnote_index.number(footnote_id)
              index_item = @chapter.footnote_index[footnote_id]
            rescue ReVIEW::KeyError
              return "\\footnote{#{footnote_id}}"
            end

            # Check if we need to use footnotetext mode (like LATEXBuilder line 1143)
            if @book.config['footnotetext']
              # footnotetext config is enabled - always use footnotemark (like LATEXBuilder line 1144)
              "\\footnotemark[#{footnote_number}]"
            elsif @rendering_context.requires_footnotetext?
              # We're in a context that requires footnotetext (caption/table/column/dt)
              # Collect the footnote for later output (like LATEXBuilder line 1146)
              if index_item.footnote_node?
                @rendering_context.collect_footnote(index_item.footnote_node, footnote_number)
              end
              # Use protected footnotemark (like LATEXBuilder line 1147)
              '\\protect\\footnotemark{}'
            else
              # Normal context - use direct footnote (like LATEXBuilder line 1149)
              footnote_content = if index_item.footnote_node?
                                   @renderer.render_footnote_content(index_item.footnote_node)
                                 else
                                   escape(index_item.content || '')
                                 end
              "\\footnote{#{footnote_content}}"
            end
          else
            "\\footnote{#{content}}"
          end
        end

        # Render list reference
        def render_inline_list(_type, content, node)
          return content unless node.args.present?

          if node.args.length == 2
            render_cross_chapter_list_reference(node)
          elsif node.args.length == 1
            render_same_chapter_list_reference(node)
          else
            content
          end
        end

        # Render listref reference (same as list)
        def render_inline_listref(type, content, node)
          render_inline_list(type, content, node)
        end

        # Render table reference
        def render_inline_table(_type, content, node)
          return content unless node.args.present?

          if node.args.length == 2
            render_cross_chapter_table_reference(node)
          elsif node.args.length == 1
            render_same_chapter_table_reference(node)
          else
            content
          end
        end

        # Render tableref reference (same as table)
        def render_inline_tableref(type, content, node)
          render_inline_table(type, content, node)
        end

        # Render image reference
        def render_inline_img(_type, content, node)
          return content unless node.args.present?

          if node.args.length == 2
            render_cross_chapter_image_reference(node)
          elsif node.args.length == 1
            render_same_chapter_image_reference(node)
          else
            content
          end
        end

        # Render imgref reference (same as img)
        def render_inline_imgref(type, content, node)
          render_inline_img(type, content, node)
        end

        # Render equation reference
        def render_inline_eq(_type, content, node)
          return content unless node.args.first

          equation_id = node.args.first
          if @chapter && @chapter.equation_index
            begin
              equation_item = @chapter.equation_index.number(equation_id)
              if @chapter.number
                chapter_num = @chapter.format_number(false)
                "\\reviewequationref{#{chapter_num}.#{equation_item}}"
              else
                "\\reviewequationref{#{equation_item}}"
              end
            rescue ReVIEW::KeyError => e
              raise NotImplementedError, "Equation reference failed for #{equation_id}: #{e.message}"
            end
          else
            raise NotImplementedError, 'Equation reference requires chapter context but none provided'
          end
        end

        # Render eqref reference (same as eq)
        def render_inline_eqref(type, content, node)
          render_inline_eq(type, content, node)
        end

        # Render same-chapter list reference
        def render_same_chapter_list_reference(node)
          list_ref = node.args.first.to_s
          if @chapter && @chapter.list_index
            begin
              list_item = @chapter.list_index.number(list_ref)
              if @chapter.number
                chapter_num = @chapter.format_number(false)
                "\\reviewlistref{#{chapter_num}.#{list_item}}"
              else
                "\\reviewlistref{#{list_item}}"
              end
            rescue ReVIEW::KeyError => e
              raise NotImplementedError, "List reference failed for #{list_ref}: #{e.message}"
            end
          else
            "\\ref{#{escape(list_ref)}}"
          end
        end

        # Render bibliography reference
        def render_inline_bib(_type, content, node)
          return content unless node.args.first

          bib_id = node.args.first.to_s
          # Try to get bibpaper_index, either directly from instance variable or through method
          # Use instance_variable_get first to avoid bib_exist? check in tests
          bibpaper_index = @chapter&.instance_variable_get(:@bibpaper_index)
          if bibpaper_index.nil? && @chapter
            begin
              bibpaper_index = @chapter.bibpaper_index
            rescue ReVIEW::FileNotFound
              # Ignore errors when bib file doesn't exist
            end
          end

          if bibpaper_index
            begin
              bib_number = bibpaper_index.number(bib_id)
              "\\reviewbibref{[#{bib_number}]}{bib:#{bib_id}}"
            rescue ReVIEW::KeyError
              # Fallback if bibpaper not found in index
              "\\cite{#{bib_id}}"
            end
          else
            # Fallback when no bibpaper index available
            "\\cite{#{bib_id}}"
          end
        end

        # Render bibref reference (same as bib)
        def render_inline_bibref(type, content, node)
          render_inline_bib(type, content, node)
        end

        # Render same-chapter table reference
        def render_same_chapter_table_reference(node)
          table_ref = node.args.first.to_s
          if @chapter && @chapter.table_index
            begin
              table_item = @chapter.table_index.number(table_ref)
              table_label = "table:#{@chapter.id}:#{table_ref}"
              if @chapter.number
                chapter_num = @chapter.format_number(false)
                "\\reviewtableref{#{chapter_num}.#{table_item}}{#{table_label}}"
              else
                "\\reviewtableref{#{table_item}}{#{table_label}}"
              end
            rescue ReVIEW::KeyError => e
              raise NotImplementedError, "Table reference failed for #{table_ref}: #{e.message}"
            end
          else
            "\\ref{#{escape(table_ref)}}"
          end
        end

        # Render same-chapter image reference
        def render_same_chapter_image_reference(node)
          image_ref = node.args.first.to_s
          if @chapter && @chapter.image_index
            begin
              image_item = @chapter.image_index.number(image_ref)
              image_label = "image:#{@chapter.id}:#{image_ref}"
              if @chapter.number
                chapter_num = @chapter.format_number(false)
                "\\reviewimageref{#{chapter_num}.#{image_item}}{#{image_label}}"
              else
                "\\reviewimageref{#{image_item}}{#{image_label}}"
              end
            rescue ReVIEW::KeyError => e
              raise NotImplementedError, "Image reference failed for #{image_ref}: #{e.message}"
            end
          else
            # Don't escape underscores in ref labels
            "\\ref{#{image_ref}}"
          end
        end

        # Render cross-chapter list reference
        def render_cross_chapter_list_reference(node)
          chapter_id, list_id = node.args

          # Find the target chapter
          target_chapter = @book&.contents&.detect { |chap| chap.id == chapter_id }
          unless target_chapter
            raise NotImplementedError, "Cross-chapter list reference failed: chapter '#{chapter_id}' not found"
          end

          # Ensure the target chapter has list index
          unless target_chapter.list_index
            raise NotImplementedError, "Cross-chapter list reference failed: no list index for chapter '#{chapter_id}'"
          end

          begin
            list_item = target_chapter.list_index.number(list_id)
            if target_chapter.number
              chapter_num = target_chapter.format_number(false)
              "\\reviewlistref{#{chapter_num}.#{list_item}}"
            else
              "\\reviewlistref{#{list_item}}"
            end
          rescue ReVIEW::KeyError => e
            raise NotImplementedError, "Cross-chapter list reference failed for #{chapter_id}|#{list_id}: #{e.message}"
          end
        end

        # Render cross-chapter table reference
        def render_cross_chapter_table_reference(node)
          chapter_id, table_id = node.args

          # Find the target chapter
          target_chapter = @book&.contents&.detect { |chap| chap.id == chapter_id }
          unless target_chapter
            raise NotImplementedError, "Cross-chapter table reference failed: chapter '#{chapter_id}' not found"
          end

          # Ensure the target chapter has table index
          unless target_chapter.table_index
            raise NotImplementedError, "Cross-chapter table reference failed: no table index for chapter '#{chapter_id}'"
          end

          begin
            table_item = target_chapter.table_index.number(table_id)
            table_label = "table:#{chapter_id}:#{table_id}"
            if target_chapter.number
              chapter_num = target_chapter.format_number(false)
              "\\reviewtableref{#{chapter_num}.#{table_item}}{#{table_label}}"
            else
              "\\reviewtableref{#{table_item}}{#{table_label}}"
            end
          rescue ReVIEW::KeyError => e
            raise NotImplementedError, "Cross-chapter table reference failed for #{chapter_id}|#{table_id}: #{e.message}"
          end
        end

        # Render cross-chapter image reference
        def render_cross_chapter_image_reference(node)
          chapter_id, image_id = node.args

          # Find the target chapter
          target_chapter = @book&.contents&.detect { |chap| chap.id == chapter_id }
          unless target_chapter
            raise NotImplementedError, "Cross-chapter image reference failed: chapter '#{chapter_id}' not found"
          end

          # Ensure the target chapter has image index
          unless target_chapter.image_index
            raise NotImplementedError, "Cross-chapter image reference failed: no image index for chapter '#{chapter_id}'"
          end

          begin
            image_item = target_chapter.image_index.number(image_id)
            image_label = "image:#{chapter_id}:#{image_id}"
            if target_chapter.number
              chapter_num = target_chapter.format_number(false)
              "\\reviewimageref{#{chapter_num}.#{image_item}}{#{image_label}}"
            else
              "\\reviewimageref{#{image_item}}{#{image_label}}"
            end
          rescue ReVIEW::KeyError => e
            raise NotImplementedError, "Cross-chapter image reference failed for #{chapter_id}|#{image_id}: #{e.message}"
          end
        end

        # Render chapter number reference
        def render_inline_chap(_type, content, node)
          return content unless node.args.first

          chapter_id = node.args.first
          if @book && @book.chapter_index
            begin
              chapter_number = @book.chapter_index.number(chapter_id)
              "\\reviewchapref{#{chapter_number}}{chap:#{chapter_id}}"
            rescue ReVIEW::KeyError => e
              raise NotImplementedError, "Chapter reference failed for #{chapter_id}: #{e.message}"
            end
          else
            "\\reviewchapref{#{escape(chapter_id)}}{chap:#{escape(chapter_id)}}"
          end
        end

        # Render chapter title reference
        def render_inline_chapref(_type, content, node)
          return content unless node.args.first

          chapter_id = node.args.first
          if @book && @book.chapter_index
            begin
              title = @book.chapter_index.display_string(chapter_id)
              "\\reviewchapref{#{escape(title)}}{chap:#{chapter_id}}"
            rescue ReVIEW::KeyError => e
              raise NotImplementedError, "Chapter title reference failed for #{chapter_id}: #{e.message}"
            end
          else
            "\\reviewchapref{#{escape(chapter_id)}}{chap:#{escape(chapter_id)}}"
          end
        end

        # Extract heading reference from node.args, handling ReferenceResolver's array splitting
        # ReferenceResolver splits "ch02|ブロック命令" into ["ch02", "ブロック命令"]
        # We need to join them back together to get the original format
        def extract_heading_ref(node, content)
          if node.args.length >= 2
            # Multiple args - rejoin with pipe to reconstruct original format
            node.args.join('|')
          elsif node.args.first
            # Single arg - use as-is
            node.args.first
          else
            # No args - fall back to content
            content
          end
        end

        # Render heading reference
        def render_inline_hd(_type, content, node)
          heading_ref = extract_heading_ref(node, content)
          return '' if heading_ref.blank?

          handle_heading_reference(heading_ref) do |section_number, section_label, section_title|
            "\\reviewsecref{「#{section_number} #{escape(section_title)}」}{#{section_label}}"
          end
        end

        # Render section reference
        def render_inline_sec(_type, content, node)
          heading_ref = extract_heading_ref(node, content)
          return '' if heading_ref.blank?

          handle_heading_reference(heading_ref) do |section_number, section_label, _section_title|
            "\\reviewsecref{#{section_number}}{#{section_label}}"
          end
        end

        # Render section reference with full title
        def render_inline_secref(_type, content, node)
          heading_ref = extract_heading_ref(node, content)
          return '' if heading_ref.blank?

          handle_heading_reference(heading_ref) do |section_number, section_label, section_title|
            "\\reviewsecref{「#{section_number} #{escape(section_title)}」}{#{section_label}}"
          end
        end

        # Render section title only
        def render_inline_sectitle(_type, content, node)
          heading_ref = extract_heading_ref(node, content)
          return content if heading_ref.blank?

          handle_heading_reference(heading_ref) do |_section_number, section_label, section_title|
            "\\reviewsecref{#{escape(section_title)}}{#{section_label}}"
          end
        end

        # Render index entry
        def render_inline_idx(_type, content, node)
          return content unless node.args.first

          index_str = node.args.first
          # Process hierarchical index like LATEXBuilder's index method
          index_entry = process_index(index_str)
          # Index entry like LATEXBuilder
          "\\index{#{index_entry}}#{content}"
        end

        # Render hidden index entry
        def render_inline_hidx(_type, content, node)
          return content unless node.args.first

          index_str = node.args.first
          # Process hierarchical index like LATEXBuilder's index method
          index_entry = process_index(index_str)
          # Hidden index entry like LATEXBuilder - just output index, content is already rendered
          "\\index{#{index_entry}}"
        end

        # Process index string for hierarchical index entries (mendex/upmendex)
        # This is a simplified version of LATEXBuilder's index method (latexbuilder.rb:1406-1427)
        def process_index(str)
          # Split by <<>> delimiter for hierarchical index entries
          parts = str.split('<<>>')

          # Process each part and format for mendex
          formatted_parts = parts.map { |item| format_index_item(item) }

          # Join hierarchical parts with '!' for mendex/upmendex
          formatted_parts.join('!')
        end

        # Format a single index item for mendex/upmendex
        def format_index_item(item)
          if ascii_only?(item)
            format_ascii_index_item(item)
          else
            format_japanese_index_item(item)
          end
        end

        # Check if string contains only ASCII characters
        def ascii_only?(str)
          str =~ /\A[[:ascii:]]+\Z/
        end

        # Format ASCII-only index item
        def format_ascii_index_item(item)
          escaped_item = escape(item)
          mendex_escaped = escape_index(escaped_item)

          # If no escaping was needed, just return the item
          return item if mendex_escaped == item

          # Generate key@display format for proper sorting
          "#{escape_index(item)}@#{mendex_escaped}"
        end

        # Format Japanese (non-ASCII) index item with yomi reading
        def format_japanese_index_item(item)
          yomi = generate_yomi(item)
          escaped_item = escape(item)
          "#{escape_index(yomi)}@#{escape_index(escaped_item)}"
        end

        # Generate yomi (reading) for Japanese text using NKF
        def generate_yomi(text)
          require 'nkf'
          NKF.nkf('-w --hiragana', text).force_encoding('UTF-8').chomp
        rescue LoadError, ArgumentError, TypeError, RuntimeError
          # Fallback: use the original text as-is if NKF is unavailable
          text
        end

        # Render keyword notation
        def render_inline_kw(_type, content, node)
          if node.args.length >= 2
            term = escape(node.args[0])
            description = escape(node.args[1])
            "\\reviewkw{#{term}}（#{description}）"
          else
            "\\reviewkw{#{content}}"
          end
        end

        # Render ruby notation
        def render_inline_ruby(_type, content, node)
          if node.args.length >= 2
            base_text = escape(node.args[0])
            ruby_text = escape(node.args[1])
            "\\ruby{#{base_text}}{#{ruby_text}}"
          else
            content
          end
        end

        # Render icon
        def render_inline_icon(_type, content, node)
          if node.args.first
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
        end

        # Render ami notation
        def render_inline_ami(_type, content, _node)
          "\\reviewami{#{content}}"
        end

        # Render bou notation
        def render_inline_bou(_type, content, _node)
          # Boudou (emphasis)
          "\\reviewbou{#{content}}"
        end

        # Render balloon notation
        def render_inline_balloon(_type, content, _node)
          # Balloon annotation - content contains the balloon text
          "\\reviewballoon{#{content}}"
        end

        # Render mathematical expression
        def render_inline_m(_type, content, node)
          # Mathematical expressions - don't escape content
          "$#{node.args.first || content}$"
        end

        # Render superscript
        def render_inline_sup(_type, content, _node)
          "\\textsuperscript{#{content}}"
        end

        # Render superscript (alias)
        def render_inline_superscript(type, content, node)
          render_inline_sup(type, content, node)
        end

        # Render subscript
        def render_inline_sub(_type, content, _node)
          "\\textsubscript{#{content}}"
        end

        # Render subscript (alias)
        def render_inline_subscript(type, content, node)
          render_inline_sub(type, content, node)
        end

        # Render strikethrough
        def render_inline_del(_type, content, _node)
          "\\reviewstrike{#{content}}"
        end

        # Render strikethrough (alias)
        def render_inline_strike(type, content, node)
          render_inline_del(type, content, node)
        end

        # Render insert
        def render_inline_ins(_type, content, _node)
          "\\reviewinsert{#{content}}"
        end

        # Render insert (alias)
        def render_inline_insert(type, content, node)
          render_inline_ins(type, content, node)
        end

        # Render unicode character
        def render_inline_uchar(_type, content, node)
          # Unicode character handling like LATEXBuilder
          if node.args.first
            char_code = node.args.first
            texcompiler = @book.config['texcommand']
            if texcompiler&.start_with?('platex')
              # with otf package - use \UTF macro
              "\\UTF{#{escape(char_code)}}"
            else
              # upLaTeX or other - convert to actual Unicode character
              [char_code.to_i(16)].pack('U')
            end
          else
            content
          end
        end

        # Render line break
        def render_inline_br(_type, _content, _node)
          "\\\\\n"
        end

        # Render word expansion
        def render_inline_w(_type, content, _node)
          # Word expansion - pass through content
          content
        end

        # Render word expansion (bold)
        def render_inline_wb(_type, content, _node)
          # Word expansion - pass through content
          content
        end

        # Render raw content
        def render_inline_raw(_type, content, node)
          if node.args.first
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
        end

        # Render embedded content
        def render_inline_embed(_type, content, _node)
          # Embedded content - pass through
          content
        end

        # Render label reference
        def render_inline_labelref(_type, content, node)
          # Use resolved content from ReferenceResolver if available,
          # otherwise fall back to legacy behavior
          if content && !content.empty?
            "\\textbf{#{escape(content)}}"
          elsif node.args.first
            ref_id = node.args.first
            "\\ref{#{escape(ref_id)}}"
          else
            ''
          end
        end

        # Render reference (same as labelref)
        def render_inline_ref(type, content, node)
          render_inline_labelref(type, content, node)
        end

        # Render inline comment
        def render_inline_comment(_type, content, _node)
          if @book&.config&.[]('draft')
            "\\pdfcomment{#{escape(content)}}"
          else
            ''
          end
        end

        # Render title reference
        def render_inline_title(_type, content, node)
          if node.args.first
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
              rescue ReVIEW::KeyError => e
                raise NotImplementedError, "Chapter title reference failed for #{chapter_id}: #{e.message}"
              end
            else
              "\\reviewtitle{#{escape(chapter_id)}}"
            end
          else
            content
          end
        end

        # Render endnote reference
        def render_inline_endnote(_type, content, node)
          if node.args.first
            # Endnote reference
            ref_id = node.args.first
            if @chapter && @chapter.endnote_index
              begin
                index_item = @chapter.endnote_index[ref_id]
                # Use content directly from index item (no endnote_node in traditional index)
                endnote_content = escape(index_item.content || '')
                "\\endnote{#{endnote_content}}"
              rescue ReVIEW::KeyError => _e
                "\\endnote{#{escape(ref_id)}}"
              end
            else
              "\\endnote{#{escape(ref_id)}}"
            end
          else
            content
          end
        end

        # Render page reference
        def render_inline_pageref(_type, content, node)
          if node.args.first
            # Page reference
            ref_id = node.args.first
            "\\pageref{#{escape(ref_id)}}"
          else
            content
          end
        end

        # Render column reference
        def render_inline_column(_type, _content, node)
          id = node.args.first
          m = /\A([^|]+)\|(.+)/.match(id)
          if m && m[1] && @book
            chapter = @book.chapters.detect { |chap| chap.id == m[1] }
          end
          if chapter
            render_column_chap(chapter, m[2])
          else
            render_column_chap(@chapter, id)
          end
        rescue ReVIEW::KeyError => e
          raise NotImplementedError, "Unknown column: #{id} - #{e.message}"
        end

        # Render column reference for specific chapter
        def render_column_chap(chapter, id)
          return "\\reviewcolumnref{#{escape(id)}}{}" unless chapter&.column_index

          begin
            column_item = chapter.column_index[id]
            caption = column_item.caption
            # Get column number like LatexRenderer#generate_column_label does
            num = column_item.number
            column_label = "column:#{chapter.id}:#{num}"

            compiled_caption = @parent_renderer.render_inline_text(caption)
            column_text = I18n.t('column', compiled_caption)
            "\\reviewcolumnref{#{column_text}}{#{column_label}}"
          rescue ReVIEW::KeyError => e
            raise NotImplementedError, "Unknown column: #{id} in chapter #{chapter.id} - #{e.message}"
          end
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
                  # Get the full section number from headline_index (already includes chapter number)
                  full_number = target_chapter.headline_index.number(heading_id)

                  # Check if we should show the number based on secnolevel (like LATEXBuilder line 1095-1100)
                  section_number = if full_number.present? && target_chapter.number && over_secnolevel?(full_number)
                                     # Show full number with chapter: "2.1", "2.1.2", etc.
                                     full_number
                                   else
                                     # Without chapter number - extract relative part only
                                     # headline_index.number returns "2.1" but we want "1"
                                     headline_item.number.join('.')
                                   end

                  # Generate label using chapter number and relative section number (like SecCounter.anchor does)
                  # Use target_chapter.format_number(false) to get the chapter number prefix
                  chapter_prefix = target_chapter.format_number(false)
                  relative_parts = headline_item.number.join('-')
                  section_label = "sec:#{chapter_prefix}-#{relative_parts}"
                  yield(section_number, section_label, headline_item.caption || heading_id)
                else
                  # Fallback when heading not found in target chapter
                  fallback_format % "#{chapter_id}-#{heading_parts.join('-')}"
                end
              rescue ReVIEW::KeyError
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
                # Get the full section number from headline_index (already includes chapter number)
                full_number = @chapter.headline_index.number(heading_ref)

                # Check if we should show the number based on secnolevel
                section_number = if full_number.present? && @chapter.number && over_secnolevel?(full_number)
                                   # Show full number with chapter: "2.1", "2.1.2", etc.
                                   full_number
                                 else
                                   # Without chapter number - extract relative part only
                                   headline_item.number.join('.')
                                 end

                # Generate label using chapter ID and relative section number (like SecCounter.anchor does)
                # Use chapter format_number to get chapter ID prefix, then add relative section parts
                chapter_prefix = @chapter.format_number(false)
                relative_parts = headline_item.number.join('-')
                section_label = "sec:#{chapter_prefix}-#{relative_parts}"
                yield(section_number, section_label, headline_item.caption || heading_ref)
              else
                # Fallback if headline not found in index
                fallback_format % escape(heading_ref)
              end
            rescue ReVIEW::KeyError
              # Fallback on any error
              fallback_format % escape(heading_ref)
            end
          else
            # Fallback when no headline index available
            fallback_format % escape(heading_ref)
          end
        end

        # Check if section number level is within secnolevel
        def over_secnolevel?(num)
          @book.config['secnolevel'] >= num.to_s.split('.').size
        end
      end
    end
  end
end
