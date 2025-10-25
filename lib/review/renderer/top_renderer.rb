# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/renderer/base'
require 'review/textutils'
require 'review/loggable'
require 'review/i18n'

module ReVIEW
  module Renderer
    class TopRenderer < Base
      include ReVIEW::TextUtils
      include ReVIEW::Loggable

      # Japanese titles for different block types (matching TOPBuilder)
      TITLES = {
        list: 'リスト',
        listnum: '連番付きリスト',
        emlist: 'インラインリスト',
        emlistnum: '連番付きインラインリスト',
        cmd: 'コマンド',
        quote: '引用',
        source: 'ソースコード',
        table: '表',
        emtable: 'インライン表',
        imgtable: '画像付き表',
        image: '図',
        indepimage: '独立図',
        numberlessimage: '番号なし図',
        icon: 'アイコン',
        note: 'ノート',
        memo: 'メモ',
        tip: 'TIP',
        info: 'インフォ',
        warning: '警告',
        important: '重要',
        caution: '注意',
        notice: '注記'
      }.freeze

      def initialize(chapter)
        super
        @minicolumn_stack = []
        @table_row_separator_count = 0
        @first_line_number = 1
        @rendering_context = nil

        # Ensure locale strings are available
        I18n.setup(@book.config['language'] || 'ja')
      end

      def target_name
        'top'
      end

      def visit_document(node)
        render_children(node)
      end

      def visit_headline(node)
        level = node.level
        caption = render_caption_inline(node.caption_node)

        # Use headline prefix if available
        prefix = generate_headline_prefix(level)
        "■H#{level}■#{prefix}#{caption}\n"
      end

      def visit_paragraph(node)
        content = render_children(node).chomp
        return '' if content.empty?

        "#{content}\n"
      end

      def visit_list(node)
        result = +''

        case node.list_type
        when :ul
          node.children.each do |item|
            result += visit_unordered_list_item(item)
          end
        when :ol
          node.children.each_with_index do |item, index|
            result += visit_ordered_list_item(item, index + 1)
          end
        when :dl
          node.children.each do |item|
            result += visit_definition_item(item)
          end
        end

        result
      end

      def visit_unordered_list_item(node)
        # Separate text content from nested lists
        text_content = +''
        nested_lists = +''

        node.children.each do |child|
          if child.class.name.include?('ListNode')
            # This is a nested list - render it separately
            nested_lists += visit(child)
          else
            # This is regular content
            text_content += visit(child)
          end
        end

        text_content = text_content.chomp

        # Use level for nested indentation (TOP style uses tabs for each level)
        level = node.level || 1
        indent = "\t" * (level - 1)

        result = "#{indent}●\t#{text_content}\n"

        # Add any nested lists after the item
        result += nested_lists
        result
      end

      def visit_ordered_list_item(node, number)
        # Separate text content from nested lists
        text_content = +''
        nested_lists = +''

        node.children.each do |child|
          if child.class.name.include?('ListNode')
            # This is a nested list - render it separately
            nested_lists += visit(child)
          else
            # This is regular content
            text_content += visit(child)
          end
        end

        text_content = text_content.chomp

        # Use level for nested indentation
        level = node.level || 1
        indent = "\t" * (level - 1)

        result = "#{indent}#{number}\t#{text_content}\n"

        # Add any nested lists after the item
        result += nested_lists
        result
      end

      def visit_item(node)
        # Handle list items that come directly without parent list context
        content = render_children(node).chomp
        "●\t#{content}\n"
      end

      def visit_definition_item(node)
        # Handle definition term - use term_children (AST structure)
        term = if node.term_children && !node.term_children.empty?
                 node.term_children.map { |child| visit(child) }.join
               else
                 '' # No term available
               end

        # Handle definition content (all children are definition content)
        definition = if node.children && !node.children.empty?
                       node.children.map { |child| visit(child) }.join
                     end

        result = "#{term}☆\n"
        result += "\t#{definition}\n" if definition

        result
      end

      # Common code block rendering method used by all code block types
      def render_code_block_common(node)
        result = +''
        # Convert code_type to symbol if it's not already
        code_type = node.code_type.to_sym
        block_title = TITLES[code_type] || TITLES[:list]

        result += "\n"
        result += "◆→開始:#{block_title}←◆\n"

        # Add caption if present
        caption = render_caption_inline(node.caption_node)
        unless caption.empty?
          result += if node.id
                      "■#{node.id}■#{caption}\n"
                    else
                      "■#{caption}\n"
                    end
          result += "\n"
        end

        # Add line numbers if needed
        if node.line_numbers
          code_content = render_children(node).chomp
          lines = code_content.split("\n")
          lines.each_with_index do |line, i|
            line_num = (@first_line_number + i).to_s.rjust(2)
            result += "#{line_num}: #{line}\n"
          end
        else
          code_content = render_children(node)
          # Remove trailing newline if present to avoid double newlines
          code_content = code_content.chomp if code_content.end_with?("\n")
          result += code_content
          result += "\n"
        end

        result += "\n"
        result += "◆→終了:#{block_title}←◆\n"
        result += "\n"

        result
      end

      # Individual code block type visitors that delegate to common method
      def visit_code_block_list(node)
        render_code_block_common(node)
      end

      def visit_code_block_listnum(node)
        render_code_block_common(node)
      end

      def visit_code_block_emlist(node)
        render_code_block_common(node)
      end

      def visit_code_block_emlistnum(node)
        render_code_block_common(node)
      end

      def visit_code_block_cmd(node)
        render_code_block_common(node)
      end

      def visit_code_block_source(node)
        render_code_block_common(node)
      end

      def visit_code_line(node)
        render_children(node) + "\n"
      end

      def visit_table(node)
        result = +''
        @table_row_separator_count = 0

        result += "\n"
        result += "◆→開始:#{TITLES[:table]}←◆\n"

        # Add caption if present
        caption = render_caption_inline(node.caption_node)
        unless caption.empty?
          result += if node.id
                      "■#{node.id}■#{caption}\n"
                    else
                      "■#{caption}\n"
                    end
          result += "\n"
        end

        # Process table content
        result += render_children(node)

        result += "◆→終了:#{TITLES[:table]}←◆\n"
        result += "\n"

        result
      end

      def visit_table_row(node)
        cells = []
        node.children.each do |cell|
          cell_content = render_children(cell)
          # Skip separator rows (rows that contain only dashes)
          unless /^-+$/.match?(cell_content.strip)
            cells << cell_content
          end
        end

        # Only process non-empty rows
        return '' if cells.empty? || cells.all? { |cell| cell.strip.empty? }

        result = cells.join("\t") + "\n"

        # Add separator after header rows
        @table_row_separator_count += 1
        # Check if this should be treated as header (simplified logic)
        if @table_row_separator_count == 1 && should_add_table_separator?
          result += "#{'-' * 12}\n"
        end

        result
      end

      def visit_table_cell(node)
        content = render_children(node)

        # Apply bold formatting for headers if configured
        if should_format_table_header?
          "★#{content}☆"
        else
          content
        end
      end

      def visit_image(node)
        result = +''

        result += "\n"
        result += "◆→開始:#{TITLES[:image]}←◆\n"

        # Add caption if present
        caption = render_caption_inline(node.caption_node)
        unless caption.empty?
          result += if node.id
                      "■#{node.id}■#{caption}\n"
                    else
                      "■#{caption}\n"
                    end
          result += "\n"
        end

        # Add image path with metrics
        image_path = node.image_path || node.id
        metrics = format_image_metrics(node)
        result += "◆→#{image_path}#{metrics}←◆\n"

        result += "◆→終了:#{TITLES[:image]}←◆\n"
        result += "\n"

        result
      end

      def visit_minicolumn(node)
        result = +''
        minicolumn_title = TITLES[node.minicolumn_type.to_sym] || node.minicolumn_type.to_s

        @minicolumn_stack.push(node.minicolumn_type)

        result += "\n"
        result += "◆→開始:#{minicolumn_title}←◆\n"

        # Add caption if present
        caption = render_caption_inline(node.caption_node)
        unless caption.empty?
          result += "■#{caption}\n"
          result += "\n"
        end

        result += render_children(node)

        result += "◆→終了:#{minicolumn_title}←◆\n"
        result += "\n"

        @minicolumn_stack.pop

        result
      end

      # visit_block is now handled by Base renderer with dynamic method dispatch

      def visit_block_quote(node)
        result = +''

        result += "\n"
        result += "◆→開始:#{TITLES[:quote]}←◆\n"
        result += render_children(node)
        result += "◆→終了:#{TITLES[:quote]}←◆\n"
        result += "\n"

        result
      end

      def visit_generic_block(node)
        block_title = TITLES[node.block_type.to_sym] || node.block_type.to_s
        result = +''

        result += "\n"
        result += "◆→開始:#{block_title}←◆\n"
        result += render_children(node)
        result += "◆→終了:#{block_title}←◆\n"
        result += "\n"

        result
      end

      def visit_inline(node)
        type = node.inline_type
        content = render_children(node)

        case type
        when :b, :strong
          "★#{content}☆"
        when :i, :em
          "▲#{content}☆"
        when :code, :tt
          "△#{content}☆"
        when :sup
          "#{content}◆→DTP連絡:「#{content}」は上付き←◆"
        when :sub
          "#{content}◆→DTP連絡:「#{content}」は下付き←◆"
        when :br
          "\n"
        when :href
          render_href(node, content)
        when :url # rubocop:disable Lint/DuplicateBranch
          "△#{content}☆"
        when :fn
          render_footnote_ref(node, content)
        when :ruby
          render_ruby(node, content)
        when :comment
          render_comment(node, content)
        when :raw
          render_raw(node, content)
        when :labelref
          render_labelref(node, content)
        when :pageref
          render_pageref(node, content)
        else
          content
        end
      end

      def visit_footnote(node)
        footnote_id = node.id
        content = render_children(node).chomp
        footnote_number = get_footnote_number(footnote_id)

        "【注#{footnote_number}】#{content}\n"
      end

      def visit_text(node)
        node.content || ''
      end

      def visit_reference(node)
        format_resolved_reference(node.resolved_data)
      end

      private

      def generate_headline_prefix(level)
        # Simple numbering - in real implementation this would use chapter numbering
        case level
        when 1
          "#{@chapter&.number || 1}　"
        when 2
          "#{@chapter&.number || 1}.1　"
        when 3
          "#{@chapter&.number || 1}.1.1　"
        else
          ''
        end
      end

      def should_add_table_separator?
        # Simplified logic - in real implementation this would check table structure
        true
      end

      def should_format_table_header?
        # Check config for header formatting
        @book&.config&.dig('textmaker', 'th_bold') || false
      end

      def format_image_metrics(node)
        # Format image metrics if present
        metrics = +''
        if node.metric
          metrics = "、#{node.metric}"
        end
        metrics
      end

      def render_caption_inline(caption_node)
        caption_node ? render_children(caption_node) : ''
      end

      def render_href(node, content)
        args = node.args || []
        if args.length >= 2
          url = args[0]
          label = args[1]
          "#{label}（△#{url}☆）"
        else
          "△#{content}☆"
        end
      end

      def render_footnote_ref(node, content)
        args = node.args || []
        footnote_id = args.first || content
        footnote_number = get_footnote_number(footnote_id)
        "【注#{footnote_number}】"
      end

      def render_ruby(node, content)
        args = node.args || []
        if args.length >= 2
          base = args[0]
          ruby = args[1]
          "#{base}◆→DTP連絡:「#{base}」に「#{ruby}」とルビ←◆"
        else
          content
        end
      end

      def render_comment(_node, content)
        # Only render in draft mode
        if @book&.config&.[]('draft')
          "◆→#{content}←◆"
        else
          ''
        end
      end

      def render_raw(node, content)
        args = node.args || []
        if args.any?
          format = args.first
          if format == 'top'
            content
          else
            '' # Ignore raw content for other formats
          end
        else
          content
        end
      end

      def render_labelref(node, content)
        args = node.args || []
        label_id = args.first || content
        "「◆→#{label_id}←◆」"
      end

      def render_pageref(node, content)
        args = node.args || []
        label_id = args.first || content
        "●ページ◆→#{label_id}←◆"
      end

      def format_resolved_reference(data)
        case data
        when AST::ResolvedData::Image
          format_image_reference(data)
        when AST::ResolvedData::Table
          format_table_reference(data)
        when AST::ResolvedData::List
          format_list_reference(data)
        when AST::ResolvedData::Equation
          format_equation_reference(data)
        when AST::ResolvedData::Footnote
          format_footnote_reference(data)
        when AST::ResolvedData::Endnote
          format_endnote_reference(data)
        when AST::ResolvedData::Chapter
          format_chapter_reference(data)
        when AST::ResolvedData::Headline
          format_headline_reference(data)
        when AST::ResolvedData::Column
          format_column_reference(data)
        when AST::ResolvedData::Word
          data.word_content.to_s
        else
          data.item_id.to_s
        end
      end

      def format_image_reference(data)
        compose_numbered_reference('image', data)
      end

      def format_table_reference(data)
        compose_numbered_reference('table', data)
      end

      def format_list_reference(data)
        compose_numbered_reference('list', data)
      end

      def format_equation_reference(data)
        compose_numbered_reference('equation', data)
      end

      def format_footnote_reference(data)
        number = data.item_number || data.item_id
        "【注#{number}】"
      end

      def format_endnote_reference(data)
        number = data.item_number || data.item_id
        "【後注#{number}】"
      end

      def format_chapter_reference(data)
        chapter_number = data.chapter_number
        chapter_title = data.chapter_title

        if chapter_title && chapter_number
          number_text = formatted_chapter_number(chapter_number)
          I18n.t('chapter_quote', [number_text, chapter_title])
        elsif chapter_title
          I18n.t('chapter_quote_without_number', chapter_title)
        elsif chapter_number
          formatted_chapter_number(chapter_number)
        else
          data.item_id.to_s
        end
      end

      def format_headline_reference(data)
        caption = data.headline_caption || ''
        headline_numbers = Array(data.headline_number).compact

        if !headline_numbers.empty?
          number_str = headline_numbers.join('.')
          I18n.t('hd_quote', [number_str, caption])
        elsif !caption.empty?
          I18n.t('hd_quote_without_number', caption)
        else
          data.item_id.to_s
        end
      end

      def format_column_reference(data)
        label = I18n.t('columnname')
        number_text = reference_number_text(data)
        "#{label}#{number_text || data.item_id || ''}"
      end

      def compose_numbered_reference(label_key, data)
        label = I18n.t(label_key)
        number_text = reference_number_text(data)
        "#{label}#{number_text || data.item_id || ''}"
      end

      def reference_number_text(data)
        item_number = data.item_number
        return nil unless item_number

        chapter_number = data.chapter_number
        if chapter_number && !chapter_number.to_s.empty?
          I18n.t('format_number', [chapter_number, item_number])
        else
          I18n.t('format_number_without_chapter', [item_number])
        end
      rescue StandardError
        nil
      end

      def formatted_chapter_number(chapter_number)
        if chapter_number.to_s.match?(/\A-?\d+\z/)
          I18n.t('chapter', chapter_number.to_i)
        else
          chapter_number.to_s
        end
      end

      def get_footnote_number(footnote_id)
        # Simplified footnote numbering - in real implementation this would
        # use the footnote index from the chapter or book
        if @chapter&.book.respond_to?(:footnote_index) && @chapter.book.footnote_index
          @chapter.book.footnote_index[footnote_id] || 1
        elsif @book.respond_to?(:footnote_index) && @book&.footnote_index
          @book.footnote_index[footnote_id] || 1
        else
          # Fallback: simple incrementing number based on footnote_id hash
          @footnote_counter ||= {}
          @footnote_counter[footnote_id] ||= (@footnote_counter.size + 1)
        end
      end
    end
  end
end
