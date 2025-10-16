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
require 'review/sec_counter'
require 'review/i18n'
require 'digest/sha2'

module ReVIEW
  module Renderer
    class IdgxmlRenderer < Base
      include ReVIEW::HTMLUtils
      include ReVIEW::TextUtils

      attr_reader :chapter, :book

      def initialize(chapter)
        super

        # Initialize I18n if not already setup
        if @book && @book.config['language']
          I18n.setup(@book.config['language'])
        else
          I18n.setup('ja') # Default to Japanese
        end

        # Initialize section counters like IDGXMLBuilder
        @section = 0
        @subsection = 0
        @subsubsection = 0
        @subsubsubsection = 0
        @sec_counter = SecCounter.new(5, @chapter) if @chapter

        # Initialize column counter
        @column = 0

        # Initialize state flags
        @noindent = nil
        @ol_num = nil
        @first_line_num = nil

        # Initialize table state
        @tsize = nil
        @tablewidth = nil
        @table_id = nil
        @col = 0

        # Initialize equation counters
        @texblockequation = 0
        @texinlineequation = 0

        # Initialize root element name
        @rootelement = 'doc'

        # Get structuredxml setting
        @secttags = @book&.config&.[]('structuredxml')

        # Initialize RenderingContext
        @rendering_context = RenderingContext.new(:document)

        # Initialize AST indexer
        @ast_indexer = nil
      end

      def visit_document(node)
        # Build indexes using AST::Indexer
        if @chapter && !@ast_indexer
          require 'review/ast/indexer'
          @ast_indexer = ReVIEW::AST::Indexer.new(@chapter)
          @ast_indexer.build_indexes(node)
        end

        # Check nolf mode (default is nolf=true, meaning no newlines)
        @nolf = @book.config['nolf'].nil? ? true : @book.config['nolf']

        # Output XML declaration and root element
        output = []
        output << %Q(<?xml version="1.0" encoding="UTF-8"?>)
        output << %Q(<#{@rootelement} xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/">)

        # Render document content
        content = render_children(node)

        # Close section tags if structuredxml is enabled
        closing_tags = ''
        if @secttags
          closing_tags += '</sect4>' if @subsubsubsection > 0
          closing_tags += '</sect3>' if @subsubsection > 0
          closing_tags += '</sect2>' if @subsection > 0
          closing_tags += '</sect>' if @section > 0
          closing_tags += '</chapter>'
        end

        # Apply solve_nest to optimize list nesting
        content = solve_nest(content)

        # Combine all parts
        output << content
        output << closing_tags
        output << "</#{@rootelement}>\n"

        result = output.join

        # Remove all newlines if nolf mode is enabled (default)
        if @nolf
          result = result.gsub(/>\n+</, '><')
        end

        result
      end

      def visit_headline(node)
        level = node.level
        label = node.label
        caption = render_children(node.caption) if node.caption

        # Close section tags as needed
        output_close_sect_tags(level)

        result = []

        # Handle section tag opening for structuredxml mode
        case level
        when 1
          result << %Q(<chapter id="chap:#{@chapter.number}">) if @secttags
          @section = 0
          @subsection = 0
          @subsubsection = 0
          @subsubsubsection = 0
        when 2
          @section += 1
          result << %Q(<sect id="sect:#{@chapter.number}.#{@section}">) if @secttags
          @subsection = 0
          @subsubsection = 0
          @subsubsubsection = 0
        when 3
          @subsection += 1
          result << %Q(<sect2 id="sect:#{@chapter.number}.#{@section}.#{@subsection}">) if @secttags
          @subsubsection = 0
          @subsubsubsection = 0
        when 4
          @subsubsection += 1
          result << %Q(<sect3 id="sect:#{@chapter.number}.#{@section}.#{@subsection}.#{@subsubsection}">) if @secttags
          @subsubsubsection = 0
        when 5
          @subsubsubsection += 1
          result << %Q(<sect4 id="sect:#{@chapter.number}.#{@section}.#{@subsection}.#{@subsubsection}.#{@subsubsubsection}">) if @secttags
        when 6
          # ignore level 6
        else
          raise "caption level too deep or unsupported: #{level}"
        end

        # Get headline prefix
        prefix, _anchor = headline_prefix(level) if @sec_counter

        # Generate label attribute
        label_attr = label.nil? ? '' : %Q( id="#{label}")

        # Generate TOC caption (without footnotes and tags)
        toccaption = escape(caption.to_s.gsub(/@<fn>\{.+?\}/, '').gsub(/<[^>]+>/, ''))

        # Output title with DTP processing instruction
        result << %Q(<title#{label_attr} aid:pstyle="h#{level}">#{prefix}#{caption}</title><?dtp level="#{level}" section="#{prefix}#{toccaption}"?>)

        result.join("\n") + "\n"
      end

      def visit_paragraph(node)
        content = render_children(node)

        # Join lines in paragraph by removing newlines (like join_lines in IDGXMLBuilder)
        # unless join_lines_by_lang is explicitly enabled
        unless @book.config['join_lines_by_lang']
          content = content.gsub(/\n/, '')
        else
          content = content.gsub(/\n/, ' ')
        end

        # Handle noindent attribute
        if node.attribute?(:noindent) || @noindent
          @noindent = nil
          return %Q(<p aid:pstyle="noindent" noindent='1'>#{content}</p>)
        end

        # Check for tab indentation (inlist attribute)
        if content =~ /\A(\t+)/
          indent_level = $1.size
          content_without_tabs = content.sub(/\A\t+/, '')
          return %Q(<p inlist="#{indent_level}">#{content_without_tabs}</p>)
        end

        # Regular paragraph
        "<p>#{content}</p>"
      end

      def visit_text(node)
        escape(node.content.to_s)
      end

      def visit_inline(node)
        content = render_children(node)
        render_inline_element(node.inline_type, content, node)
      end

      def visit_reference(node)
        # ReferenceNode is a child of InlineNode(type=ref)
        # Return empty string as the actual rendering is done by parent InlineNode
        ''
      end

      def visit_list(node)
        case node.list_type
        when :ul
          visit_ul(node)
        when :ol
          visit_ol(node)
        when :dl
          visit_dl(node)
        else
          raise NotImplementedError, "IdgxmlRenderer does not support list_type #{node.list_type}"
        end
      end

      def visit_list_item(node)
        # Should not be called directly; handled by parent list
        raise NotImplementedError, 'List item processing should be handled by visit_list'
      end

      def visit_code_block(node)
        case node.code_type
        when :list
          visit_list_code_block(node)
        when :listnum
          visit_listnum_code_block(node)
        when :emlist
          visit_emlist_code_block(node)
        when :emlistnum
          visit_emlistnum_code_block(node)
        when :cmd
          visit_cmd_code_block(node)
        when :source
          visit_source_code_block(node)
        else
          raise NotImplementedError, "Unknown code block type: #{node.code_type}"
        end
      end

      def visit_code_line(node)
        # Render children and detab
        content = render_children(node)
        detab(content)
      end

      def visit_table(node)
        # Handle imgtable specially
        if node.table_type == :imgtable
          return visit_imgtable(node)
        end

        # Regular table processing
        visit_regular_table(node)
      end

      def visit_table_row(node)
        # Should be handled by visit_table
        raise NotImplementedError, 'Table row processing should be handled by visit_table'
      end

      def visit_table_cell(node)
        # Should be handled by visit_table
        raise NotImplementedError, 'Table cell processing should be handled by visit_table'
      end

      def visit_image(node)
        image_type = node.image_type

        case image_type
        when :indepimage, :numberlessimage
          visit_indepimage(node)
        else
          visit_regular_image(node)
        end
      end

      def visit_minicolumn(node)
        type = node.minicolumn_type.to_s
        caption = render_children(node.caption) if node.caption
        content = render_children(node)

        # Use captionblock helper
        captionblock(type, content, caption)
      end

      def visit_column(node)
        caption = render_children(node.caption) if node.caption
        content = render_children(node)

        # Determine column type (empty string for regular column)
        type = ''

        # Generate column output
        @column += 1
        id_attr = %Q(id="column-#{@column}")

        result = []
        result << "<#{type}column #{id_attr}>"
        if caption
          result << %Q(<title aid:pstyle="#{type}column-title">#{caption}</title><?dtp level="9" section="#{escape(caption)}"?>)
        end
        result << content.chomp
        result << "</#{type}column>"

        result.join("\n") + "\n"
      end

      def visit_block(node)
        block_type = node.block_type.to_s

        case block_type
        when 'quote'
          content = render_children(node)
          # Content already contains <p> tags from paragraphs
          "<quote>#{content}</quote>\n"
        when 'lead', 'read'
          content = render_children(node)
          # Content already contains <p> tags from paragraphs
          "<lead>#{content}</lead>\n"
        when 'note', 'memo', 'tip', 'info', 'warning', 'important', 'caution', 'notice'
          caption = node.args&.first
          content = render_children(node)
          captionblock(block_type, content, caption)
        when 'planning', 'best', 'security', 'point', 'shoot', 'reference', 'term', 'link', 'practice', 'expert'
          caption = node.args&.first
          content = render_children(node)
          captionblock(block_type, content, caption)
        when 'insn', 'box'
          caption = node.args&.first
          content = render_children(node)
          syntaxblock(block_type, content, caption)
        when 'flushright'
          content = render_children(node)
          # Content already contains <p> tags, just add align attribute
          content.gsub('<p>', %Q(<p align='right'>)) + "\n"
        when 'centering'
          content = render_children(node)
          # Content already contains <p> tags, just add align attribute
          content.gsub('<p>', %Q(<p align='center'>)) + "\n"
        when 'rawblock'
          visit_rawblock(node)
        when 'comment'
          visit_comment_block(node)
        when 'noindent'
          @noindent = true
          ''
        when 'blankline'
          "<p/>\n"
        when 'pagebreak'
          "<pagebreak />\n"
        when 'hr'
          "<hr />\n"
        when 'label'
          label_id = node.args&.first
          %Q(<label id='#{label_id}' />\n)
        when 'dtp'
          dtp_str = node.args&.first
          %Q(<?dtp #{dtp_str} ?>\n)
        when 'bpo'
          content = render_children(node)
          %Q(<bpo>#{content.chomp}</bpo>\n)
        when 'olnum'
          # Set ordered list start number
          @ol_num = node.args&.first&.to_i
          ''
        when 'firstlinenum'
          # Set first line number for code blocks
          @first_line_num = node.args&.first&.to_i
          ''
        when 'tsize'
          # Set table size for next table
          @tsize = node.args&.first
          ''
        else
          raise NotImplementedError, "Unknown block type: #{block_type}"
        end
      end

      def visit_tex_equation(node)
        @texblockequation += 1
        content = node.content

        result = []

        if node.id?
          result << '<equationblock>'

          # Generate caption
          caption_str = if get_chap.nil?
                          %Q(<caption>#{I18n.t('equation')}#{I18n.t('format_number_without_chapter', [@chapter.equation(node.id).number])}#{I18n.t('caption_prefix_idgxml')}#{escape(node.caption.to_s)}</caption>)
                        else
                          %Q(<caption>#{I18n.t('equation')}#{I18n.t('format_number', [get_chap, @chapter.equation(node.id).number])}#{I18n.t('caption_prefix_idgxml')}#{escape(node.caption.to_s)}</caption>)
                        end

          result << caption_str if caption_top?('equation')
        end

        # Handle math format
        if @book.config['math_format'] == 'imgmath'
          fontsize = @book.config.dig('imgmath_options', 'fontsize').to_f
          lineheight = @book.config.dig('imgmath_options', 'lineheight').to_f
          math_str = "\\begin{equation*}\n\\fontsize{#{fontsize}}{#{lineheight}}\\selectfont\n#{content}\n\\end{equation*}\n"
          key = Digest::SHA256.hexdigest(math_str)
          img_path = @img_math.defer_math_image(math_str, key)
          result << '<equationimage>'
          result << %Q(<Image href="file://#{img_path}" />)
          result << '</equationimage>'
        else
          result << %Q(<replace idref="texblock-#{@texblockequation}">)
          result << '<pre>'
          result << content
          result << '</pre>'
          result << '</replace>'
        end

        if node.id?
          result << caption_str unless caption_top?('equation')
          result << '</equationblock>'
        end

        result.join("\n") + "\n"
      end

      def visit_embed(node)
        # Handle raw embed
        if node.embed_type == :raw || node.embed_type == :inline
          return process_raw_embed(node)
        end

        # Default embed processing
        if node.lines
          node.lines.join("\n") + "\n"
        elsif node.arg
          "#{node.arg}\n"
        else
          ''
        end
      end

      def visit_generic(node)
        method_name = derive_visit_method_name_string(node)
        raise NotImplementedError, "IdgxmlRenderer does not support generic visitor. Implement #{method_name} for #{node.class.name}"
      end

      private

      def render_children(node)
        return '' unless node.children

        node.children.map { |child| visit(child) }.join
      end

      def render_inline_element(type, content, node)
        require 'review/renderer/idgxml_renderer/inline_element_renderer'
        inline_renderer = InlineElementRenderer.new(
          self,
          book: @book,
          chapter: @chapter,
          rendering_context: @rendering_context
        )
        inline_renderer.render(type, content, node)
      end

      # Close section tags based on level
      def output_close_sect_tags(level)
        return unless @secttags

        closing_tags = []
        closing_tags << '</sect4>' if level <= 5 && @subsubsubsection > 0
        closing_tags << '</sect3>' if level <= 4 && @subsubsection > 0
        closing_tags << '</sect2>' if level <= 3 && @subsection > 0
        closing_tags << '</sect>' if level <= 2 && @section > 0

        closing_tags.join
      end

      # Solve list nesting like IDGXMLBuilder
      def solve_nest(content)
        content.gsub("</dd></dl>\x01→dl←\x01", '').
          gsub("\x01→/dl←\x01", "</dd></dl>←END\x01").
          gsub("</li></ul>\x01→ul←\x01", '').
          gsub("\x01→/ul←\x01", "</li></ul>←END\x01").
          gsub("</li></ol>\x01→ol←\x01", '').
          gsub("\x01→/ol←\x01", "</li></ol>←END\x01").
          gsub("</dl>←END\x01<dl>", '').
          gsub("</ul>←END\x01<ul>", '').
          gsub("</ol>←END\x01<ol>", '').
          gsub("←END\x01", '')
      end

      # Get headline prefix
      def headline_prefix(level)
        return [nil, nil] unless @sec_counter

        @sec_counter.inc(level)
        anchor = @sec_counter.anchor(level)
        prefix = @sec_counter.prefix(level, @book&.config&.[]('secnolevel'))
        [prefix, anchor]
      end

      # Get chapter number for numbering
      def get_chap(chapter = @chapter)
        if @book&.config&.[]('secnolevel') && @book.config['secnolevel'] > 0 &&
           !chapter.number.nil? && !chapter.number.to_s.empty?
          if chapter.is_a?(ReVIEW::Book::Part)
            return I18n.t('part_short', chapter.number)
          else
            return chapter.format_number(nil)
          end
        end
        nil
      end

      # Check caption position
      def caption_top?(type)
        @book&.config&.dig('caption_position', type) == 'top'
      end

      # Handle metric for IDGXML
      def handle_metric(str)
        k, v = str.split('=', 2)
        %Q(#{k}="#{v.sub(/\A["']/, '').sub(/["']\Z/, '')}")
      end

      def result_metric(array)
        " #{array.join(' ')}"
      end

      # Captionblock helper for minicolumns
      def captionblock(type, content, caption, specialstyle = nil)
        result = []
        result << "<#{type}>"
        if caption && !caption.empty?
          style = specialstyle || "#{type}-title"
          result << %Q(<title aid:pstyle='#{style}'>#{caption}</title>)
        end
        blocked_lines = split_paragraph_content(content)
        result << blocked_lines.join.chomp
        result << "</#{type}>"
        result.join("\n") + "\n"
      end

      # Syntaxblock helper for special code blocks
      def syntaxblock(type, content, caption)
        result = []

        captionstr = nil
        if caption && !caption.empty?
          titleopentag = %Q(caption aid:pstyle="#{type}-title")
          titleclosetag = 'caption'
          if type == 'insn'
            titleopentag = %Q(floattitle type="insn")
            titleclosetag = 'floattitle'
          end
          captionstr = %Q(<#{titleopentag}>#{caption}</#{titleclosetag}>)
        end

        result << "<#{type}>"
        result << captionstr if caption_top?('list') && captionstr
        result << content.chomp
        result << captionstr if !caption_top?('list') && captionstr
        result << "</#{type}>"

        result.join("\n") + "\n"
      end

      # Split paragraph content (from TextUtils)
      def split_paragraph_content(content)
        # Split content by double newlines to create paragraphs
        paragraphs = content.split(/\n\n+/)
        paragraphs.map { |para| "<p>#{para.strip}</p>" }
      end

      # Visit unordered list
      def visit_ul(node)
        result = []
        result << '<ul>'

        node.children.each do |item|
          item_content = render_children(item)
          result << %Q(<li aid:pstyle="ul-item">#{item_content.chomp}</li>)
        end

        result << '</ul>'
        result.join("\n") + "\n"
      end

      # Visit ordered list
      def visit_ol(node)
        result = []
        result << '<ol>'

        # Use @ol_num if set by olnum command, or get from node attribute
        num = node.attribute?(:start_number) ? node.fetch_attribute(:start_number) : (@ol_num || 1)
        @ol_num = num unless @ol_num

        # Count total items
        total_items = node.children.length

        node.children.each_with_index do |item, _idx|
          item_content = render_children(item)
          # num attribute should be the starting number (same for all items in IDGXMLBuilder)
          result << %Q(<li aid:pstyle="ol-item" olnum="#{@ol_num}" num="#{num}">#{item_content.chomp}</li>)
          @ol_num += 1
        end

        result << '</ol>'
        @ol_num = nil

        result.join("\n") + "\n"
      end

      # Visit definition list
      def visit_dl(node)
        result = []
        result << '<dl>'

        node.children.each do |item|
          # Get term and definitions
          if item.term_children && item.term_children.any?
            term_content = item.term_children.map { |child| visit(child) }.join
          elsif item.content
            term_content = item.content.to_s
          else
            term_content = ''
          end

          result << "<dt>#{term_content}</dt>"

          # Process definition content
          if item.children && !item.children.empty?
            definition_parts = item.children.map { |child| visit(child) }
            definition_content = definition_parts.join
            result << "<dd>#{definition_content.chomp}</dd>"
          else
            result << '<dd></dd>'
          end
        end

        result << '</dl>'
        result.join("\n") + "\n"
      end

      # Visit list code block
      def visit_list_code_block(node)
        result = []
        result << '<codelist>'

        # Generate caption if present
        if node.caption
          caption_content = render_children(node.caption)
          if node.id?
            list_header_output = generate_list_header(node.id, caption_content)
            result << list_header_output
          end
        end

        # Generate code content
        result << '<pre>'
        result << generate_code_lines_body(node)
        result << '</pre>'

        result << '</codelist>'
        result.join("\n") + "\n"
      end

      # Visit listnum code block
      def visit_listnum_code_block(node)
        result = []
        result << '<codelist>'

        # Generate caption if present
        if node.caption
          caption_content = render_children(node.caption)
          if node.id?
            list_header_output = generate_list_header(node.id, caption_content)
            result << list_header_output
          end
        end

        # Generate code content with line numbers
        result << '<pre>'
        result << generate_listnum_body(node)
        result << '</pre>'

        result << '</codelist>'
        result.join("\n") + "\n"
      end

      # Visit emlist code block
      def visit_emlist_code_block(node)
        caption_content = node.caption ? render_children(node.caption) : nil
        quotedlist(node, 'emlist', caption_content)
      end

      # Visit emlistnum code block
      def visit_emlistnum_code_block(node)
        caption_content = node.caption ? render_children(node.caption) : nil
        quotedlist_with_linenum(node, 'emlistnum', caption_content)
      end

      # Visit cmd code block
      def visit_cmd_code_block(node)
        caption_content = node.caption ? render_children(node.caption) : nil
        quotedlist(node, 'cmd', caption_content)
      end

      # Visit source code block
      def visit_source_code_block(node)
        result = []
        result << '<source>'

        caption_content = node.caption ? render_children(node.caption) : nil

        if caption_top?('list') && caption_content
          result << %Q(<caption>#{caption_content}</caption>)
        end

        result << '<pre>'
        result << generate_code_lines_body(node)
        result << '</pre>'

        if !caption_top?('list') && caption_content
          result << %Q(<caption>#{caption_content}</caption>)
        end

        result << '</source>'
        result.join("\n") + "\n"
      end

      # Generate list header like IDGXMLBuilder
      def generate_list_header(id, caption)
        return '' unless caption && !caption.empty?

        if get_chap.nil?
          %Q(<caption>#{I18n.t('list')}#{I18n.t('format_number_without_chapter', [@chapter.list(id).number])}#{I18n.t('caption_prefix_idgxml')}#{caption}</caption>)
        else
          %Q(<caption>#{I18n.t('list')}#{I18n.t('format_number', [get_chap, @chapter.list(id).number])}#{I18n.t('caption_prefix_idgxml')}#{caption}</caption>)
        end
      end

      # Generate code lines body like IDGXMLBuilder
      def generate_code_lines_body(node)
        lines = node.children.map { |line| visit(line) }

        result = []
        no = 1

        lines.each do |line|
          if @book.config['listinfo']
            line_output = %Q(<listinfo line="#{no}")
            line_output += %Q( begin="1") if no == 1
            line_output += %Q( end="#{no}") if no == lines.size
            line_output += '>'
            line_output += line
            line_output += "\n"
            line_output += '</listinfo>'
            result << line_output
          else
            result << line + "\n"
          end
          no += 1
        end

        result.join
      end

      # Generate listnum body with line numbers
      def generate_listnum_body(node)
        lines = node.children.map { |line| visit(line) }

        result = []
        no = 1
        first_line_num = @first_line_num || 1

        lines.each_with_index do |line, i|
          # Add line number span
          line_with_number = detab(%Q(<span type='lineno'>) + (i + first_line_num).to_s.rjust(2) + ': </span>' + line)

          if @book.config['listinfo']
            line_output = %Q(<listinfo line="#{no}")
            line_output += %Q( begin="1") if no == 1
            line_output += %Q( end="#{no}") if no == lines.size
            line_output += '>'
            line_output += line_with_number
            line_output += "\n"
            line_output += '</listinfo>'
            result << line_output
          else
            result << line_with_number + "\n"
          end
          no += 1
        end

        # Clear @first_line_num after use
        @first_line_num = nil

        result.join
      end

      # Quotedlist helper
      def quotedlist(node, css_class, caption)
        result = []
        result << %Q(<list type='#{css_class}'>)

        if caption_top?('list') && caption
          result << %Q(<caption aid:pstyle='#{css_class}-title'>#{caption}</caption>)
        end

        result << '<pre>'
        result << generate_code_lines_body(node)
        result << '</pre>'

        if !caption_top?('list') && caption
          result << %Q(<caption aid:pstyle='#{css_class}-title'>#{caption}</caption>)
        end

        result << '</list>'
        result.join("\n") + "\n"
      end

      # Quotedlist with line numbers
      def quotedlist_with_linenum(node, css_class, caption)
        result = []
        result << %Q(<list type='#{css_class}'>)

        if caption_top?('list') && caption
          result << %Q(<caption aid:pstyle='#{css_class}-title'>#{caption}</caption>)
        end

        result << '<pre>'

        # Generate lines with line numbers
        lines = node.children.map { |line| visit(line) }
        no = 1
        first_line_num = @first_line_num || 1

        lines.each_with_index do |line, i|
          # Add line number span
          line_with_number = detab(%Q(<span type='lineno'>) + (i + first_line_num).to_s.rjust(2) + ': </span>' + line)

          if @book.config['listinfo']
            line_output = %Q(<listinfo line="#{no}")
            line_output += %Q( begin="1") if no == 1
            line_output += %Q( end="#{no}") if no == lines.size
            line_output += '>'
            line_output += line_with_number
            line_output += "\n"
            line_output += '</listinfo>'
            result << line_output
          else
            result << line_with_number + "\n"
          end
          no += 1
        end

        # Clear @first_line_num after use
        @first_line_num = nil

        result << '</pre>'

        if !caption_top?('list') && caption
          result << %Q(<caption aid:pstyle='#{css_class}-title'>#{caption}</caption>)
        end

        result << '</list>'
        result.join("\n") + "\n"
      end

      # Visit regular table
      def visit_regular_table(node)
        @tablewidth = nil
        if @book.config['tableopt']
          @tablewidth = @book.config['tableopt'].split(',')[0].to_f / @book.config['pt_to_mm_unit'].to_f
        end
        @col = 0

        # Parse table rows
        all_rows = node.header_rows + node.body_rows
        rows_data = parse_table_rows_from_ast(all_rows)

        result = []
        result << '<table>'

        caption_content = node.caption ? render_children(node.caption) : nil

        # Caption at top if configured
        if caption_top?('table') && caption_content
          result << generate_table_header(node.id, caption_content)
        end

        # Generate tbody
        if @tablewidth.nil?
          result << '<tbody>'
        else
          result << %Q(<tbody xmlns:aid5="http://ns.adobe.com/AdobeInDesign/5.0/" aid:table="table" aid:trows="#{rows_data[:rows].length}" aid:tcols="#{@col}">)
        end

        @table_id = node.id
        result << generate_table_rows(rows_data, node.header_rows.length)

        result << '</tbody>'

        # Caption at bottom if configured
        if !caption_top?('table') && caption_content
          result << generate_table_header(node.id, caption_content)
        end

        result << '</table>'

        # Clear tsize after use
        @tsize = nil

        result.join("\n") + "\n"
      end

      # Parse table rows from AST
      def parse_table_rows_from_ast(rows)
        processed_rows = []

        rows.each do |row_node|
          cells = row_node.children.map do |cell_node|
            render_children(cell_node)
          end

          col_count = cells.length
          @col = col_count if col_count > @col

          # Apply table width processing if enabled
          if @tablewidth
            cells = cells.map do |cell|
              cell.gsub("\t.\t", "\tDUMMYCELLSPLITTER\t")
                  .gsub("\t..\t", "\t.\t")
                  .gsub(/\t\.\Z/, "\tDUMMYCELLSPLITTER")
                  .gsub(/\t\.\.\Z/, "\t.")
                  .gsub(/\A\./, '')
            end
          end

          processed_rows << cells
        end

        { rows: processed_rows }
      end

      # Generate table header
      def generate_table_header(id, caption)
        return '' unless caption && !caption.empty?

        if id.nil?
          %Q(<caption>#{caption}</caption>)
        elsif get_chap
          %Q(<caption>#{I18n.t('table')}#{I18n.t('format_number', [get_chap, @chapter.table(id).number])}#{I18n.t('caption_prefix_idgxml')}#{caption}</caption>)
        else
          %Q(<caption>#{I18n.t('table')}#{I18n.t('format_number_without_chapter', [@chapter.table(id).number])}#{I18n.t('caption_prefix_idgxml')}#{caption}</caption>)
        end
      end

      # Generate table rows
      def generate_table_rows(rows_data, header_count)
        rows = rows_data[:rows]

        # Calculate cell widths
        cellwidth = []
        if @tablewidth
          if @tsize.nil?
            @col.times { |n| cellwidth[n] = @tablewidth / @col }
          else
            cellwidth = @tsize.split(/\s*,\s*/)
            totallength = 0
            cellwidth.size.times do |n|
              cellwidth[n] = cellwidth[n].to_f / @book.config['pt_to_mm_unit'].to_f
              totallength += cellwidth[n]
            end
            if cellwidth.size < @col
              cw = (@tablewidth - totallength) / (@col - cellwidth.size)
              (cellwidth.size..(@col - 1)).each { |i| cellwidth[i] = cw }
            end
          end
        end

        result = []

        # Output header rows if present
        if header_count > 0
          header_count.times do |y|
            if @tablewidth.nil?
              result << %Q(<tr type="header">#{rows.shift.join("\t")}</tr>)
            else
              i = 0
              rows.shift.each_with_index do |cell, x|
                result << %Q(<td xyh="#{x + 1},#{y + 1},#{header_count}" aid:table="cell" aid:theader="1" aid:crows="1" aid:ccols="1" aid:ccolwidth="#{sprintf('%.3f', cellwidth[i])}">#{cell.sub('DUMMYCELLSPLITTER', '')}</td>)
                i += 1
              end
            end
          end
        end

        # Output body rows
        if @tablewidth
          rows.each_with_index do |row, y|
            i = 0
            row.each_with_index do |cell, x|
              result << %Q(<td xyh="#{x + 1},#{y + 1 + header_count},#{header_count}" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="#{sprintf('%.3f', cellwidth[i])}">#{cell.sub('DUMMYCELLSPLITTER', '')}</td>)
              i += 1
            end
          end
        else
          lastline = rows.pop
          rows.each { |row| result << "<tr>#{row.join("\t")}</tr>" }
          result << %Q(<tr type="lastline">#{lastline.join("\t")}</tr>) if lastline
        end

        result.join("\n")
      end

      # Visit imgtable
      def visit_imgtable(node)
        caption_content = node.caption ? render_children(node.caption) : nil

        if @chapter.image_bound?(node.id)
          metrics = parse_metric('idgxml', node.metric)

          result = []
          result << '<table>'

          if caption_top?('table') && caption_content
            result << generate_table_header(node.id, caption_content)
          end

          result << %Q(<imgtable><Image href="file://#{@chapter.image(node.id).path.sub(%r{\A./}, '')}"#{metrics} /></imgtable>)

          if !caption_top?('table') && caption_content
            result << generate_table_header(node.id, caption_content)
          end

          result << '</table>'

          result.join("\n") + "\n"
        else
          # Fall back to image dummy
          visit_image_dummy(node.id, caption_content, [])
        end
      end

      # Visit regular image
      def visit_regular_image(node)
        caption_content = node.caption ? render_children(node.caption) : nil

        if @chapter.image_bound?(node.id)
          metrics = parse_metric('idgxml', node.metric)

          result = []
          result << '<img>'

          if caption_top?('image') && caption_content
            result << generate_image_header(node.id, caption_content)
          end

          result << %Q(<Image href="file://#{@chapter.image(node.id).path.sub(%r{\A./}, '')}"#{metrics} />)

          if !caption_top?('image') && caption_content
            result << generate_image_header(node.id, caption_content)
          end

          result << '</img>'

          result.join("\n") + "\n"
        else
          # Fall back to dummy image
          visit_image_dummy(node.id, caption_content, [])
        end
      end

      # Visit indepimage
      def visit_indepimage(node)
        caption_content = node.caption ? render_children(node.caption) : nil
        metrics = parse_metric('idgxml', node.metric)

        result = []
        result << '<img>'

        if caption_top?('image') && caption_content
          result << %Q(<caption>#{caption_content}</caption>)
        end

        begin
          result << %Q(<Image href="file://#{@chapter.image(node.id).path.sub(%r{\A\./}, '')}"#{metrics} />)
        rescue StandardError
          # Image not found, but continue
        end

        if !caption_top?('image') && caption_content
          result << %Q(<caption>#{caption_content}</caption>)
        end

        result << '</img>'

        result.join("\n") + "\n"
      end

      # Visit image dummy
      def visit_image_dummy(id, caption, lines)
        result = []
        result << '<img>'

        if caption_top?('image') && caption
          result << generate_image_header(id, caption)
        end

        result << %Q(<pre aid:pstyle="dummyimage">)
        lines.each do |line|
          result << detab(line)
          result << "\n"
        end
        result << '</pre>'

        if !caption_top?('image') && caption
          result << generate_image_header(id, caption)
        end

        result << '</img>'

        result.join("\n") + "\n"
      end

      # Generate image header
      def generate_image_header(id, caption)
        return '' unless caption && !caption.empty?

        if get_chap.nil?
          %Q(<caption>#{I18n.t('image')}#{I18n.t('format_number_without_chapter', [@chapter.image(id).number])}#{I18n.t('caption_prefix_idgxml')}#{caption}</caption>)
        else
          %Q(<caption>#{I18n.t('image')}#{I18n.t('format_number', [get_chap, @chapter.image(id).number])}#{I18n.t('caption_prefix_idgxml')}#{caption}</caption>)
        end
      end

      # Visit rawblock
      def visit_rawblock(node)
        result = []
        no = 1

        lines = node.lines || []
        lines.each do |line|
          # Unescape HTML entities
          unescaped = line.gsub('&lt;', '<').gsub('&gt;', '>').gsub('&quot;', '"').gsub('&amp;', '&')
          result << unescaped
          result << "\n" unless lines.length == no
          no += 1
        end

        result.join
      end

      # Visit comment block
      def visit_comment_block(node)
        return '' unless @book.config['draft']

        lines = []
        lines << escape(node.args.first) if node.args&.first && !node.args.first.empty?

        if node.children && !node.children.empty?
          content = render_children(node)
          lines << content unless content.empty?
        end

        return '' if lines.empty?

        str = lines.join("\n")
        "<msg>#{str}</msg>"
      end

      # Process raw embed
      def process_raw_embed(node)
        # Check if this embed is targeted for IDGXML
        unless node.targeted_for?('idgxml')
          return ''
        end

        # Get content from either arg or content attribute
        # For inline raw, content is in node.arg
        content = node.arg || node.content || ''
        # Convert literal \n to actual newline
        content.gsub('\\n', "\n")
      end

      # Escape for IDGXML (uses HTML escaping)
      def escape(str)
        escape_html(str.to_s)
      end

      # Get line number for code blocks
      def line_num
        return 1 unless @first_line_num

        line_n = @first_line_num
        @first_line_num = nil
        line_n
      end

      # Get list reference for inline @<list>{}
      def get_list_reference(id)
        chapter, extracted_id = extract_chapter_id(id)

        if get_chap(chapter)
          I18n.t('list') + I18n.t('format_number', [get_chap(chapter), chapter.list(extracted_id).number])
        else
          I18n.t('list') + I18n.t('format_number_without_chapter', [chapter.list(extracted_id).number])
        end
      rescue KeyError
        id
      end

      # Get table reference for inline @<table>{}
      def get_table_reference(id)
        chapter, extracted_id = extract_chapter_id(id)

        if get_chap(chapter)
          I18n.t('table') + I18n.t('format_number', [get_chap(chapter), chapter.table(extracted_id).number])
        else
          I18n.t('table') + I18n.t('format_number_without_chapter', [chapter.table(extracted_id).number])
        end
      rescue KeyError
        id
      end

      # Get image reference for inline @<img>{}
      def get_image_reference(id)
        chapter, extracted_id = extract_chapter_id(id)

        if get_chap(chapter)
          I18n.t('image') + I18n.t('format_number', [get_chap(chapter), chapter.image(extracted_id).number])
        else
          I18n.t('image') + I18n.t('format_number_without_chapter', [chapter.image(extracted_id).number])
        end
      rescue KeyError
        id
      end

      # Get equation reference for inline @<eq>{}
      def get_equation_reference(id)
        chapter, extracted_id = extract_chapter_id(id)

        if get_chap(chapter)
          I18n.t('equation') + I18n.t('format_number', [get_chap(chapter), chapter.equation(extracted_id).number])
        else
          I18n.t('equation') + I18n.t('format_number_without_chapter', [chapter.equation(extracted_id).number])
        end
      rescue KeyError
        id
      end

      # Extract chapter ID from reference
      def extract_chapter_id(chap_ref)
        m = /\A([\w+-]+)\|(.+)/.match(chap_ref)
        if m
          ch = @book.contents.detect { |chap| chap.id == m[1] }
          raise KeyError unless ch

          return [ch, m[2]]
        end
        [@chapter, chap_ref]
      end

      # Normalize ID for XML attributes
      def normalize_id(id)
        id.to_s.gsub(/[^a-zA-Z0-9_-]/, '_')
      end
    end
  end
end
