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

        def initialize(renderer, book:, chapter:, doc_status:, foottext:)
          @renderer = renderer
          @book = book
          @chapter = chapter
          @doc_status = doc_status
          @foottext = foottext

          # Initialize LaTeX character escaping
          initialize_metachars('')
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
          if node.args && node.args.length >= 2
            url = escape_url(node.args[0])
            text = escape_latex(node.args[1])
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
        end

        def render_inline_fn(_type, content, node)
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
                rescue StandardError => e
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
                                     @renderer.render_footnote_ast(index_item.footnote_node)
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
        end

        # Render list reference
        def render_inline_list(_type, content, node)
          return content unless node.args && !node.args.empty?

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
          return content unless node.args && !node.args.empty?

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
          return content unless node.args && !node.args.empty?

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
          return content unless node.args && node.args.first

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
        end

        # Render bibliography reference
        def render_inline_bib(_type, content, node)
          return content unless node.args && node.args.first

          # Don't escape underscores in bibliography keys - they're allowed in LaTeX cite commands
          bib_key = node.args.first.to_s
          "\\cite{#{bib_key}}"
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
        end

        # Render same-chapter image reference
        def render_same_chapter_image_reference(node)
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
              "\\reviewlistref{#{target_chapter.number}.#{list_item}}"
            else
              "\\reviewlistref{#{list_item}}"
            end
          rescue StandardError => e
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
              "\\reviewtableref{#{target_chapter.number}.#{table_item}}{#{table_label}}"
            else
              "\\reviewtableref{#{table_item}}{#{table_label}}"
            end
          rescue StandardError => e
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
              "\\reviewimageref{#{target_chapter.number}.#{image_item}}{#{image_label}}"
            else
              "\\reviewimageref{#{image_item}}{#{image_label}}"
            end
          rescue StandardError => e
            raise NotImplementedError, "Cross-chapter image reference failed for #{chapter_id}|#{image_id}: #{e.message}"
          end
        end

        # Render chapter number reference
        def render_inline_chap(_type, content, node)
          return content unless node.args && node.args.first

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
        end

        # Render chapter title reference
        def render_inline_chapref(_type, content, node)
          return content unless node.args && node.args.first

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
        end

        # Render heading reference
        def render_inline_hd(_type, content, node)
          return content unless node.args && node.args.first

          heading_ref = node.args.first
          # Heading reference - handle both simple and chapter|heading format
          handle_heading_reference(heading_ref) do |section_number, section_label, section_title|
            "\\reviewsecref{「#{section_number} #{escape(section_title)}」}{#{section_label}}"
          end
        end

        # Render section reference
        def render_inline_sec(_type, content, node)
          return content unless node.args && node.args.first

          heading_ref = node.args.first
          # Section reference - use Re:VIEW section reference like LATEXBuilder
          handle_heading_reference(heading_ref) do |section_number, section_label, _section_title|
            "\\reviewsecref{#{section_number}}{#{section_label}}"
          end
        end

        # Render section reference with full title
        def render_inline_secref(_type, content, node)
          return content unless node.args && node.args.first

          heading_ref = node.args.first
          # Section reference with full title - use Re:VIEW section reference like LATEXBuilder
          handle_heading_reference(heading_ref) do |section_number, section_label, section_title|
            "\\reviewsecref{「#{section_number} #{escape(section_title)}」}{#{section_label}}"
          end
        end

        # Render section title only
        def render_inline_sectitle(_type, content, node)
          return content unless node.args && node.args.first

          heading_ref = node.args.first
          # Section title only - use Re:VIEW section reference like LATEXBuilder
          handle_heading_reference(heading_ref) do |_section_number, section_label, section_title|
            "\\reviewsecref{#{escape(section_title)}}{#{section_label}}"
          end
        end

        # Render index entry
        def render_inline_idx(_type, content, node)
          return content unless node.args && node.args.first

          index_text = escape(node.args.first)
          # Index entry like LATEXBuilder
          "\\index{#{index_text}}"
        end

        # Render hidden index entry
        def render_inline_hidx(_type, content, node)
          return content unless node.args && node.args.first

          index_text = escape(node.args.first)
          # Hidden index entry like LATEXBuilder
          "\\index{#{index_text}}#{content}"
        end

        # Render keyword notation
        def render_inline_kw(_type, content, node)
          if node.args && node.args.length >= 2
            term = escape(node.args[0])
            description = escape(node.args[1])
            "\\reviewkw{#{term}}（#{description}）"
          else
            "\\reviewkw{#{content}}"
          end
        end

        # Render ruby notation
        def render_inline_ruby(_type, content, node)
          if node.args && node.args.length >= 2
            base_text = escape(node.args[0])
            ruby_text = escape(node.args[1])
            "\\ruby{#{base_text}}{#{ruby_text}}"
          else
            content
          end
        end

        # Render icon
        def render_inline_icon(_type, content, node)
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
        end

        # Render ami notation
        def render_inline_ami(_type, _node, content)
          "\\reviewami{#{content}}"
        end

        # Render bou notation
        def render_inline_bou(_type, _node, content)
          # Boudou (emphasis)
          "\\reviewbou{#{content}}"
        end

        # Render balloon notation
        def render_inline_balloon(_type, _node, content)
          # Balloon annotation - content contains the balloon text
          "\\reviewballoon{#{content}}"
        end

        # Render mathematical expression
        def render_inline_m(_type, content, node)
          # Mathematical expressions - don't escape content
          "$#{node.args&.first || content}$"
        end

        # Render superscript
        def render_inline_sup(_type, _node, content)
          "\\textsuperscript{#{content}}"
        end

        # Render superscript (alias)
        def render_inline_superscript(type, content, node)
          render_inline_sup(type, content, node)
        end

        # Render subscript
        def render_inline_sub(_type, _node, content)
          "\\textsubscript{#{content}}"
        end

        # Render subscript (alias)
        def render_inline_subscript(type, content, node)
          render_inline_sub(type, content, node)
        end

        # Render strikethrough
        def render_inline_del(_type, _node, content)
          "\\reviewstrike{#{content}}"
        end

        # Render strikethrough (alias)
        def render_inline_strike(type, content, node)
          render_inline_del(type, content, node)
        end

        # Render insert
        def render_inline_ins(_type, _node, content)
          "\\reviewinsert{#{content}}"
        end

        # Render insert (alias)
        def render_inline_insert(type, content, node)
          render_inline_ins(type, content, node)
        end

        # Render unicode character
        def render_inline_uchar(_type, content, node)
          # Unicode character handling like LATEXBuilder
          if node.args && node.args.first
            char_code = node.args.first
            "\\UTF{#{escape(char_code)}}"
          else
            content
          end
        end

        # Render line break
        def render_inline_br(_type, _node, _content)
          "\\\\\n"
        end

        # Render word expansion
        def render_inline_w(_type, _node, content)
          # Word expansion - pass through content
          content
        end

        # Render word expansion (bold)
        def render_inline_wb(_type, _node, content)
          # Word expansion - pass through content
          content
        end

        # Render raw content
        def render_inline_raw(_type, content, node)
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
        end

        # Render embedded content
        def render_inline_embed(_type, _node, content)
          # Embedded content - pass through
          content
        end

        # Render label reference
        def render_inline_labelref(_type, content, node)
          if node.args && node.args.first
            ref_id = node.args.first
            "\\ref{#{escape(ref_id)}}"
          else
            content
          end
        end

        # Render reference (same as labelref)
        def render_inline_ref(type, content, node)
          render_inline_labelref(type, content, node)
        end

        # Render title reference
        def render_inline_title(_type, content, node)
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
        end

        # Render endnote reference
        def render_inline_endnote(_type, content, node)
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
        end

        # Render page reference
        def render_inline_pageref(_type, content, node)
          if node.args && node.args.first
            # Page reference
            ref_id = node.args.first
            "\\pageref{#{escape(ref_id)}}"
          else
            content
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
end
