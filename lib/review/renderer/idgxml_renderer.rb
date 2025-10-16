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
# The markers are restored to actual newlines at the end of visit_document.
#
# == List Nesting Markers
#
# This renderer uses special markers to handle nested list structures. These markers
# are used by solve_nest to properly merge consecutive lists of the same type while
# maintaining correct nesting levels (ul, ul2, ul3, etc.):
#
# - IDGXML_LIST_NEST_START: Marks the start of a nested list structure
# - IDGXML_LIST_NEST_END: Marks the end of a nested list structure
#
# These markers are processed and removed by solve_nest at the end of visit_document.

require 'review/renderer/base'
require 'review/renderer/rendering_context'
require 'review/htmlutils'
require 'review/textutils'
require 'review/sec_counter'
require 'review/i18n'
require 'digest/sha2'

module ReVIEW
  module Renderer
    # Context for managing list rendering with proper encapsulation
    class ListContext
      attr_reader :list_type, :depth
      attr_accessor :needs_close_tag, :has_nested_content

      def initialize(list_type, depth)
        @list_type = list_type # :ul, :ol, :dl (as symbol)
        @depth = depth
        @needs_close_tag = false
        @has_nested_content = false
      end

      # Generate appropriate tag name with depth suffix
      def tag_name
        @depth == 1 ? @list_type.to_s : "#{@list_type}#{@depth}"
      end

      # Generate opening marker for nested lists (used by solve_nest)
      def opening_marker
        return '' if @depth == 1

        case @list_type
        when :ul then IdgxmlRenderer::IDGXML_LIST_NEST_UL_START
        when :ol then IdgxmlRenderer::IDGXML_LIST_NEST_OL_START
        when :dl then IdgxmlRenderer::IDGXML_LIST_NEST_DL_START
        else ''
        end
      end

      # Generate closing marker for nested lists (used by solve_nest)
      def closing_marker
        return '' if @depth == 1

        case @list_type
        when :ul then IdgxmlRenderer::IDGXML_LIST_NEST_UL_END
        when :ol then IdgxmlRenderer::IDGXML_LIST_NEST_OL_END
        when :dl then IdgxmlRenderer::IDGXML_LIST_NEST_DL_END
        else ''
        end
      end

      # Get appropriate item closing tag
      def item_close_tag
        case @list_type
        when :ul, :ol then '</li>'
        when :dl then '</dd>'
        else ''
        end
      end

      def mark_nested_content
        @has_nested_content = true
      end
    end

    # Legacy context for beginchild/endchild compatibility
    class NestContext
      attr_accessor :list_type, :needs_close_tag

      def initialize(list_type)
        @list_type = list_type # 'ul', 'ol', 'dl' (as string for legacy)
        @needs_close_tag = false
      end

      def close_tag
        return '' unless @needs_close_tag

        case @list_type
        when 'ul', 'ol'
          '</li>'
        when 'dl'
          '</dd>'
        else
          ''
        end
      end
    end

    class IdgxmlRenderer < Base
      include ReVIEW::HTMLUtils
      include ReVIEW::TextUtils

      attr_reader :chapter, :book

      # Marker constants for list nesting
      IDGXML_LIST_NEST_UL_START = "\x01IDGXML_LIST_NEST_UL_START\x01"
      IDGXML_LIST_NEST_UL_END = "\x01IDGXML_LIST_NEST_UL_END\x01"
      IDGXML_LIST_NEST_OL_START = "\x01IDGXML_LIST_NEST_OL_START\x01"
      IDGXML_LIST_NEST_OL_END = "\x01IDGXML_LIST_NEST_OL_END\x01"
      IDGXML_LIST_NEST_DL_START = "\x01IDGXML_LIST_NEST_DL_START\x01"
      IDGXML_LIST_NEST_DL_END = "\x01IDGXML_LIST_NEST_DL_END\x01"
      IDGXML_LIST_MERGE_MARKER = "\x01IDGXML_LIST_MERGE_MARKER\x01"

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

        # Initialize ImgMath for math rendering
        @img_math = nil

        # Initialize ImgGraph for graph rendering
        @img_graph = nil

        # Initialize list nesting tracking with stack-based approach
        @nest_stack = [] # Stack of NestContext objects
        @previous_list_type = nil
        @pending_close_tag = nil # Pending closing tag (e.g., '</li>' or '</dd>')

        # Initialize list depth tracking for solve_nest markers
        @ul_depth = 0
        @ol_depth = 0
        @dl_depth = 0

        # Initialize current list context for improved list management
        @current_list_context = nil

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

        # Apply solve_nest to merge consecutive lists of the same type
        # This is still needed even with the new nest_stack approach
        content = solve_nest(content)

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

        # Restore protected newlines from listinfo and inline elements
        result = result.gsub("\x01IDGXML_LISTINFO_NEWLINE\x01", "\n")
        result.gsub("\x01IDGXML_INLINE_NEWLINE\x01", "\n")
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

      def visit_reference(_node)
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
        when 'note', 'memo', 'tip', 'info', 'warning', 'important', 'caution'
          caption = node.args&.first
          content = render_children(node)
          captionblock(block_type, content, caption)
        when 'planning', 'best', 'security', 'reference', 'link', 'practice', 'expert'
          caption = node.args&.first
          content = render_children(node)
          captionblock(block_type, content, caption)
        when 'point', 'shoot', 'notice'
          caption = node.args&.first
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
          # Handle target specification like //tsize[|idgxml|2]
          tsize_arg = node.args&.first
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
        # beginchild marks the start of nested content within a list item
        # Validate that we're in a list context
        unless @previous_list_type
          raise ReVIEW::ApplicationError, "//beginchild is shown, but previous element isn't ul, ol, or dl"
        end

        # Mark current context as having nested content
        @current_list_context&.mark_nested_content if @current_list_context

        # Clear pending close tag (it will be handled by endchild)
        @pending_close_tag = nil

        # Push context for tracking
        @nest_stack.push(NestContext.new(@previous_list_type))

        '' # No output - just state management
      end

      def visit_endchild(_node)
        # endchild marks the end of nested content
        # Validate stack state
        if @nest_stack.empty?
          raise ReVIEW::ApplicationError, "//endchild is shown, but any opened //beginchild doesn't exist"
        end

        context = @nest_stack.pop

        # Generate appropriate closing tags based on list type
        item_close = case context.list_type
                     when 'ul', 'ol' then '</li>'
                     when 'dl' then '</dd>'
                     else ''
                     end

        # Determine list closing tag with proper depth suffix
        list_close = generate_list_closing_tag(context.list_type)

        "#{item_close}#{list_close}"
      end

      # Generate list closing tag with proper depth suffix
      # Note: This is called during endchild processing after the list has been closed,
      # so depth counters may have already been decremented. We need to use the actual
      # current depth or infer from context.
      def generate_list_closing_tag(list_type)
        # Get current depth for the list type
        depth = case list_type
                when 'ul' then @ul_depth
                when 'ol' then @ol_depth
                when 'dl' then @dl_depth
                else 1
                end

        # If depth is 0 or negative, default to 1 (shouldn't happen in well-formed documents)
        depth = 1 if depth <= 0

        tag_name = depth == 1 ? list_type : "#{list_type}#{depth}"
        "</#{tag_name}>"
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

      def visit_tex_equation(node)
        @texblockequation += 1
        content = node.content

        result = []

        if node.id?
          result << '<equationblock>'

          # Render caption with inline elements
          rendered_caption = if node.caption.is_a?(String)
                               render_inline_in_caption(node.caption)
                             elsif node.caption
                               render_children(node.caption)
                             else
                               ''
                             end

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

      def visit_generic(node)
        method_name = derive_visit_method_name_string(node)
        raise NotImplementedError, "IdgxmlRenderer does not support generic visitor. Implement #{method_name} for #{node.class.name}"
      end

      private

      # Unified list rendering with proper context management
      def render_list(node, list_type)
        with_list_context(list_type) do |context|
          result = []
          result << "<#{context.tag_name}>"
          result << context.opening_marker unless context.opening_marker.empty?

          # Render list items based on list type
          case list_type
          when :ul
            result << render_ul_items(node, context)
          when :ol
            result << render_ol_items(node, context)
          when :dl
            result << render_dl_items(node, context)
          end

          result << context.closing_marker unless context.closing_marker.empty?
          result << "</#{context.tag_name}>"

          # Track for beginchild/endchild (legacy)
          @previous_list_type = list_type.to_s

          result.join("\n") + "\n"
        end
      end

      # Context management for list rendering
      def with_list_context(list_type)
        depth = increment_list_depth(list_type)
        context = ListContext.new(list_type, depth)
        old_context = @current_list_context
        @current_list_context = context

        result = yield(context)

        @current_list_context = old_context
        decrement_list_depth(list_type)

        result
      end

      # Increment depth counter for list type
      def increment_list_depth(list_type)
        case list_type
        when :ul
          @ul_depth += 1
          @ul_depth
        when :ol
          @ol_depth += 1
          @ol_depth
        when :dl
          @dl_depth += 1
          @dl_depth
        else
          1
        end
      end

      # Decrement depth counter for list type
      def decrement_list_depth(list_type)
        case list_type
        when :ul
          @ul_depth -= 1
        when :ol
          @ol_depth -= 1
        when :dl
          @dl_depth -= 1
        end
      end

      # Render unordered list items
      def render_ul_items(node, _context)
        items = []
        node.children.each_with_index do |item, idx|
          item_content = item.children.map { |child| visit(child) }.join("\n")
          # Join lines in list item according to join_lines_by_lang setting
          item_content = if @book.config['join_lines_by_lang']
                           item_content.tr("\n", ' ')
                         else
                           item_content.delete("\n")
                         end

          items << %Q(<li aid:pstyle="ul-item">#{item_content.chomp})

          # Close </li> for all non-last items
          is_last_item = (idx == node.children.size - 1)
          if is_last_item
            # Set pending close tag for the last item
            @pending_close_tag = '</li>'
          else
            items << '</li>'
          end
        end

        items.join("\n")
      end

      # Render ordered list items
      def render_ol_items(node, _context)
        items = []
        olnum = @ol_num || 1

        node.children.each_with_index do |item, idx|
          item_content = item.children.map { |child| visit(child) }.join("\n")
          # Join lines in list item according to join_lines_by_lang setting
          item_content = if @book.config['join_lines_by_lang']
                           item_content.tr("\n", ' ')
                         else
                           item_content.delete("\n")
                         end

          # Get the num attribute from the item if available
          num = item.respond_to?(:number) ? (item.number || olnum) : olnum

          items << %Q(<li aid:pstyle="ol-item" olnum="#{olnum}" num="#{num}">#{item_content.chomp})

          # Close </li> for all non-last items
          is_last_item = (idx == node.children.size - 1)
          if is_last_item
            # Set pending close tag for the last item
            @pending_close_tag = '</li>'
          else
            items << '</li>'
          end

          olnum += 1
        end

        # Reset olnum after list
        @ol_num = nil

        items.join("\n")
      end

      # Render definition list items
      def render_dl_items(node, _context)
        items = []

        node.children.each_with_index do |item, idx|
          # Get term and definitions
          term_content = if item.term_children && item.term_children.any?
                           item.term_children.map { |child| visit(child) }.join
                         elsif item.content
                           item.content.to_s
                         else
                           ''
                         end

          items << "<dt>#{term_content}</dt>"

          # Process definition content
          is_last_item = (idx == node.children.size - 1)

          if item.children && !item.children.empty?
            definition_parts = item.children.map { |child| visit(child) }
            definition_content = definition_parts.join
            items << "<dd>#{definition_content.chomp}"
          else
            # Empty dd - output opening tag only
            items << '<dd>'
          end

          # Close </dd> for all non-last items
          if is_last_item
            # Set pending close tag for the last item
            @pending_close_tag = '</dd>'
          else
            items << '</dd>'
          end
        end

        items.join("\n")
      end

      def render_children(node)
        return '' unless node.children

        result = []
        node.children.each_with_index do |child, idx|
          # Check if next child is beginchild for special handling
          next_child = node.children[idx + 1]
          is_next_beginchild = next_child && next_child.is_a?(ReVIEW::AST::BlockNode) && next_child.block_type == :beginchild

          # Visit the child
          child_output = visit(child)

          # Handle pending close tag if present
          if @pending_close_tag && child_output
            if is_next_beginchild
              # Next is beginchild - defer the close tag handling
              # Remove the closing list tag that will be re-added after nested content
              child_output = remove_closing_list_tag(child_output)
              result << child_output
              # Keep @pending_close_tag for beginchild to handle
            else
              # Normal case - insert pending close tag
              child_output = insert_pending_close_tag(child_output)
              @pending_close_tag = nil
              result << child_output
            end
          else
            result << child_output
          end
        end

        # Final cleanup: ensure any remaining pending close tag is added
        if @pending_close_tag
          last_idx = result.length - 1
          if last_idx >= 0 && result[last_idx]
            result[last_idx] = insert_pending_close_tag(result[last_idx])
          else
            result << @pending_close_tag
          end
          @pending_close_tag = nil
        end

        result.join
      end

      # Remove closing list tag from output
      def remove_closing_list_tag(output)
        # Remove the last closing list tag (</ul>, </ol>, or </dl>)
        output.sub(%r{</(ul|ol|dl)>\n?\z}, '')
      end

      # Insert pending close tag before the closing list tag
      def insert_pending_close_tag(output)
        # Find the last closing list tag (</ul>, </ol>, or </dl>)
        if output =~ %r{(.*)</(ul|ol|dl)>(\n?)\z}m
          # Insert the pending close tag before the closing list tag
          before_closing = $1
          list_type = $2
          trailing_newline = $3
          "#{before_closing}#{@pending_close_tag}</#{list_type}>#{trailing_newline}"
        elsif output.end_with?("\n")
          # No closing list tag found - append at the end
          output.chomp + @pending_close_tag + "\n"
        else
          output + @pending_close_tag
        end
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

      # Merge consecutive lists of the same type that appear at the same nesting level.
      # This is required for IDGXML format to properly handle list continuations.
      #
      # The IDGXML format requires that consecutive lists of the same type at the same
      # nesting level be merged into a single list structure. This is achieved through
      # a multi-step marker-based post-processing approach.
      #
      # Processing steps:
      # 1. Remove opening markers from nested lists
      # 2. Convert closing markers to merge markers
      # 3. Merge consecutive lists by removing intermediate tags
      # 4. Merge top-level lists (without markers)
      # 5. Clean up remaining markers
      #
      # Example transformation:
      #   Input:  </ul><ul>
      #   Output: (merged into single list with items continuing)
      #
      # This follows the same pattern as IDGXMLBuilder.solve_nest
      def solve_nest(content)
        # Step 1: Remove opening markers from nested lists
        content = remove_opening_markers(content)

        # Step 2: Convert closing markers to merge markers
        content = convert_to_merge_markers(content)

        # Step 3: Merge consecutive lists using merge markers
        content = merge_lists_with_markers(content)

        # Step 4: Merge consecutive top-level lists (no markers)
        content = merge_toplevel_lists(content)

        # Step 5: Clean up any remaining merge markers
        content.gsub(/#{Regexp.escape(IDGXML_LIST_MERGE_MARKER)}/o, '')
      end

      # Step 1: Remove opening markers that appear at nested list start
      # These markers are placed right after opening tag of nested lists
      # Pattern: <TYPE(N)>\n?MARKER -> <TYPE(N)> (remove opening marker)
      def remove_opening_markers(content)
        content.
          gsub(/<(dl\d+)>\n?#{Regexp.escape(IDGXML_LIST_NEST_DL_START)}/o, '<\1>').
          gsub(/<(ul\d+)>\n?#{Regexp.escape(IDGXML_LIST_NEST_UL_START)}/o, '<\1>').
          gsub(/<(ol\d+)>\n?#{Regexp.escape(IDGXML_LIST_NEST_OL_START)}/o, '<\1>').
          # Also handle case where opening marker appears after closing item tags
          # Pattern: </dd></dl(N)>MARKER -> empty (remove nested list opening marker)
          gsub(%r{</dd></dl(\d*)>\n?#{Regexp.escape(IDGXML_LIST_NEST_DL_START)}}o, '').
          gsub(%r{</li></ul(\d*)>\n?#{Regexp.escape(IDGXML_LIST_NEST_UL_START)}}o, '').
          gsub(%r{</li></ol(\d*)>\n?#{Regexp.escape(IDGXML_LIST_NEST_OL_START)}}o, '')
      end

      # Step 2: Convert closing markers to MERGE markers
      # Pattern: CLOSE_MARKER\n?</TYPE(N)> -> </item></TYPE(N)>MERGE_MARKER
      def convert_to_merge_markers(content)
        content.
          gsub(%r{#{Regexp.escape(IDGXML_LIST_NEST_DL_END)}\n?</dl(\d*)>}o, "</dd></dl\\1>#{IDGXML_LIST_MERGE_MARKER}").
          gsub(%r{#{Regexp.escape(IDGXML_LIST_NEST_UL_END)}\n?</ul(\d*)>}o, "</li></ul\\1>#{IDGXML_LIST_MERGE_MARKER}").
          gsub(%r{#{Regexp.escape(IDGXML_LIST_NEST_OL_END)}\n?</ol(\d*)>}o, "</li></ol\\1>#{IDGXML_LIST_MERGE_MARKER}")
      end

      # Step 3: Merge consecutive lists by removing intermediate tags
      # Pattern: </TYPE(N)>MERGE_MARKER\n?<TYPE(M)> -> empty (merge lists)
      def merge_lists_with_markers(content)
        content.
          gsub(%r{</dl(\d*)>#{Regexp.escape(IDGXML_LIST_MERGE_MARKER)}\n?<dl(\d*)>}o, '').
          gsub(%r{</ul(\d*)>#{Regexp.escape(IDGXML_LIST_MERGE_MARKER)}\n?<ul(\d*)>}o, '').
          gsub(%r{</ol(\d*)>#{Regexp.escape(IDGXML_LIST_MERGE_MARKER)}\n?<ol(\d*)>}o, '')
      end

      # Step 4: Merge consecutive top-level lists (no markers, just adjacent tags)
      # Pattern: </li></TYPE>\n?<TYPE><li> -> </li><li> (merge lists at same level)
      def merge_toplevel_lists(content)
        content.
          gsub(%r{</li>\n?</ul>\n?<ul>\n?<li}, '</li><li').
          gsub(%r{</li>\n?</ol>\n?<ol>\n?<li}, '</li><li').
          gsub(%r{</dd>\n?</dl>\n?<dl>\n?<dt}, '</dd><dt')
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
        output = render_list(node, :ul)

        # If in nest context, mark that we need a closing tag (for beginchild/endchild)
        unless @nest_stack.empty?
          @nest_stack.last.needs_close_tag = true
        end

        output
      end

      # Visit ordered list
      def visit_ol(node)
        output = render_list(node, :ol)

        # If in nest context, mark that we need a closing tag (for beginchild/endchild)
        unless @nest_stack.empty?
          @nest_stack.last.needs_close_tag = true
        end

        output
      end

      # Visit definition list
      def visit_dl(node)
        output = render_list(node, :dl)

        # If in nest context, mark that we need a closing tag (for beginchild/endchild)
        unless @nest_stack.empty?
          @nest_stack.last.needs_close_tag = true
        end

        output
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
        lines << escape(node.args.first) if node.args&.first && !node.args.first.empty?

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
        caption = node.args&.first

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
        # Create a temporary paragraph node and parse inline elements
        require 'review/ast/compiler'
        require 'review/lineinput'

        # Use the inline processor to parse inline elements
        temp_node = ReVIEW::AST::ParagraphNode.new(location: nil)
        @ast_compiler ||= ReVIEW::AST::Compiler.for_chapter(@chapter)
        @ast_compiler.inline_processor.parse_inline_elements(caption_text, temp_node)

        # Render the inline elements
        render_children(temp_node)
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
