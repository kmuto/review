# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/i18n'
require 'review/htmlutils'
require 'review/latexutils'

module ReVIEW
  module AST
    # TextFormatter - Centralized text formatting and I18n service
    #
    # This class consolidates all text formatting and internationalization logic
    # that was previously scattered across Renderer, InlineElementHandler, Formatter,
    # and ResolvedData classes.
    #
    # Design principles:
    # - Single responsibility: All I18n and text generation in one place
    # - Format-agnostic core with format-specific decorations
    # - Reusable from Renderer, InlineElementHandler, and ResolvedData
    class TextFormatter
      include ReVIEW::HTMLUtils
      include ReVIEW::LaTeXUtils

      attr_reader :format_type, :config, :chapter

      # Initialize formatter
      # @param format_type [Symbol] Output format (:html, :latex, :idgxml, :top)
      # @param config [Hash] Configuration hash
      # @param chapter [Chapter, nil] Current chapter (optional, used for HTML reference links)
      def initialize(format_type:, config:, chapter: nil)
        @format_type = format_type
        @config = config
        @chapter = chapter

        # Initialize LaTeX character escaping if format is LaTeX
        initialize_metachars(config['texcommand']) if format_type == :latex
      end

      # Format a numbered item's caption (e.g., "図1.1 キャプション")
      # @param label_key [String] I18n key for the label (e.g., 'image', 'table', 'list')
      # @param chapter_number [String, nil] Chapter number (e.g., "第1章")
      # @param item_number [Integer] Item number within chapter
      # @param caption_text [String, nil] Caption text
      # @return [String] Formatted caption
      def format_caption(label_key, chapter_number, item_number, caption_text = nil)
        label = I18n.t(label_key)

        # Different formats use different number formats and separators
        case format_type
        when :latex, :html
          # HTML/LaTeX use format_number_header (with colon) + caption_prefix
          number_text = format_number_header(chapter_number, item_number)
          separator = I18n.t('caption_prefix')
        when :idgxml
          # IDGXML uses format_number (without colon) + caption_prefix_idgxml
          number_text = format_number(chapter_number, item_number)
          separator = I18n.t('caption_prefix_idgxml')
        else
          # For other formats (text, etc.), use generic logic
          number_text = format_number(chapter_number, item_number)
          separator = caption_separator
        end

        base = "#{label}#{number_text}"

        return base if caption_text.nil? || caption_text.empty?

        "#{base}#{separator}#{caption_text}"
      end

      # Format just the number part (e.g., "1.1" or "1")
      # @param chapter_number [String, nil] Chapter number
      # @param item_number [Integer] Item number
      # @return [String] Formatted number
      def format_number(chapter_number, item_number)
        if chapter_number && !chapter_number.to_s.empty?
          I18n.t('format_number', [chapter_number, item_number])
        else
          I18n.t('format_number_without_chapter', [item_number])
        end
      end

      # Format number for caption header (HTML/LaTeX style)
      # Used in block elements (//image, //table, //list, //equation) caption headers
      # @param chapter_number [String, nil] Chapter number
      # @param item_number [Integer] Item number
      # @return [String] Formatted number for header
      def format_number_header(chapter_number, item_number)
        if chapter_number && !chapter_number.to_s.empty?
          I18n.t('format_number_header', [chapter_number, item_number])
        else
          I18n.t('format_number_header_without_chapter', [item_number])
        end
      end

      # Format a reference to an item
      # @param type [Symbol] Reference type (:image, :table, :list, :equation, etc.)
      # @param data [ResolvedData] Resolved reference data
      # @return [String] Formatted reference
      def format_reference(type, data)
        case type
        when :image
          format_image_reference(data)
        when :table
          format_table_reference(data)
        when :list
          format_list_reference(data)
        when :equation
          format_equation_reference(data)
        when :footnote
          format_footnote_reference(data)
        when :endnote
          format_endnote_reference(data)
        when :chapter
          format_chapter_reference(data)
        when :headline
          format_headline_reference(data)
        when :column
          format_column_reference(data)
        when :bibpaper
          format_bibpaper_reference(data)
        when :word
          format_word_reference(data)
        else
          raise ArgumentError, "Unknown reference type: #{type}"
        end
      end

      # Format chapter number with I18n (e.g., "第1章", "Appendix A")
      # @param chapter_number [String, Integer] Chapter number
      # @return [String] Formatted chapter number
      def format_chapter_number(chapter_number)
        return chapter_number.to_s if chapter_number.to_s.empty?

        # Numeric chapter (e.g., "1", "2")
        if numeric_string?(chapter_number)
          I18n.t('chapter', chapter_number.to_i)
        # Single uppercase letter (appendix, e.g., "A", "B")
        elsif chapter_number.to_s.match?(/\A[A-Z]\z/)
          I18n.t('appendix', chapter_number.to_s)
        # Roman numerals (part, e.g., "I", "II", "III")
        elsif chapter_number.to_s.match?(/\A[IVX]+\z/)
          I18n.t('part', chapter_number.to_s)
        else
          # For other formats, return as-is
          chapter_number.to_s
        end
      end

      # Format footnote reference mark
      # @param number [Integer] Footnote number
      # @return [String] Formatted footnote mark
      def format_footnote_mark(number)
        I18n.t('html_footnote_refmark', number)
      end

      # Format endnote reference mark
      # @param number [Integer] Endnote number
      # @return [String] Formatted endnote mark
      def format_endnote_mark(number)
        I18n.t('html_endnote_refmark', number)
      end

      # Format footnote text mark (used in footnote body)
      # @param number [Integer] Footnote number
      # @return [String] Formatted footnote text mark
      def format_footnote_textmark(number)
        I18n.t('html_footnote_textmark', number)
      end

      # Format endnote text mark (used in endnote body)
      # @param number [Integer] Endnote number
      # @return [String] Formatted endnote text mark
      def format_endnote_textmark(number)
        I18n.t('html_endnote_textmark', number)
      end

      # Format footnote back mark (back link)
      # @return [String] Formatted footnote back mark
      def format_footnote_backmark
        I18n.t('html_footnote_backmark')
      end

      # Format part short label (e.g., "第I部")
      # @param chapter [Chapter] Chapter object
      # @return [String] Formatted part short label
      def format_part_short(chapter)
        I18n.t('part_short', chapter.number)
      end

      # Format numberless image label
      # @return [String] Numberless image label
      def format_numberless_image
        I18n.t('numberless_image')
      end

      # Format caption prefix
      # @return [String] Caption prefix string
      def format_caption_prefix
        prefix = I18n.t('caption_prefix')
        prefix == 'caption_prefix' ? ' ' : prefix
      end

      # Format column reference from ResolvedData
      # Used by ResolvedData#to_text for :text format
      # @param data [ResolvedData] Resolved column reference data
      # @return [String] Formatted column reference
      def format_column_reference(data)
        # caption_text is always plain text from caption_node.to_inline_text
        I18n.t('column', data.caption_text)
      end

      # Format column label with I18n
      # Takes already-rendered caption (in target format)
      # Used by InlineElementHandlers for format-specific rendering
      # @param caption [String] Already rendered caption
      # @return [String] Formatted column label
      def format_column_label(caption)
        I18n.t('column', caption)
      end

      # Format label marker for labelref/ref inline elements
      # @param idref [String] Reference ID
      # @return [String] Formatted label marker
      def format_label_marker(idref)
        I18n.t('label_marker') + escape_text(idref)
      end

      # Format headline quote
      # @param full_number [String, nil] Full section number (e.g., "1.2.3")
      # @param caption_text [String] Caption text (already rendered in target format)
      # @return [String] Formatted headline quote
      def format_headline_quote(full_number, caption_text)
        if full_number
          I18n.t('hd_quote', [full_number, caption_text])
        else
          I18n.t('hd_quote_without_number', caption_text)
        end
      end

      # Format image quote (IDGXML specific)
      # @param caption_text [String] Caption text
      # @return [String] Formatted image quote
      def format_image_quote(caption_text)
        I18n.t('image_quote', caption_text)
      end

      private

      # Format numbered reference (image, table, list) using common logic
      # @param label_key [String] I18n key for the label (e.g., 'image', 'table', 'list')
      # @param data [ResolvedData] Resolved reference data
      # @param html_css_class [String] CSS class for HTML output (e.g., 'imgref', 'tableref')
      # @return [String] Formatted reference
      def format_numbered_reference(label_key, data, html_css_class)
        case format_type
        when :html
          # For HTML references, use format_number (no colon) instead of format_caption
          label = I18n.t(label_key)
          number_text = "#{label}#{format_number(data.chapter_number, data.item_number)}"
          format_html_reference(number_text, data, html_css_class)
        when :latex
          format_latex_reference(data)
        when :text
          # For :text format, include caption if available
          format_caption(label_key, data.chapter_number, data.item_number, data.caption_text)
        else # For :idgxml and others
          format_caption(label_key, data.chapter_number, data.item_number)
        end
      end

      # Format image reference
      def format_image_reference(data)
        format_numbered_reference('image', data, 'imgref')
      end

      # Format table reference
      def format_table_reference(data)
        format_numbered_reference('table', data, 'tableref')
      end

      # Format list reference
      def format_list_reference(data)
        format_numbered_reference('list', data, 'listref')
      end

      # Format equation reference
      def format_equation_reference(data)
        case format_type
        when :html
          label = I18n.t('equation')
          number_text = "#{label}#{format_number(data.chapter_number, data.item_number)}"
          format_html_reference(number_text, data, 'eqref')
        when :latex
          # Equation uses direct \ref instead of format_latex_reference
          "\\ref{#{data.item_id}}"
        when :text
          format_caption('equation', data.chapter_number, data.item_number, data.caption_text)
        else # For :idgxml and others
          format_caption('equation', data.chapter_number, data.item_number)
        end
      end

      # Format footnote reference
      def format_footnote_reference(data)
        case format_type
        when :latex
          "\\footnotemark[#{data.item_number}]"
        when :top
          number = data.item_number || data.item_id
          "【注#{number}】"
        else
          # For :html, :idgxml, :text and others
          data.item_number.to_s
        end
      end

      # Format endnote reference
      def format_endnote_reference(data)
        case format_type
        when :top
          number = data.item_number || data.item_id
          "【後注#{number}】"
        else
          # For :html, :idgxml, :text, :latex and others
          data.item_number.to_s
        end
      end

      # Format chapter reference
      def format_chapter_reference(data)
        chapter_number = data.chapter_number
        chapter_title = data.chapter_title

        if chapter_title && chapter_number
          number_text = format_chapter_number(chapter_number)
          escape_text(I18n.t('chapter_quote', [number_text, chapter_title]))
        elsif chapter_title
          escape_text(I18n.t('chapter_quote_without_number', chapter_title))
        elsif chapter_number
          escape_text(format_chapter_number(chapter_number))
        else
          escape_text(data.item_id || '')
        end
      end

      # Format headline reference
      def format_headline_reference(data)
        caption = data.caption_text
        headline_numbers = Array(data.headline_number).compact

        if !headline_numbers.empty?
          # Build full number with chapter number if available
          number_str = if data.chapter_number && !data.chapter_number.to_s.empty?
                         ([data.chapter_number] + headline_numbers).join('.')
                       else
                         headline_numbers.join('.')
                       end
          escape_text(I18n.t('hd_quote', [number_str, caption]))
        elsif !caption.empty?
          escape_text(I18n.t('hd_quote_without_number', caption))
        else
          escape_text(data.item_id || '')
        end
      end

      # Format bibpaper reference
      def format_bibpaper_reference(data)
        case format_type
        when :html
          %Q(<span class="bibref">[#{data.item_number}]</span>)
        when :latex
          "\\reviewbibref{[#{data.item_number}]}{bib:#{data.item_id}}"
        else
          # For :idgxml, :text and others
          "[#{data.item_number}]"
        end
      end

      # Format word reference
      def format_word_reference(data)
        escape_text(data.word_content)
      end

      # Format HTML reference with link support
      # Matches the original HTML InlineElementHandler behavior: always use ./chapter_id#id format
      def format_html_reference(text, data, css_class)
        return %Q(<span class="#{css_class}">#{text}</span>) unless config['chapterlink']

        # Use chapter_id from data, or fall back to current chapter's id
        chapter_id = data.chapter_id || @chapter&.id
        extname = ".#{config['htmlext'] || 'html'}"
        %Q(<span class="#{css_class}"><a href="./#{chapter_id}#{extname}##{normalize_id(data.item_id)}">#{text}</a></span>)
      end

      # Format LaTeX reference
      def format_latex_reference(data)
        if data.cross_chapter?
          "\\ref{#{data.chapter_id}:#{data.item_id}}"
        else
          "\\ref{#{data.item_id}}"
        end
      end

      # Get caption separator
      def caption_separator
        separator = I18n.t('caption_prefix_idgxml')
        if separator == 'caption_prefix_idgxml'
          # Fallback to regular caption prefix
          fallback = I18n.t('caption_prefix')
          fallback == 'caption_prefix' ? ' ' : fallback
        else
          separator
        end
      end

      # Check if string is numeric
      def numeric_string?(value)
        value.to_s.match?(/\A-?\d+\z/)
      end

      # Normalize ID for HTML/XML attributes
      def normalize_id(id)
        id.to_s.gsub(/[^a-zA-Z0-9_-]/, '_')
      end

      # Escape text based on format type
      def escape_text(text)
        case format_type
        when :html, :idgxml
          escape_html(text.to_s)
        when :latex
          escape(text.to_s)
        else # For :text, :top and others
          text.to_s
        end
      end
    end
  end
end
