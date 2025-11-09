# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/textutils'
require 'review/loggable'
require_relative 'base'

module ReVIEW
  module Renderer
    class PlaintextRenderer < Base
      include ReVIEW::TextUtils
      include ReVIEW::Loggable

      def initialize(chapter)
        super
        @blank_seen = true
        @ol_num = nil
        @logger = ReVIEW.logger
      end

      # Format type for this renderer
      # @return [Symbol] Format type :text
      def format_type
        :text
      end

      def target_name
        'plaintext'
      end

      def visit_document(node)
        render_children(node)
      end

      def visit_headline(node)
        level = node.level
        caption = render_caption_inline(node.caption_node)

        # Get headline prefix like PLAINTEXTBuilder
        prefix = headline_prefix(level)
        "#{prefix}#{caption}\n"
      end

      def visit_paragraph(node)
        content = render_children(node)
        # Join lines to single paragraph like PLAINTEXTBuilder's join_lines_to_paragraph
        lines = content.split("\n")
        result = lines.join
        "#{result}\n"
      end

      def visit_list(node)
        result = +''

        case node.list_type
        when :ul
          node.children.each do |item|
            result += visit_list_item(item, :ul)
          end
        when :ol
          # Reset ol counter
          @ol_num = node.start_number || 1
          node.children.each do |item|
            result += visit_list_item(item, :ol)
            @ol_num += 1
          end
          @ol_num = nil
        when :dl
          node.children.each do |item|
            result += visit_definition_item(item)
          end
        else
          raise NotImplementedError, "PlaintextRenderer does not support list_type #{node.list_type}."
        end

        "\n#{result}\n"
      end

      def visit_list_item(node, type = :ul)
        content = render_children(node)
        # Remove paragraph newlines and join
        text = content.gsub(/\n+/, ' ').strip

        case type
        when :ul
          "#{text}\n"
        when :ol
          "#{@ol_num}　#{text}\n"
        end
      end

      def visit_definition_item(node)
        # Handle definition term
        term = if node.term_children && !node.term_children.empty?
                 node.term_children.map { |child| visit(child) }.join
               else
                 ''
               end

        # Handle definition content
        definition_parts = node.children.map { |child| visit(child) }
        definition = definition_parts.join.delete("\n")

        "#{term}\n#{definition}\n"
      end

      # Numbered code block (listnum, emlistnum)
      def render_numbered_code_block(node)
        result = +''
        caption = render_caption_inline(node.caption_node)
        lines_content = render_children(node)

        lines = lines_content.split("\n")
        lines.pop if lines.last && lines.last.empty?

        first_line_number = node.first_line_num || 1

        result += "\n" if caption_top?('list') && !caption.empty?
        result += "#{caption}\n" if caption_top?('list') && !caption.empty?
        result += "\n" if caption_top?('list') && !caption.empty?

        lines.each_with_index do |line, i|
          result += "#{(i + first_line_number).to_s.rjust(2)}: #{detab(line)}\n"
        end

        result += "\n" unless caption_top?('list')
        result += "#{caption}\n" unless caption_top?('list') || caption.empty?
        result += "\n"

        result
      end

      # Regular code block (emlist, cmd, source, etc.)
      def render_regular_code_block(node)
        result = +''
        caption = render_caption_inline(node.caption_node)
        lines_content = render_children(node)

        result += "\n" if caption_top?('list') && !caption.empty?
        result += "#{caption}\n" if caption_top?('list') && !caption.empty?

        lines_content.each_line do |line|
          result += detab(line.chomp) + "\n"
        end

        result += "#{caption}\n" unless caption_top?('list') || caption.empty?
        result += "\n"

        result
      end

      def visit_code_block_list(node)
        result = +''
        caption = render_caption_inline(node.caption_node)
        lines_content = render_children(node)

        result += "\n" if caption_top?('list') && !caption.empty?
        result += generate_list_header(node.id, caption) + "\n" if caption_top?('list') && !caption.empty?
        result += "\n" if caption_top?('list') && !caption.empty?

        lines_content.each_line do |line|
          result += detab(line.chomp) + "\n"
        end

        result += "\n" unless caption_top?('list')
        result += generate_list_header(node.id, caption) + "\n" unless caption_top?('list') || caption.empty?
        result += "\n"

        result
      end

      def visit_code_block_listnum(node)
        render_numbered_code_block(node)
      end

      def visit_code_block_emlist(node)
        render_regular_code_block(node)
      end

      def visit_code_block_emlistnum(node)
        render_numbered_code_block(node)
      end

      def visit_code_block_cmd(node)
        render_regular_code_block(node)
      end

      def visit_code_block_source(node)
        render_regular_code_block(node)
      end

      def visit_code_line(node)
        line_content = render_children(node)
        # Add newline after each line
        line_content + "\n"
      end

      def visit_table(node)
        result = +''

        # Check if this is an imgtable
        if node.table_type == :imgtable
          return render_imgtable(node)
        end

        # Add caption
        caption = render_caption_inline(node.caption_node)
        unless caption.empty?
          result += "\n"
          result += if node.id
                      generate_table_header(node.id, caption) + "\n"
                    else
                      "#{caption}\n"
                    end
          result += "\n" if caption_top?('table')
        end

        # Process table rows
        all_rows = node.header_rows + node.body_rows
        all_rows.each do |row|
          result += visit_table_row(row)
        end

        result += "\n" unless caption_top?('table')
        result += "\n"

        result
      end

      def visit_table_row(node)
        cells = node.children.map { |cell| render_children(cell) }
        cells.join("\t") + "\n"
      end

      def visit_table_cell(node)
        render_children(node)
      end

      def visit_image(node)
        result = +''
        caption = render_caption_inline(node.caption_node)

        result += "\n"
        if node.id && @chapter
          result += "#{text_formatter.format_caption_plain('image', get_chap, @chapter.image(node.id).number, caption)}\n"
        else
          result += "図　#{caption}\n" unless caption.empty?
        end
        result += "\n"

        result
      end

      def visit_minicolumn(node)
        result = +''
        caption = render_caption_inline(node.caption_node)

        result += "\n"
        result += "#{caption}\n" unless caption.empty?
        result += render_children(node)
        result += "\n"

        result
      end

      def visit_column(node)
        result = +''
        caption = render_caption_inline(node.caption_node)

        result += "\n"
        result += "#{caption}\n" unless caption.empty?
        result += render_children(node)
        result += "\n"

        result
      end

      # visit_block is now handled by Base renderer with dynamic method dispatch

      def visit_block_quote(node)
        result = +"\n"
        result += render_children(node)
        result += "\n"
        result
      end

      def visit_block_blockquote(node)
        visit_block_quote(node)
      end

      def visit_block_comment(_node)
        # Comments are not rendered in plaintext
        ''
      end

      def visit_block_blankline(_node)
        "\n"
      end

      def visit_block_pagebreak(_node)
        # Page breaks are not meaningful in plaintext
        ''
      end

      def visit_block_label(_node)
        # Labels are not rendered
        ''
      end

      def visit_block_tsize(_node)
        # Table size control is not meaningful in plaintext
        ''
      end

      def visit_block_flushright(node)
        result = +"\n"
        result += render_children(node)
        result += "\n"
        result
      end

      def visit_block_centering(node)
        result = +"\n"
        result += render_children(node)
        result += "\n"
        result
      end

      def visit_block_bibpaper(node)
        visit_bibpaper_block(node)
      end

      def visit_bibpaper_block(node)
        id = node.args[0]
        caption_text = node.args[1]

        result = +''
        if id && @chapter
          bibpaper_number = @chapter.bibpaper(id).number
          result += "#{bibpaper_number} "
        end
        result += "#{caption_text}\n" if caption_text

        content = render_children(node)
        result += "#{content}\n" unless content.strip.empty?

        result
      end

      def visit_generic_block(node)
        result = +''
        caption = render_caption_inline(node.caption_node) if node.respond_to?(:caption_node)

        result += "\n"
        result += "#{caption}\n" if caption && !caption.empty?
        result += render_children(node)
        result += "\n"

        result
      end

      def visit_tex_equation(node)
        result = +''
        content = node.content

        result += "\n"

        if node.id? && @chapter
          caption = render_caption_inline(node.caption_node)
          result += "#{text_formatter.format_caption_plain('equation', get_chap, @chapter.equation(node.id).number, caption)}\n" if caption_top?('equation')
        end

        result += "#{content}\n"

        if node.id? && @chapter
          caption = render_caption_inline(node.caption_node)
          result += "#{text_formatter.format_caption_plain('equation', get_chap, @chapter.equation(node.id).number, caption)}\n" unless caption_top?('equation')
        end

        result += "\n"
        result
      end

      def render_inline_element(type, content, node)
        method_name = "render_inline_#{type}"
        if respond_to?(method_name, true)
          send(method_name, type, content, node)
        else
          raise NotImplementedError, "Unknown inline element: #{type}"
        end
      end

      def visit_text(node)
        node.content || ''
      end

      def visit_reference(node)
        node.content || ''
      end

      def visit_footnote(node)
        footnote_id = node.id
        content = render_children(node)
        footnote_number = @chapter&.footnote(footnote_id)&.number || '??'

        "注#{footnote_number} #{content}\n"
      end

      def visit_embed(node)
        # Check if content should be output for this renderer
        return '' unless node.targeted_for?('plaintext') || node.targeted_for?('text')

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

      # Inline rendering methods
      def render_inline_fn(_type, _content, node)
        fn_id = node.target_item_id
        return '' unless fn_id && @chapter

        footnote_number = @chapter.footnote(fn_id).number
        " 注#{footnote_number} "
      rescue ReVIEW::KeyError
        ''
      end

      def render_inline_kw(_type, _content, node)
        if node.args.length >= 2
          word = node.args[0]
          alt = node.args[1].strip
          "#{word}（#{alt}）"
        else
          node.args.first || ''
        end
      end

      def render_inline_href(_type, _content, node)
        args = node.args || []
        if args.length >= 2
          url = args[0]
          label = args[1]
          "#{label}（#{url}）"
        else
          args.first || ''
        end
      end

      def render_inline_ruby(_type, _content, node)
        # Ruby base text only, ignore ruby annotation
        node.args.first || ''
      end

      def render_inline_br(_type, _content, _node)
        "\n"
      end

      def render_inline_raw(_type, _content, node)
        # Convert \n to actual newlines like PLAINTEXTBuilder
        if node.targeted_for?('plaintext') || node.targeted_for?('text')
          (node.content || '').gsub('\\n', "\n")
        else
          ''
        end
      end

      def render_inline_embed(_type, _content, node)
        # Convert \n to actual newlines like PLAINTEXTBuilder
        if node.targeted_for?('plaintext') || node.targeted_for?('text')
          (node.content || '').gsub('\\n', "\n")
        else
          ''
        end
      end

      def render_inline_hidx(_type, _content, _node)
        ''
      end

      def render_inline_icon(_type, _content, _node)
        ''
      end

      def render_inline_comment(_type, _content, _node)
        ''
      end

      def render_inline_balloon(_type, content, _node)
        "←#{content}"
      end

      def render_inline_uchar(_type, content, _node)
        [content.to_i(16)].pack('U')
      end

      def render_inline_bib(_type, _content, node)
        ref_node = node.children.first
        unless ref_node.reference_node? && ref_node.resolved?
          raise 'BUG: Reference should be resolved at AST construction time'
        end

        data = ref_node.resolved_data
        data.item_number.to_s
      end

      def render_inline_hd(_type, _content, node)
        # Headline reference
        ref_node = node.children.first
        unless ref_node.reference_node? && ref_node.resolved?
          raise 'BUG: Reference should be resolved at AST construction time'
        end

        data = ref_node.resolved_data
        text_formatter.format_reference(:headline, data)
      end

      def render_inline_labelref(_type, _content, _node)
        '●'
      end

      alias_method :render_inline_ref, :render_inline_labelref

      def render_inline_pageref(_type, _content, _node)
        '●ページ'
      end

      def render_inline_chap(_type, _content, node)
        ref_node = node.children.first
        unless ref_node.reference_node? && ref_node.resolved?
          raise 'BUG: Reference should be resolved at AST construction time'
        end

        data = ref_node.resolved_data
        text_formatter.format_chapter_number_full(data.chapter_number, data.chapter_type).to_s
      end

      def render_inline_chapref(_type, _content, node)
        ref_node = node.children.first
        unless ref_node.reference_node? && ref_node.resolved?
          raise 'BUG: Reference should be resolved at AST construction time'
        end

        data = ref_node.resolved_data
        text_formatter.format_reference(:chapter, data)
      end

      def render_inline_default(_type, content, _node)
        content
      end

      # Default inline rendering - just return content
      alias_method :render_inline_b, :render_inline_default
      alias_method :render_inline_strong, :render_inline_default
      alias_method :render_inline_i, :render_inline_default
      alias_method :render_inline_em, :render_inline_default
      alias_method :render_inline_tt, :render_inline_default
      alias_method :render_inline_code, :render_inline_default
      alias_method :render_inline_ttb, :render_inline_default
      alias_method :render_inline_ttbold, :render_inline_default
      alias_method :render_inline_tti, :render_inline_default
      alias_method :render_inline_ttibold, :render_inline_default
      alias_method :render_inline_u, :render_inline_default
      alias_method :render_inline_bou, :render_inline_default
      alias_method :render_inline_keytop, :render_inline_default
      alias_method :render_inline_m, :render_inline_default
      alias_method :render_inline_ami, :render_inline_default
      alias_method :render_inline_sup, :render_inline_default
      alias_method :render_inline_sub, :render_inline_default
      alias_method :render_inline_hint, :render_inline_default
      alias_method :render_inline_maru, :render_inline_default
      alias_method :render_inline_idx, :render_inline_default
      alias_method :render_inline_ins, :render_inline_default
      alias_method :render_inline_del, :render_inline_default
      alias_method :render_inline_tcy, :render_inline_default

      # Helper methods
      def render_caption_inline(caption_node)
        return '' unless caption_node

        content = render_children(caption_node)
        # Join lines like visit_paragraph does
        lines = content.split("\n")
        lines.join
      end

      def headline_prefix(level)
        return '' unless @chapter
        return '' unless config['secnolevel'] && config['secnolevel'] > 0

        # Generate headline prefix like PLAINTEXTBuilder
        case level
        when 1
          if @chapter.number
            "第#{@chapter.number}章　"
          else
            ''
          end
        when 2, 3, 4, 5
          # For subsections, use section counter if available
          ''
        else # rubocop:disable Lint/DuplicateBranch
          ''
        end
      end

      def generate_list_header(id, caption)
        return caption unless id && @chapter

        list_item = @chapter.list(id)
        text_formatter.format_caption_plain('list', get_chap, list_item.number, caption)
      rescue ReVIEW::KeyError
        caption
      end

      def generate_table_header(id, caption)
        return caption unless id && @chapter

        table_item = @chapter.table(id)
        text_formatter.format_caption_plain('table', get_chap, table_item.number, caption)
      rescue ReVIEW::KeyError
        caption
      end

      def render_imgtable(node)
        result = +''
        caption = render_caption_inline(node.caption_node)

        result += "\n"
        if node.id && !caption.empty?
          result += generate_table_header(node.id, caption) + "\n"
          result += "\n"
        end
        result += "\n"

        result
      end

      def get_chap(chapter = @chapter)
        return nil unless chapter
        return nil unless config['secnolevel'] && config['secnolevel'] > 0
        return nil if chapter.number.nil? || chapter.number.to_s.empty?

        if chapter.is_a?(ReVIEW::Book::Part)
          text_formatter.format_part_short(chapter)
        else
          chapter.format_number(nil)
        end
      end

      def over_secnolevel?(n, _chapter = @chapter)
        secnolevel = config['secnolevel'] || 0
        secnolevel >= n.to_s.split('.').size
      end

      def escape(str)
        # Plaintext doesn't need escaping
        str.to_s
      end
    end
  end
end
