# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/latexutils'

module ReVIEW
  module Renderer
    module Latex
      # Inline element handler for LaTeX rendering
      # Uses InlineContext for shared logic
      class InlineElementHandler
        include ReVIEW::LaTeXUtils

        def initialize(inline_context)
          @ctx = inline_context
          @chapter = @ctx.chapter
          @book = @ctx.book
          @config = @ctx.config
          # Initialize LaTeX character escaping
          initialize_metachars(@config['texcommand'])
        end

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
            raw_url = if node.children.first.leaf_node?
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

        def render_inline_fn(_type, _content, node)
          ref_node = node.children.first
          unless ref_node.reference_node? && ref_node.resolved?
            raise 'BUG: Reference should be resolved at AST construction time'
          end

          data = ref_node.resolved_data
          footnote_number = data.item_number

          # Check if we need to use footnotetext mode
          if @ctx.config['footnotetext']
            "\\footnotemark[#{footnote_number}]"
          elsif @ctx.rendering_context.requires_footnotetext?
            if data.caption_node
              @ctx.rendering_context.collect_footnote(data.caption_node, footnote_number)
            end
            '\\protect\\footnotemark{}'
          else
            footnote_content = if data.caption_node
                                 @ctx.render_children(data.caption_node)
                               else
                                 escape(data.caption_text || '')
                               end
            "\\footnote{#{footnote_content}}"
          end
        end

        # Render list reference
        def render_inline_list(_type, _content, node)
          ref_node = node.children.first
          unless ref_node.reference_node? && ref_node.resolved?
            raise 'BUG: Reference should be resolved at AST construction time'
          end

          data = ref_node.resolved_data
          list_number = data.item_number

          chapter_num = @ctx.text_formatter.format_chapter_number_short(data.chapter_number, data.chapter_type)
          if chapter_num && !chapter_num.empty?
            "\\reviewlistref{#{chapter_num}.#{list_number}}"
          else
            "\\reviewlistref{#{list_number}}"
          end
        end

        # Render listref reference (same as list)
        def render_inline_listref(type, content, node)
          render_inline_list(type, content, node)
        end

        # Render table reference
        def render_inline_table(_type, _content, node)
          ref_node = node.children.first
          unless ref_node.reference_node? && ref_node.resolved?
            raise 'BUG: Reference should be resolved at AST construction time'
          end

          data = ref_node.resolved_data
          table_number = data.item_number
          # Use current chapter ID if chapter_id is not set in resolved_data
          chapter_id = data.chapter_id || @chapter&.id
          table_label = "table:#{chapter_id}:#{data.item_id}"

          short_num = @ctx.text_formatter.format_chapter_number_short(data.chapter_number, data.chapter_type)
          if short_num && !short_num.empty?
            "\\reviewtableref{#{short_num}.#{table_number}}{#{table_label}}"
          else
            "\\reviewtableref{#{table_number}}{#{table_label}}"
          end
        end

        # Render tableref reference (same as table)
        def render_inline_tableref(type, content, node)
          render_inline_table(type, content, node)
        end

        # Render image reference
        def render_inline_img(_type, _content, node)
          ref_node = node.children.first
          unless ref_node.reference_node? && ref_node.resolved?
            raise 'BUG: Reference should be resolved at AST construction time'
          end

          data = ref_node.resolved_data
          image_number = data.item_number
          # Use current chapter ID if chapter_id is not set in resolved_data
          chapter_id = data.chapter_id || @chapter&.id
          image_label = "image:#{chapter_id}:#{data.item_id}"

          short_num = @ctx.text_formatter.format_chapter_number_short(data.chapter_number, data.chapter_type)
          if short_num && !short_num.empty?
            "\\reviewimageref{#{short_num}.#{image_number}}{#{image_label}}"
          else
            "\\reviewimageref{#{image_number}}{#{image_label}}"
          end
        end

        # Render imgref reference (same as img)
        def render_inline_imgref(type, content, node)
          render_inline_img(type, content, node)
        end

        # Render equation reference
        def render_inline_eq(_type, _content, node)
          ref_node = node.children.first
          unless ref_node.reference_node? && ref_node.resolved?
            raise 'BUG: Reference should be resolved at AST construction time'
          end

          data = ref_node.resolved_data
          equation_number = data.item_number

          short_num = @ctx.text_formatter.format_chapter_number_short(data.chapter_number, data.chapter_type)
          if short_num && !short_num.empty?
            "\\reviewequationref{#{short_num}.#{equation_number}}"
          else
            "\\reviewequationref{#{equation_number}}"
          end
        end

        # Render eqref reference (same as eq)
        def render_inline_eqref(type, content, node)
          render_inline_eq(type, content, node)
        end

        # Render same-chapter list reference
        def render_same_chapter_list_reference(node)
          list_ref = node.args.first.to_s
          if @chapter && @ctx.chapter.list_index
            begin
              list_item = @ctx.chapter.list_index.number(list_ref)
              if @ctx.chapter.number
                chapter_num = @ctx.chapter.format_number(false)
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
        def render_inline_bib(_type, _content, node)
          ref_node = node.children.first
          unless ref_node.reference_node? && ref_node.resolved?
            raise 'BUG: Reference should be resolved at AST construction time'
          end

          data = ref_node.resolved_data
          bib_number = data.item_number
          bib_id = data.item_id
          "\\reviewbibref{[#{bib_number}]}{bib:#{bib_id}}"
        end

        # Render bibref reference (same as bib)
        def render_inline_bibref(type, content, node)
          render_inline_bib(type, content, node)
        end

        # Render same-chapter table reference
        def render_same_chapter_table_reference(node)
          table_ref = node.args.first.to_s
          if @chapter && @ctx.chapter.table_index
            begin
              table_item = @ctx.chapter.table_index.number(table_ref)
              table_label = "table:#{@ctx.chapter.id}:#{table_ref}"
              if @ctx.chapter.number
                chapter_num = @ctx.chapter.format_number(false)
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
          if @chapter && @ctx.chapter.image_index
            begin
              image_item = @ctx.chapter.image_index.number(image_ref)
              image_label = "image:#{@ctx.chapter.id}:#{image_ref}"
              if @ctx.chapter.number
                chapter_num = @ctx.chapter.format_number(false)
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
          target_chapter = @ctx.book.contents&.detect { |chap| chap.id == chapter_id }
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
          target_chapter = @ctx.book.contents&.detect { |chap| chap.id == chapter_id }
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
          target_chapter = @ctx.book.contents&.detect { |chap| chap.id == chapter_id }
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
        def render_inline_chap(_type, _content, node)
          ref_node = node.children.first
          unless ref_node.reference_node? && ref_node.resolved?
            raise 'BUG: Reference should be resolved at AST construction time'
          end

          data = ref_node.resolved_data
          # Format chapter number to full form (e.g., "第1章", "付録A", "第II部")
          chapter_num = @ctx.text_formatter.format_chapter_number_full(data.chapter_number, data.chapter_type)
          "\\reviewchapref{#{chapter_num}}{chap:#{data.item_id}}"
        end

        # Render chapter title reference
        def render_inline_chapref(_type, _content, node)
          ref_node = node.children.first
          unless ref_node.reference_node? && ref_node.resolved?
            raise 'BUG: Reference should be resolved at AST construction time'
          end

          data = ref_node.resolved_data
          display_str = data.to_text
          "\\reviewchapref{#{escape(display_str)}}{chap:#{data.item_id}}"
        end

        # Extract heading reference from node.args, handling ReferenceResolver's array splitting
        # ReferenceResolver splits "ch02|ブロック命令" into ["ch02", "ブロック命令"]
        # We need to join them back together to get the original format
        # Build heading reference parts from resolved_data
        # Returns [section_number, section_label, section_title]
        def build_heading_reference_parts(data)
          # Get headline_number array (e.g., [1, 2] for section 1.2)
          headline_number = data.headline_number || []

          # Get caption from caption_node
          section_title = data.caption_text

          # Determine chapter context
          if data.chapter_id && data.chapter_number
            # Cross-chapter reference
            short_chapter = @ctx.text_formatter.format_chapter_number_short(data.chapter_number, data.chapter_type)
            chapter_prefix = short_chapter
          elsif @chapter && @ctx.chapter.number
            # Same chapter reference
            short_chapter = @ctx.chapter.format_number(false)
            chapter_prefix = short_chapter
          else
            # Reference without chapter number
            short_chapter = '0'
            chapter_prefix = '0'
          end

          # Build section number for display
          full_number_parts = [short_chapter] + headline_number
          full_section_number = full_number_parts.join('.')

          # Check if we should show the number based on secnolevel
          section_number = if short_chapter != '0' && @ctx.over_secnolevel?(full_section_number)
                             # Show full number with chapter: "2.1", "2.1.2", etc.
                             full_section_number
                           else
                             # Without chapter number - use relative section number only
                             headline_number.join('.')
                           end

          # Generate label using chapter prefix and relative section number
          relative_parts = headline_number.join('-')
          section_label = "sec:#{chapter_prefix}-#{relative_parts}"

          [section_number, section_label, section_title]
        end

        # Render heading reference
        def render_inline_hd(_type, _content, node)
          ref_node = node.children.first
          unless ref_node.reference_node? && ref_node.resolved?
            raise 'BUG: Reference should be resolved at AST construction time'
          end

          data = ref_node.resolved_data
          section_number, section_label, section_title = build_heading_reference_parts(data)
          "\\reviewsecref{「#{section_number} #{escape(section_title)}」}{#{section_label}}"
        end

        # Render section reference
        def render_inline_sec(_type, _content, node)
          ref_node = node.children.first
          unless ref_node.reference_node? && ref_node.resolved?
            raise 'BUG: Reference should be resolved at AST construction time'
          end

          data = ref_node.resolved_data
          section_number, section_label, _section_title = build_heading_reference_parts(data)
          "\\reviewsecref{#{section_number}}{#{section_label}}"
        end

        # Render section reference with full title
        def render_inline_secref(_type, _content, node)
          ref_node = node.children.first
          unless ref_node.reference_node? && ref_node.resolved?
            raise 'BUG: Reference should be resolved at AST construction time'
          end

          data = ref_node.resolved_data
          section_number, section_label, section_title = build_heading_reference_parts(data)
          "\\reviewsecref{「#{section_number} #{escape(section_title)}」}{#{section_label}}"
        end

        # Render section title only
        def render_inline_sectitle(_type, _content, node)
          ref_node = node.children.first
          unless ref_node.reference_node? && ref_node.resolved?
            raise 'BUG: Reference should be resolved at AST construction time'
          end

          data = ref_node.resolved_data
          _section_number, section_label, section_title = build_heading_reference_parts(data)
          "\\reviewsecref{#{escape(section_title)}}{#{section_label}}"
        end

        # Render index entry
        def render_inline_idx(_type, content, node)
          return content unless node.args.first

          index_str = node.args.first
          # Process hierarchical index like LATEXBuilder's index method
          index_entry = process_index(index_str)
          # Index entry like LATEXBuilder - content first, then index
          "#{content}\\index{#{index_entry}}"
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

          # Generate key@display format for proper sorting like LATEXBuilder (latexbuilder.rb:1418)
          "#{escape_mendex_key(escape_index(item))}@#{escape_mendex_display(mendex_escaped)}"
        end

        # Format Japanese (non-ASCII) index item with yomi reading
        def format_japanese_index_item(item)
          # Check dictionary first like LATEXBuilder (latexbuilder.rb:1411-1412)
          index_db = @ctx.index_db
          yomi = if index_db && index_db[item]
                   index_db[item]
                 else
                   # Generate yomi using MeCab like LATEXBuilder (latexbuilder.rb:1421-1422)
                   generate_yomi(item)
                 end
          escaped_item = escape(item)
          "#{escape_mendex_key(escape_index(yomi))}@#{escape_mendex_display(escape_index(escaped_item))}"
        end

        # Generate yomi (reading) for Japanese text using MeCab + NKF like LATEXBuilder (latexbuilder.rb:1421)
        def generate_yomi(text)
          # If MeCab is available, use it to parse and generate reading
          index_mecab = @ctx.index_mecab
          if index_mecab
            require 'nkf'
            NKF.nkf('-w --hiragana', index_mecab.parse(text).force_encoding('UTF-8').chomp)
          else
            # Fallback: use the original text as-is if MeCab is unavailable
            text
          end
        rescue LoadError, ArgumentError, TypeError, RuntimeError
          # Fallback: use the original text as-is if processing fails
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
          return content unless node.args.first

          icon_id = node.args.first
          image_path = find_image_path(icon_id)

          if image_path
            command = 'reviewicon'
            "\\#{command}{#{image_path}}"
          else
            "\\verb|--[[path = #{icon_id} (not exist)]]--|"
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

        # Render subscript
        def render_inline_sub(_type, content, _node)
          "\\textsubscript{#{content}}"
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
            texcompiler = @ctx.config['texcommand']
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
        def render_inline_raw(_type, _content, node)
          node.targeted_for?('latex') ? (node.content || '') : ''
        end

        # Render embedded content
        def render_inline_embed(_type, _content, node)
          node.targeted_for?('latex') ? (node.content || '') : ''
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
          if @ctx.draft_mode?
            "\\pdfcomment{#{escape(content)}}"
          else
            ''
          end
        end

        # Render column reference
        def render_inline_column(_type, _content, node)
          ref_node = node.children.first
          unless ref_node.reference_node? && ref_node.resolved?
            raise 'BUG: Reference should be resolved at AST construction time'
          end

          data = ref_node.resolved_data
          column_number = data.item_number
          chapter_id = data.chapter_id || @ctx.chapter&.id
          column_label = "column:#{chapter_id}:#{column_number}"

          # Render caption with inline markup
          compiled_caption = if data.caption_node
                               @ctx.render_caption_inline(data.caption_node)
                             else
                               data.caption_text
                             end
          column_text = @ctx.text_formatter.format_column_label(compiled_caption)
          "\\reviewcolumnref{#{column_text}}{#{column_label}}"
        end

        # Render endnote
        def render_inline_endnote(_type, _content, node)
          ref_node = node.children.first
          unless ref_node.reference_node? && ref_node.resolved?
            raise 'BUG: Reference should be resolved at AST construction time'
          end

          data = ref_node.resolved_data
          endnote_content = escape(data.caption_text || '')
          "\\endnote{#{endnote_content}}"
        end

        # Render title reference (@<title>{chapter_id})
        def render_inline_title(_type, _content, node)
          ref_node = node.children.first
          unless ref_node.reference_node? && ref_node.resolved?
            raise 'BUG: Reference should be resolved at AST construction time'
          end

          data = ref_node.resolved_data
          title = data.to_title_text
          if @ctx.chapter_link_enabled?
            "\\reviewchapref{#{escape(title)}}{chap:#{data.item_id}}"
          else
            escape(title)
          end
        end

        private

        # Find image path for icon
        def find_image_path(icon_id)
          @ctx.chapter&.image(icon_id)&.path
        rescue StandardError
          nil
        end
      end
    end
  end
end
