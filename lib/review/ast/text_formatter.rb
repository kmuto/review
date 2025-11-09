# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/i18n'

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
      attr_reader :config, :chapter

      # Initialize formatter
      # @param config [Hash] Configuration hash
      # @param chapter [Chapter, nil] Current chapter (optional, used for HTML reference links)
      def initialize(config:, chapter: nil)
        @config = config
        @chapter = chapter
      end

      # Format a numbered item's caption for HTML/LaTeX (e.g., "図1.1: キャプション")
      # Uses format_number_header (with colon) + caption_prefix
      # @param label_key [String] I18n key for the label (e.g., 'image', 'table', 'list')
      # @param chapter_number [String, nil] Chapter number (e.g., "第1章")
      # @param item_number [Integer] Item number within chapter
      # @param caption_text [String, nil] Caption text
      # @return [String] Formatted caption
      def format_caption(label_key, chapter_number, item_number, caption_text = nil)
        label = I18n.t(label_key)
        number_text = format_number_header(chapter_number, item_number)
        separator = I18n.t('caption_prefix')

        base = "#{label}#{number_text}"
        return base if caption_text.nil? || caption_text.empty?

        "#{base}#{separator}#{caption_text}"
      end

      # Format a numbered item's caption for IDGXML/TOP/TEXT (e.g., "図1.1 キャプション")
      # Uses format_number (without colon) + caption_separator
      # @param label_key [String] I18n key for the label (e.g., 'image', 'table', 'list')
      # @param chapter_number [String, nil] Chapter number (e.g., "第1章")
      # @param item_number [Integer] Item number within chapter
      # @param caption_text [String, nil] Caption text
      # @return [String] Formatted caption
      def format_caption_plain(label_key, chapter_number, item_number, caption_text = nil)
        label = I18n.t(label_key)
        number_text = format_number(chapter_number, item_number)
        separator = caption_separator

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

      # Format a reference as plain text (without format-specific decorations)
      # This method returns pure text suitable for wrapping with HTML tags, LaTeX commands, etc.
      # @param type [Symbol] Reference type (:image, :table, :list, :equation, etc.)
      # @param data [ResolvedData] Resolved reference data
      # @return [String] Plain text reference (e.g., "図1.1", "表2.3")
      def format_reference_text(type, data)
        case type
        when :image
          format_numbered_reference_text('image', data)
        when :table
          format_numbered_reference_text('table', data)
        when :list
          format_numbered_reference_text('list', data)
        when :equation
          format_numbered_reference_text('equation', data)
        when :footnote
          format_footnote_reference_text(data)
        when :endnote
          format_endnote_reference_text(data)
        when :chapter
          format_chapter_reference_text(data)
        when :headline
          format_headline_reference_text(data)
        when :column
          format_column_reference_text(data)
        when :bibpaper
          format_bibpaper_reference_text(data)
        when :word
          data.word_content.to_s
        else
          raise ArgumentError, "Unknown reference type: #{type}"
        end
      end

      # Format a reference to an item (with format-specific decorations)
      # Used by LaTeX, IDGXML, TOP, and TEXT renderers
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

      # Format chapter number with I18n (long form, e.g., "第1章", "Appendix A", "Part I")
      # Used for @<chap>, @<chapref>, @<title> references
      # @param raw_number [Integer, nil] Raw chapter number from chapter.number
      # @param chapter_type [Symbol, nil] Chapter type (:chapter, :appendix, :part, :predef)
      # @return [String] Formatted chapter number
      def format_chapter_number_full(raw_number, chapter_type)
        return '' unless raw_number

        case chapter_type
        when :chapter
          I18n.t('chapter', raw_number)
        when :appendix
          I18n.t('appendix', raw_number)
        when :part
          I18n.t('part', raw_number)
        else # :predef and others
          raw_number.to_s
        end
      end

      # Format chapter number without heading (short form, e.g., "1", "A", "I")
      # Used for figure/table/list references where format is "図2.1" not "図第2章.1"
      # Matches Chapter#format_number(false) behavior
      # @param raw_number [Integer, nil] Raw chapter number from chapter.number
      # @param chapter_type [Symbol, nil] Chapter type (:chapter, :appendix, :part, :predef)
      # @return [String] Short form chapter number
      def format_chapter_number_short(raw_number, chapter_type)
        return '' unless raw_number

        case chapter_type
        when :chapter, :part, :predef
          # For chapters, parts, and predef: just return the number as-is
          raw_number.to_s
        when :appendix
          # For appendix: extract format from 'appendix' I18n key and create 'appendix_without_heading'
          # This replicates the logic from Chapter#format_number(false)
          i18n_appendix = I18n.get('appendix')
          fmt = i18n_appendix.scan(/%\w{1,3}/).first || '%s'
          I18n.update('appendix_without_heading' => fmt)
          I18n.t('appendix_without_heading', raw_number)
        else # rubocop:disable Lint/DuplicateBranch
          raw_number.to_s
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
        I18n.t('label_marker') + idref.to_s
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
      # @param html_css_class [String] CSS class for HTML output (unused, kept for compatibility)
      # @return [String] Formatted reference without caption (e.g., "図1.1")
      def format_numbered_reference(label_key, data, _html_css_class)
        # Use short form of chapter number for figure/table/list references
        chapter_number_short = format_chapter_number_short(data.chapter_number, data.chapter_type)

        # Format without caption - caption is handled separately by renderers or in to_text
        format_caption_plain(label_key, chapter_number_short, data.item_number, nil)
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
      # @param data [ResolvedData] Resolved reference data
      # @return [String] Formatted reference without caption (e.g., "式3.1")
      def format_equation_reference(data)
        # Use short form of chapter number for equation references
        chapter_number_short = format_chapter_number_short(data.chapter_number, data.chapter_type)

        # Return reference without caption text
        format_caption_plain('equation', chapter_number_short, data.item_number)
      end

      # Format footnote reference
      def format_footnote_reference(data)
        # For all formats - return plain number without markup
        data.item_number.to_s
      end

      # Format endnote reference
      def format_endnote_reference(data)
        # For all formats - return plain number without markup
        data.item_number.to_s
      end

      # Format chapter reference
      def format_chapter_reference(data)
        chapter_title = data.chapter_title

        # Use full form of chapter number for chapter references
        chapter_number_full = format_chapter_number_full(data.chapter_number, data.chapter_type)

        if chapter_title && !chapter_number_full.empty?
          I18n.t('chapter_quote', [chapter_number_full, chapter_title])
        elsif chapter_title
          I18n.t('chapter_quote_without_number', chapter_title)
        elsif !chapter_number_full.empty?
          chapter_number_full
        else
          data.item_id || ''
        end
      end

      # Format headline reference
      def format_headline_reference(data)
        caption = data.caption_text
        headline_numbers = Array(data.headline_number).compact

        if !headline_numbers.empty?
          # Use short form of chapter number for headline references
          chapter_number_short = format_chapter_number_short(data.chapter_number, data.chapter_type)

          # Build full number with chapter number if available
          number_str = if chapter_number_short.empty?
                         headline_numbers.join('.')
                       else
                         ([chapter_number_short] + headline_numbers).join('.')
                       end
          I18n.t('hd_quote', [number_str, caption])
        elsif !caption.empty?
          I18n.t('hd_quote_without_number', caption)
        else
          data.item_id || ''
        end
      end

      # Format bibpaper reference
      def format_bibpaper_reference(data)
        # For all formats - return plain reference without markup
        "[#{data.item_number}]"
      end

      # Format word reference
      def format_word_reference(data)
        data.word_content.to_s
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

      # Format numbered reference as plain text (image, table, list, equation)
      # @param label_key [String] I18n key for the label (e.g., 'image', 'table', 'list')
      # @param data [ResolvedData] Resolved reference data
      # @return [String] Plain text reference (e.g., "図1.1", "表2.3")
      def format_numbered_reference_text(label_key, data)
        # Use short form of chapter number for figure/table/list references
        chapter_number_short = format_chapter_number_short(data.chapter_number, data.chapter_type)
        label = I18n.t(label_key)
        number_text = format_number(chapter_number_short, data.item_number)
        "#{label}#{number_text}"
      end

      # Format footnote reference as plain text
      # @param data [ResolvedData] Resolved reference data
      # @return [String] Plain text reference
      def format_footnote_reference_text(data)
        data.item_number.to_s
      end

      # Format endnote reference as plain text
      # @param data [ResolvedData] Resolved reference data
      # @return [String] Plain text reference
      def format_endnote_reference_text(data)
        data.item_number.to_s
      end

      # Format chapter reference as plain text
      # @param data [ResolvedData] Resolved reference data
      # @return [String] Plain text reference
      def format_chapter_reference_text(data)
        chapter_title = data.chapter_title

        # Use full form of chapter number for chapter references
        chapter_number_full = format_chapter_number_full(data.chapter_number, data.chapter_type)

        if chapter_title && !chapter_number_full.empty?
          I18n.t('chapter_quote', [chapter_number_full, chapter_title])
        elsif chapter_title
          I18n.t('chapter_quote_without_number', chapter_title)
        elsif !chapter_number_full.empty?
          chapter_number_full
        else
          data.item_id || ''
        end
      end

      # Format headline reference as plain text
      # @param data [ResolvedData] Resolved reference data
      # @return [String] Plain text reference
      def format_headline_reference_text(data)
        caption = data.caption_text
        headline_numbers = Array(data.headline_number).compact

        if !headline_numbers.empty?
          # Use short form of chapter number for headline references
          chapter_number_short = format_chapter_number_short(data.chapter_number, data.chapter_type)

          # Build full number with chapter number if available
          number_str = if chapter_number_short.empty?
                         headline_numbers.join('.')
                       else
                         ([chapter_number_short] + headline_numbers).join('.')
                       end
          I18n.t('hd_quote', [number_str, caption])
        elsif !caption.empty?
          I18n.t('hd_quote_without_number', caption)
        else
          data.item_id || ''
        end
      end

      # Format column reference as plain text
      # @param data [ResolvedData] Resolved reference data
      # @return [String] Plain text reference
      def format_column_reference_text(data)
        I18n.t('column', data.caption_text)
      end

      # Format bibpaper reference as plain text
      # @param data [ResolvedData] Resolved reference data
      # @return [String] Plain text reference
      def format_bibpaper_reference_text(data)
        "[#{data.item_number}]"
      end
    end
  end
end
