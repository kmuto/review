# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#
# == Newline Protection Markers
#
# This renderer uses special markers to protect certain newlines from being
# removed during paragraph joining and nolf (no-line-feed) processing:
#
# - IDGXML_INLINE_NEWLINE: Protects newlines from inline elements (@<br>{}, @<raw>{\n})
#   These newlines must be preserved in the final output as they are intentionally
#   inserted by the user for formatting purposes.
#
# - IDGXML_PRE_NEWLINE: Protects newlines inside <pre> tags during nolf processing
#
# - IDGXML_LISTINFO_NEWLINE: Protects newlines inside <listinfo> tags
#
# - IDGXML_ENDNOTE_NEWLINE: Protects newlines inside <endnotes> blocks
#
# The markers are restored to actual newlines at the end of visit_document.
require 'review/renderer/base'
require 'review/renderer/rendering_context'
require 'review/renderer/list_structure_normalizer'
require 'review/htmlutils'
require 'review/textutils'
require 'review/sec_counter'
require 'review/i18n'
require 'review/loggable'
require 'digest/sha2'

module ReVIEW
  module Renderer
    class IdgxmlRenderer < Base
      include ReVIEW::HTMLUtils
      include ReVIEW::TextUtils
      include ReVIEW::Loggable

      attr_reader :chapter, :book, :logger

      def initialize(chapter)
        super

        # Initialize logger for Loggable module
        @logger = ReVIEW.logger

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

        # Initialize ImgMath for math rendering
        @img_math = nil

        # Initialize ImgGraph for graph rendering
        @img_graph = nil

        # Initialize root element name
        @rootelement = 'doc'

        # Get structuredxml setting
        @secttags = @book&.config&.[]('structuredxml')

        # Initialize RenderingContext
        @rendering_context = RenderingContext.new(:document)

        # Initialize AST helpers
        @ast_indexer = nil
        @ast_compiler = nil
        @list_structure_normalizer = nil
      end

      def visit_document(node)
        # Normalize beginchild/endchild structure before any processing
        normalize_ast_structure(node)

        # Build indexes using AST::Indexer
        if @chapter && !@ast_indexer
          require 'review/ast/indexer'
          @ast_indexer = ReVIEW::AST::Indexer.new(@chapter)
          @ast_indexer.build_indexes(node)
        end

        # Check nolf mode (enabled by default for IDGXML)
        # IDGXML format removes newlines between tags by default
        nolf = @book.config.key?('nolf') ? @book.config['nolf'] : true

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

        # Combine all parts
        output << content
        output << closing_tags
        output << "</#{@rootelement}>\n"

        result = output.join

        # Remove newlines between tags if nolf mode is enabled (default)
        # But preserve newlines inside <pre> tags and listinfo tags
        if nolf
          # Protect newlines inside <pre> tags
          result = result.gsub(%r{<pre>(.*?)</pre>}m) do |match|
            match.gsub("\n", "\x01IDGXML_PRE_NEWLINE\x01")
          end

          # Remove all newlines between tags and before closing tags
          # This handles both >\n< and text\n< patterns
          result = result.gsub(/\n+</, '<')

          # Restore newlines inside <pre> tags
          result = result.gsub("\x01IDGXML_PRE_NEWLINE\x01", "\n")
        end

        # Restore protected newlines from listinfo, inline elements, and endnotes
        result = result.gsub("\x01IDGXML_LISTINFO_NEWLINE\x01", "\n")
        result = result.gsub("\x01IDGXML_INLINE_NEWLINE\x01", "\n")
        result.gsub("\x01IDGXML_ENDNOTE_NEWLINE\x01", "\n")
      end

      def visit_headline(node)
        level = node.level
        label = node.label
        caption = render_children(node.caption) if node.caption

        result = []

        # Close section tags as needed
        closing = output_close_sect_tags(level)
        result << closing if closing && !closing.empty?

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
        # Inline elements like @<br>{} and @<raw>{} use protected markers that are preserved
        # unless join_lines_by_lang is explicitly enabled
        content = if @book.config['join_lines_by_lang']
                    content.tr("\n", ' ')
                  else
                    content.delete("\n")
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
        # Handle ReferenceNode - use resolved_data if available
        if node.resolved? && node.resolved_data
          format_resolved_reference(node.resolved_data)
        else
          # Fallback to content for backward compatibility
          node.content || ''
        end
      end

      # Format resolved reference based on ResolvedData
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
        when AST::ResolvedData::Footnote, AST::ResolvedData::Endnote
          data.item_number.to_s
        when AST::ResolvedData::Chapter
          format_chapter_reference(data)
        when AST::ResolvedData::Headline
          format_headline_reference(data)
        when AST::ResolvedData::Column
          format_column_reference(data)
        when AST::ResolvedData::Word
          escape(data.word_content)
        else
          # Default: return item_id
          escape(data.item_id)
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
        number_text = reference_number_text(data)
        label = I18n.t('equation')
        escape("#{label}#{number_text || data.item_id || ''}")
      end

      def format_chapter_reference(data)
        chapter_number = data.chapter_number
        chapter_title = data.chapter_title

        if chapter_title && chapter_number
          number_text = formatted_chapter_number(chapter_number)
          escape(I18n.t('chapter_quote', [number_text, chapter_title]))
        elsif chapter_title
          escape(I18n.t('chapter_quote_without_number', chapter_title))
        elsif chapter_number
          escape(formatted_chapter_number(chapter_number))
        else
          escape(data.item_id || '')
        end
      end

      def format_headline_reference(data)
        caption = data.headline_caption || ''
        headline_numbers = Array(data.headline_number).compact

        if !headline_numbers.empty?
          number_str = headline_numbers.join('.')
          escape(I18n.t('hd_quote', [number_str, caption]))
        elsif !caption.empty?
          escape(I18n.t('hd_quote_without_number', caption))
        else
          escape(data.item_id || '')
        end
      end

      def format_column_reference(data)
        label = I18n.t('columnname')
        number_text = reference_number_text(data)
        escape("#{label}#{number_text || data.item_id || ''}")
      end

      def compose_numbered_reference(label_key, data)
        label = I18n.t(label_key)
        number_text = reference_number_text(data)
        escape("#{label}#{number_text || data.item_id || ''}")
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
        detab(content, tabwidth)
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

        # notice uses -t suffix when caption is present
        if type == 'notice' && caption && !caption.empty?
          captionblock_with_content('notice-t', content, caption, 'notice-title')
        else
          # Content already contains <p> tags from paragraphs
          captionblock_with_content(type, content, caption)
        end
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

      def visit_block(node) # rubocop:disable Metrics/CyclomaticComplexity
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
        when 'note', 'memo', 'tip', 'info', 'warning', 'important', 'caution'
          caption = node.args.first
          content = render_children(node)
          captionblock(block_type, content, caption)
        when 'planning', 'best', 'security', 'reference', 'link', 'practice', 'expert' # rubocop:disable Lint/DuplicateBranch
          caption = node.args.first
          content = render_children(node)
          captionblock(block_type, content, caption)
        when 'point', 'shoot', 'notice'
          caption = node.args.first
          # Convert children to paragraph-grouped content
          content = render_block_content_with_paragraphs(node)
          # These blocks use -t suffix when caption is present
          if caption && !caption.empty?
            caption_with_inline = render_inline_in_caption(caption)
            captionblock("#{block_type}-t", content, caption_with_inline, "#{block_type}-title")
          else
            captionblock(block_type, content, nil)
          end
        when 'term'
          content = render_block_content_with_paragraphs(node)
          captionblock('term', content, nil)
        when 'insn', 'box'
          visit_syntaxblock(node)
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
          label_id = node.args.first
          %Q(<label id='#{label_id}' />\n)
        when 'dtp'
          dtp_str = node.args.first
          %Q(<?dtp #{dtp_str} ?>\n)
        when 'bpo'
          content = render_children(node)
          %Q(<bpo>#{content.chomp}</bpo>\n)
        when 'printendnotes'
          visit_printendnotes(node)
        when 'bibpaper'
          visit_bibpaper(node)
        when 'olnum'
          # Set ordered list start number
          @ol_num = node.args.first&.to_i
          ''
        when 'firstlinenum'
          # Set first line number for code blocks
          @first_line_num = node.args.first&.to_i
          ''
        when 'tsize'
          # Set table size for next table
          # Handle target specification like //tsize[|idgxml|2]
          tsize_arg = node.args.first
          if tsize_arg && tsize_arg.start_with?('|')
            # Parse target specification
            targets, value = parse_tsize_target(tsize_arg)
            if targets.nil? || targets.include?('idgxml')
              @tsize = value
            end
          else
            @tsize = tsize_arg
          end
          ''
        when 'graph'
          visit_graph(node)
        when 'beginchild'
          visit_beginchild(node)
        when 'endchild'
          visit_endchild(node)
        else
          raise NotImplementedError, "Unknown block type: #{block_type}"
        end
      end

      def visit_beginchild(_node)
        ''
      end

      def visit_endchild(_node)
        ''
      end

      def visit_graph(node)
        # Graph block generates an image file and then renders it as an image
        # Args: [id, command, caption]
        id = node.args[0]
        command = node.args[1]
        caption_text = node.args[2]

        # Get graph content from lines
        lines = node.lines || []
        content = lines.join("\n") + "\n"

        # Initialize ImgGraph if needed and command is mermaid
        if command == 'mermaid'
          begin
            require 'playwrightrunner'
            unless @img_graph
              require 'review/img_graph'
              @img_graph = ReVIEW::ImgGraph.new(@book.config, 'idgxml')
            end
            # Defer mermaid image generation
            file_path = @img_graph.defer_mermaid_image(content, id)
          rescue LoadError
            # Playwright not available, skip graph generation
            # But we still need a file path for rendering
            c = 'idgxml'
            dir = File.join(@book.imagedir, c)
            file_path = File.join(dir, "#{id}.pdf")
          end
        else
          # For other graph types, generate directly
          c = 'idgxml' # target_name
          dir = File.join(@book.imagedir, c)
          FileUtils.mkdir_p(dir) unless File.directory?(dir)

          # Determine image extension based on format
          image_ext = 'pdf' # IDGXML typically uses PDF
          file = "#{id}.#{image_ext}"
          file_path = File.join(dir, file)

          # Create temporary file and generate graph
          require 'tempfile'
          tf = Tempfile.new('review_graph')
          tf.puts content
          tf.close

          begin
            if command == 'graphviz' || command == 'dot'
              system_graph_graphviz(id, file_path, tf.path)
            elsif command == 'gnuplot'
              system_graph_gnuplot(id, file_path, content, tf.path)
            elsif command == 'blockdiag'
              system_graph_blockdiag(id, file_path, tf.path, 'blockdiag')
            elsif command == 'seqdiag'
              system_graph_blockdiag(id, file_path, tf.path, 'seqdiag')
            elsif command == 'actdiag'
              system_graph_blockdiag(id, file_path, tf.path, 'actdiag')
            elsif command == 'nwdiag'
              system_graph_blockdiag(id, file_path, tf.path, 'nwdiag')
            end
          ensure
            tf.unlink
          end
        end

        # Add the generated file to the image index
        @chapter.image_index.image_finder.add_entry(file_path) if @chapter.image_index

        # Now render as a regular numbered image
        caption_content = caption_text ? render_inline_in_caption(caption_text) : nil

        result = []
        result << '<img>'

        if caption_top?('image') && caption_content
          result << generate_image_header(id, caption_content)
        end

        result << %Q(<Image href="file://#{file_path.sub(%r{\A\./}, '')}" />)

        if !caption_top?('image') && caption_content
          result << generate_image_header(id, caption_content)
        end

        result << '</img>'

        result.join("\n") + "\n"
      end

      def visit_printendnotes(_node)
        return '' unless @chapter && @chapter.endnotes

        endnotes = @chapter.endnotes
        return '' if endnotes.size == 0

        result = []
        result << '<endnotes>'

        endnotes.each do |endnote_item|
          id = endnote_item.id
          number = endnote_item.number
          content = render_inline_text(endnote_item.content)
          result << %Q(<endnote id='endnoteb-#{normalize_id(id)}'><span type='endnotenumber'>(#{number})</span>\t#{content}</endnote>)
        end

        result << '</endnotes>'
        # Protect newlines inside endnotes block from nolf processing
        result.join("\x01IDGXML_ENDNOTE_NEWLINE\x01") + "\x01IDGXML_ENDNOTE_NEWLINE\x01"
      end

      def visit_bibpaper(node)
        args = node.args || []
        raise NotImplementedError, 'Malformed bibpaper block: insufficient arguments' if args.length < 2

        bib_id = args[0]
        caption_text = args[1]

        result = []
        result << %Q(<bibitem id="bib-#{bib_id}">)

        unless caption_text.nil? || caption_text.empty?
          caption_inline = render_inline_in_caption(caption_text)
          bib_number = resolve_bibpaper_number(bib_id)
          result << %Q(<caption><span type='bibno'>[#{bib_number}] </span>#{caption_inline}</caption>)
        end

        content = render_children(node)
        result << content unless content.empty?

        result << "</bibitem>\n"
        result.join("\n")
      end

      def visit_tex_equation(node)
        @texblockequation += 1
        content = node.content

        result = []

        if node.id?
          result << '<equationblock>'

          # Render caption with inline elements
          rendered_caption = render_children(node.caption)

          # Generate caption
          caption_str = if get_chap.nil?
                          %Q(<caption>#{I18n.t('equation')}#{I18n.t('format_number_without_chapter', [@chapter.equation(node.id).number])}#{I18n.t('caption_prefix_idgxml')}#{rendered_caption}</caption>)
                        else
                          %Q(<caption>#{I18n.t('equation')}#{I18n.t('format_number', [get_chap, @chapter.equation(node.id).number])}#{I18n.t('caption_prefix_idgxml')}#{rendered_caption}</caption>)
                        end

          result << caption_str if caption_top?('equation')
        end

        # Handle math format
        if @book.config['math_format'] == 'imgmath'
          # Initialize ImgMath if needed
          unless @img_math
            require 'review/img_math'
            @img_math = ReVIEW::ImgMath.new(@book.config)
          end

          fontsize = @book.config.dig('imgmath_options', 'fontsize').to_f
          lineheight = @book.config.dig('imgmath_options', 'lineheight').to_f
          math_str = "\\begin{equation*}\n\\fontsize{#{fontsize}}{#{lineheight}}\\selectfont\n#{content}\n\\end{equation*}\n"
          key = Digest::SHA256.hexdigest(math_str)
          img_path = @img_math.defer_math_image(math_str, key)
          result << '<equationimage>'
          result << %Q(<Image href="file://#{img_path}" />)
          result << '</equationimage>'
        else
          result << %Q(<replace idref="texblock-#{@texblockequation}"><pre>#{content}</pre></replace>)
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
          # Don't add trailing newline for arg-based embed
          # The compile_block test helper will strip whitespace anyway
          node.arg.to_s
        else
          ''
        end
      end

      def visit_footnote(_node)
        # FootnoteNode is not rendered directly - it's just a definition
        # The actual footnote output is generated by @<fn>{id} inline element
        # Return empty string to indicate no output for this definition block
        ''
      end

      def normalize_ast_structure(node)
        list_structure_normalizer.normalize(node)
      end

      def list_structure_normalizer
        @list_structure_normalizer ||= ListStructureNormalizer.new(self)
      end

      def render_list(node, list_type)
        tag_name = list_tag_name(node, list_type)

        body = case list_type
               when :ul
                 render_unordered_items(node)
               when :ol
                 render_ordered_items(node)
               when :dl
                 render_definition_items(node)
               else
                 raise NotImplementedError, "IdgxmlRenderer does not support list_type #{list_type}"
               end

        "<#{tag_name}>#{body}</#{tag_name}>"
      end

      def list_tag_name(node, list_type)
        levels = node.children&.map { |item| item.respond_to?(:level) ? item.level : nil }&.compact
        max_level = levels&.max || 1
        max_level > 1 ? "#{list_type}#{max_level}" : list_type.to_s
      end

      def render_unordered_items(node)
        node.children.map { |item| render_unordered_item(item) }.join
      end

      def render_unordered_item(item)
        content = render_list_item_body(item)
        %Q(<li aid:pstyle="ul-item">#{content}</li>)
      end

      def render_ordered_items(node)
        start_number = @ol_num || node.start_number || 1
        current_number = start_number

        items = node.children.map do |item|
          rendered = render_ordered_item(item, current_number)
          current_number += 1
          rendered
        end

        @ol_num = nil
        items.join
      end

      def render_ordered_item(item, current_number)
        offset = item.instance_variable_get(:@idgxml_ol_offset)
        olnum_attr = offset || current_number
        display_number = item.respond_to?(:number) && item.number ? item.number : current_number
        content = render_list_item_body(item)
        %Q(<li aid:pstyle="ol-item" olnum="#{olnum_attr}" num="#{display_number}">#{content}</li>)
      end

      def render_definition_items(node)
        node.children.map { |item| render_definition_item(item) }.join
      end

      def render_definition_item(item)
        term_content = render_inline_nodes(item.term_children)
        definition_content = render_nodes(item.children)

        if definition_content.empty?
          %Q(<dt>#{term_content}</dt><dd></dd>)
        else
          %Q(<dt>#{term_content}</dt><dd>#{definition_content}</dd>)
        end
      end

      def render_list_item_body(item)
        parts = []
        inline_buffer = []

        item.children.each do |child|
          if inline_node?(child)
            inline_buffer << visit(child)
          else
            unless inline_buffer.empty?
              parts << format_inline_buffer(inline_buffer)
              inline_buffer.clear
            end
            parts << visit(child)
          end
        end

        parts << format_inline_buffer(inline_buffer) unless inline_buffer.empty?
        content = parts.compact.join
        content.end_with?("\n") ? content.chomp : content
      end

      def render_nodes(nodes)
        return '' unless nodes && !nodes.empty?

        nodes.map { |child| visit(child) }.join
      end

      def render_inline_nodes(nodes)
        return '' unless nodes && !nodes.empty?

        format_inline_buffer(nodes.map { |child| visit(child) })
      end

      def inline_node?(node)
        node.is_a?(ReVIEW::AST::TextNode) || node.is_a?(ReVIEW::AST::InlineNode)
      end

      def format_inline_buffer(buffer)
        return '' if buffer.empty?

        content = buffer.join("\n")
        if @book.config['join_lines_by_lang']
          content.tr("\n", ' ')
        else
          content.delete("\n")
        end
      end

      def ast_compiler
        @ast_compiler ||= ReVIEW::AST::Compiler.for_chapter(@chapter)
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

      # Provide inline renderer access to inline node rendering without exposing internals
      def render_inline_nodes_from_renderer(nodes)
        render_inline_nodes(nodes)
      end

      private

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

      # Captionblock helper for content that already contains <p> tags
      def captionblock_with_content(type, content, caption, specialstyle = nil)
        result = []
        result << "<#{type}>"
        if caption && !caption.empty?
          style = specialstyle || "#{type}-title"
          result << %Q(<title aid:pstyle='#{style}'>#{caption}</title>)
        end
        # Content already contains <p> tags, use as-is
        result << content.chomp
        result << "</#{type}>"
        result.join + "\n"
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

      # Render block content with paragraph grouping
      # Used for point/shoot/notice/term blocks
      def render_block_content_with_paragraphs(node)
        # Use preserved lines if available (like box/insn)
        if node.lines && node.lines.any?
          # Process each line through inline processor
          processed_lines = node.lines.map do |line|
            if line.empty?
              ''
            else
              temp_node = ReVIEW::AST::ParagraphNode.new(location: nil)
              @ast_compiler ||= ReVIEW::AST::Compiler.for_chapter(@chapter)
              @ast_compiler.inline_processor.parse_inline_elements(line, temp_node)
              render_children(temp_node)
            end
          end

          # Group lines into paragraphs (split on empty lines)
          paragraphs = []
          current_paragraph = []
          processed_lines.each do |line|
            if line.empty?
              # Empty line signals paragraph break
              unless current_paragraph.empty?
                # Join lines in paragraph according to join_lines_by_lang setting
                paragraphs << if @book.config['join_lines_by_lang']
                                current_paragraph.join(' ')
                              else
                                current_paragraph.join
                              end
              end
              current_paragraph = []
            else
              current_paragraph << line
            end
          end
          # Add last paragraph
          unless current_paragraph.empty?
            paragraphs << if @book.config['join_lines_by_lang']
                            current_paragraph.join(' ')
                          else
                            current_paragraph.join
                          end
          end

          # Join paragraphs with double newlines so split_paragraph_content can split them
          paragraphs.join("\n\n")
        else
          # Fallback: render children directly
          render_children(node)
        end
      end

      # Visit unordered list
      def visit_ul(node)
        render_list(node, :ul)
      end

      # Visit ordered list
      def visit_ol(node)
        render_list(node, :ol)
      end

      # Visit definition list
      def visit_dl(node)
        render_list(node, :dl)
      end

      # Visit list code block
      def visit_list_code_block(node)
        result = []
        result << '<codelist>'

        # Generate caption if present
        caption_content = nil
        if node.caption && node.id?
          caption_content = render_children(node.caption)
          list_header_output = generate_list_header(node.id, caption_content)
          result << list_header_output if caption_top?('list')
        end

        # Generate code content (already includes trailing newlines for each line)
        code_content = generate_code_lines_body(node)
        # Combine <pre>, code content, and </pre> in a single string
        result << "<pre>#{code_content}</pre>"

        # Add caption at bottom if configured
        if caption_content && !caption_top?('list')
          list_header_output = generate_list_header(node.id, caption_content)
          result << list_header_output
        end

        result << '</codelist>'
        # Join without newlines (nolf mode), then add final newline
        result.join + "\n"
      end

      # Visit listnum code block
      def visit_listnum_code_block(node)
        result = []
        result << '<codelist>'

        # Generate caption if present
        caption_content = nil
        if node.caption && node.id?
          caption_content = render_children(node.caption)
          list_header_output = generate_list_header(node.id, caption_content)
          result << list_header_output if caption_top?('list')
        end

        # Generate code content with line numbers (already includes trailing newlines for each line)
        code_content = generate_listnum_body(node)
        # Combine <pre>, code content, and </pre> in a single string
        result << "<pre>#{code_content}</pre>"

        # Add caption at bottom if configured
        if caption_content && !caption_top?('list')
          list_header_output = generate_list_header(node.id, caption_content)
          result << list_header_output
        end

        result << '</codelist>'
        # Join without newlines (nolf mode), then add final newline
        result.join + "\n"
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

        # Generate code content (already includes trailing newlines for each line)
        code_content = generate_code_lines_body(node)
        # Combine <pre>, code content, and </pre> in a single string
        result << "<pre>#{code_content}</pre>"

        if !caption_top?('list') && caption_content
          result << %Q(<caption>#{caption_content}</caption>)
        end

        result << '</source>'
        # Join without newlines (nolf mode), then add final newline
        result.join + "\n"
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
            result << (line + "\n")
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
          line_with_number = detab(%Q(<span type='lineno'>) + (i + first_line_num).to_s.rjust(2) + ': </span>' + line, tabwidth)

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
            result << (line_with_number + "\n")
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

        # Generate code content (already includes trailing newlines for each line)
        code_content = generate_code_lines_body(node)
        # Combine <pre>, code content, and </pre> in a single string
        # This matches IDGXMLBuilder behavior: print '<pre>'; print lines; puts '</pre>'
        result << "<pre>#{code_content}</pre>"

        if !caption_top?('list') && caption
          result << %Q(<caption aid:pstyle='#{css_class}-title'>#{caption}</caption>)
        end

        result << '</list>'
        # Join without newlines (nolf mode), then add final newline
        result.join + "\n"
      end

      # Quotedlist with line numbers
      def quotedlist_with_linenum(node, css_class, caption)
        result = []
        result << %Q(<list type='#{css_class}'>)

        if caption_top?('list') && caption
          result << %Q(<caption aid:pstyle='#{css_class}-title'>#{caption}</caption>)
        end

        # Generate code content with line numbers (already includes trailing newlines for each line)
        code_content = generate_listnum_body(node)
        # Combine <pre>, code content, and </pre> in a single string
        result << "<pre>#{code_content}</pre>"

        if !caption_top?('list') && caption
          result << %Q(<caption aid:pstyle='#{css_class}-title'>#{caption}</caption>)
        end

        result << '</list>'
        # Join without newlines (nolf mode), then add final newline
        result.join + "\n"
      end

      # Visit regular table
      def visit_regular_table(node)
        @tablewidth = nil
        if @book.config['tableopt']
          pt_unit = @book.config['pt_to_mm_unit']
          pt_unit = pt_unit.to_f if pt_unit
          pt_unit = 1.0 if pt_unit.nil? || pt_unit == 0
          @tablewidth = @book.config['tableopt'].split(',')[0].to_f / pt_unit
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
        result << if @tablewidth.nil?
                    '<tbody>'
                  else
                    %Q(<tbody xmlns:aid5="http://ns.adobe.com/AdobeInDesign/5.0/" aid:table="table" aid:trows="#{rows_data[:rows].length}" aid:tcols="#{@col}">)
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
              cell.gsub("\t.\t", "\tDUMMYCELLSPLITTER\t").
                gsub("\t..\t", "\t.\t").
                gsub(/\t\.\Z/, "\tDUMMYCELLSPLITTER").
                gsub(/\t\.\.\Z/, "\t.").
                gsub(/\A\./, '')
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
              cellwidth[n] = cellwidth[n].to_f / @book.config['pt_to_mm_unit']
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
          result << detab(line, tabwidth)
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
        lines << escape(node.args.first) if node.args.first && !node.args.first.empty?

        # Process children as separate text lines (not as paragraphs)
        if node.children && !node.children.empty?
          node.children.each do |child|
            lines << if child.is_a?(ReVIEW::AST::TextNode)
                       escape(child.content.to_s)
                     else
                       # For other node types, render normally
                       visit(child)
                     end
          end
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

        # Get content - for both inline and block raw, content is in node.content
        # (after target processing by the parser)
        content = node.content || ''
        # Convert literal \n (backslash followed by n) to a protected newline marker
        # The marker will be preserved through paragraph and nolf processing
        content.gsub('\n', "\x01IDGXML_INLINE_NEWLINE\x01")
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
      rescue ReVIEW::KeyError
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
      rescue ReVIEW::KeyError
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
      rescue ReVIEW::KeyError
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
      rescue ReVIEW::KeyError
        id
      end

      # Extract chapter ID from reference
      def extract_chapter_id(chap_ref)
        m = /\A([\w+-]+)\|(.+)/.match(chap_ref)
        if m
          ch = @book.contents.detect { |chap| chap.id == m[1] }
          raise ReVIEW::KeyError unless ch

          return [ch, m[2]]
        end
        [@chapter, chap_ref]
      end

      # Normalize ID for XML attributes
      def normalize_id(id)
        id.to_s.gsub(/[^a-zA-Z0-9_-]/, '_')
      end

      # Count ul nesting depth by traversing parent contexts
      def count_ul_nesting_depth
        depth = 0
        current = @rendering_context
        while current
          depth += 1 if current.context_type == :ul
          current = current.parent_context
        end
        depth
      end

      # Count ol nesting depth by traversing parent contexts
      def count_ol_nesting_depth
        depth = 0
        current = @rendering_context
        while current
          depth += 1 if current.context_type == :ol
          current = current.parent_context
        end
        depth
      end

      # Visit syntaxblock (box, insn) - processes lines with listinfo
      def visit_syntaxblock(node)
        type = node.block_type.to_s
        caption = node.args.first

        # Render caption if present
        captionstr = nil
        if caption && !caption.empty?
          titleopentag = %Q(caption aid:pstyle="#{type}-title")
          titleclosetag = 'caption'
          if type == 'insn'
            titleopentag = %Q(floattitle type="insn")
            titleclosetag = 'floattitle'
          end
          # Process inline elements in caption
          caption_with_inline = render_inline_in_caption(caption)
          captionstr = %Q(<#{titleopentag}>#{caption_with_inline}</#{titleclosetag}>)
        end

        result = []
        result << "<#{type}>"

        # Output caption at top if configured
        result << captionstr if caption_top?('list') && captionstr

        # Process lines with listinfo
        lines = extract_lines_from_node(node)
        if @book.config['listinfo'] && lines.any?
          # Generate all listinfo entries as a single string (like IDGXMLBuilder's print/puts)
          listinfo_output = lines.map.with_index do |line, i|
            no = i + 1
            line_parts = []
            line_parts << %Q(<listinfo line="#{no}")
            line_parts << %Q( begin="1") if no == 1
            line_parts << %Q( end="#{no}") if no == lines.size
            line_parts << '>'
            # Always include line content (even if empty) followed by newline
            # Protect newlines inside listinfo from nolf processing
            line_parts << detab(line, tabwidth)
            line_parts << "\x01IDGXML_LISTINFO_NEWLINE\x01"
            line_parts << '</listinfo>'
            line_parts.join
          end.join
          result << listinfo_output
        else
          lines_output = lines.map { |line| detab(line, tabwidth) + "\n" }.join
          result << lines_output
        end

        # Output caption at bottom if configured
        result << captionstr if !caption_top?('list') && captionstr

        result << "</#{type}>"
        result.join + "\n"
      end

      # Extract lines from block node and process inline elements
      def extract_lines_from_node(node)
        # If the node has preserved original lines, use them with inline processing
        if node.lines && node.lines.any?
          node.lines.map do |line|
            # Empty lines should remain empty
            if line.empty?
              ''
            else
              # Create a temporary paragraph node to process inline elements in this line
              temp_node = ReVIEW::AST::ParagraphNode.new(location: nil)
              @ast_compiler ||= ReVIEW::AST::Compiler.for_chapter(@chapter)
              @ast_compiler.inline_processor.parse_inline_elements(line, temp_node)
              # Render the inline elements
              render_children(temp_node)
            end
          end
        else
          # Fallback: render all children to get the full content
          full_content = render_children(node)

          # Split by newlines to get individual lines
          # Keep empty lines (important for blank lines in the source)
          lines = full_content.split("\n", -1)

          # Remove the last empty line if present (split always creates one at the end)
          lines.pop if lines.last == ''

          lines
        end
      end

      # Render inline elements in caption
      def render_inline_in_caption(caption_text)
        render_inline_text(caption_text)
      end

      def render_inline_text(text)
        # Create a temporary paragraph node and parse inline elements
        require 'review/ast/compiler'
        require 'review/lineinput'

        temp_node = ReVIEW::AST::ParagraphNode.new(location: nil)
        @ast_compiler ||= ReVIEW::AST::Compiler.for_chapter(@chapter)
        @ast_compiler.inline_processor.parse_inline_elements(text.to_s, temp_node)

        render_children(temp_node)
      end

      def resolve_bibpaper_number(bib_id)
        if @chapter
          begin
            return @chapter.bibpaper(bib_id).number
          rescue StandardError
            # Fallback to AST indexer if chapter lookup fails
          end
        end

        if @ast_indexer&.bibpaper_index
          begin
            return @ast_indexer.bibpaper_index.number(bib_id)
          rescue StandardError
            # fall through
          end
        end

        '??'
      end

      # Parse tsize target specification like |idgxml|2 or |idgxml,html|2
      def parse_tsize_target(arg)
        # Format: |target1,target2,...|value
        if arg =~ /\A\|([^|]+)\|(.+)/
          targets = Regexp.last_match(1).split(',').map(&:strip)
          value = Regexp.last_match(2)
          [targets, value]
        else
          # No target specification (malformed)
          [nil, arg]
        end
      end

      # Get tabwidth setting (default to 8)
      def tabwidth
        @book&.config&.[]('tabwidth') || 8
      end

      # Graph generation helper methods (for non-mermaid graphs)
      def system_graph_graphviz(_id, file_path, tf_path)
        system("dot -Tpdf -o#{file_path} #{tf_path}")
      end

      def system_graph_gnuplot(_id, file_path, content, tf_path)
        File.open(tf_path, 'w') do |tf|
          tf.puts <<~GNUPLOT
            set terminal pdf
            set output "#{file_path}"
            #{content}
          GNUPLOT
        end
        system("gnuplot #{tf_path}")
      end

      def system_graph_blockdiag(_id, file_path, tf_path, command)
        system("#{command} -Tpdf -o #{file_path} #{tf_path}")
      end
    end
  end
end
