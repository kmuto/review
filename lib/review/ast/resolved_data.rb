# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/i18n'

module ReVIEW
  module AST
    # ResolvedData - Immutable data structure holding resolved reference information
    #
    # This class contains structured data about resolved references,
    # separating the logical resolution (what is being referenced)
    # from the presentation (how it should be displayed).
    class ResolvedData
      attr_reader :chapter_number, :item_number, :chapter_id, :item_id
      attr_reader :chapter_title, :headline_number, :word_content
      attr_reader :caption_node

      # Get caption text from caption_node
      # @return [String] Caption text, empty string if no caption_node
      def caption_text
        caption_node&.to_text || ''
      end

      # Check if this is a cross-chapter reference
      # @return [Boolean] true if referencing an item in another chapter
      def cross_chapter?
        # If chapter_id is set and different from current context, it's cross-chapter
        !@chapter_id.nil?
      end

      # Check if the reference was successfully resolved
      # @return [Boolean] true if the reference exists and was found
      def exists?
        # If item_number is set, the reference was found
        !@item_number.nil?
      end

      # Check equality with another ResolvedData
      # @param other [Object] Object to compare with
      # @return [Boolean] true if equal
      def ==(other)
        other.instance_of?(self.class) &&
          @chapter_number == other.chapter_number &&
          @item_number == other.item_number &&
          @chapter_id == other.chapter_id &&
          @item_id == other.item_id &&
          @caption_node == other.caption_node &&
          @chapter_title == other.chapter_title &&
          @headline_number == other.headline_number &&
          @word_content == other.word_content
      end

      alias_method :eql?, :==

      # Create a string representation for debugging
      # @return [String] Debug string representation
      def to_s
        parts = ['#<ResolvedData']
        parts << "chapter=#{@chapter_number}" if @chapter_number
        parts << "item=#{@item_number}" if @item_number
        parts << "chapter_id=#{@chapter_id}" if @chapter_id
        parts << "item_id=#{@item_id}"
        parts.join(' ') + '>'
      end

      # Convert resolved data to human-readable text representation
      # This method should be implemented by each subclass
      # @return [String] Text representation
      def to_text
        @item_id || ''
      end

      # Helper methods for text formatting

      def safe_i18n(key, args = nil)
        ReVIEW::I18n.t(key, args)
      rescue StandardError
        key
      end

      def format_reference_number
        if @chapter_number && !@chapter_number.to_s.empty?
          safe_i18n('format_number', [@chapter_number, @item_number])
        else
          safe_i18n('format_number_without_chapter', [@item_number])
        end
      end

      def caption_separator
        separator = safe_i18n('caption_prefix_idgxml')
        if separator == 'caption_prefix_idgxml'
          fallback = safe_i18n('caption_prefix')
          fallback == 'caption_prefix' ? ' ' : fallback
        else
          separator
        end
      end

      def format_captioned_reference(label_key)
        label = safe_i18n(label_key)
        number_text = format_reference_number
        base = "#{label}#{number_text}"
        text = caption_text
        if text.empty?
          base
        else
          "#{base}#{caption_separator}#{text}"
        end
      end

      def chapter_number_text(chapter_num)
        if numeric_string?(chapter_num)
          safe_i18n('chapter', chapter_num.to_i)
        else
          chapter_num.to_s
        end
      end

      def numeric_string?(value)
        value.to_s.match?(/\A-?\d+\z/)
      end

      # Factory methods for common reference types

      # Create ResolvedData for an image reference
      def self.image(chapter_number:, item_number:, item_id:, chapter_id: nil, caption_node: nil)
        Image.new(
          chapter_number: chapter_number,
          item_number: item_number,
          chapter_id: chapter_id,
          item_id: item_id,
          caption_node: caption_node
        )
      end

      # Create ResolvedData for a table reference
      def self.table(chapter_number:, item_number:, item_id:, chapter_id: nil, caption_node: nil)
        Table.new(
          chapter_number: chapter_number,
          item_number: item_number,
          chapter_id: chapter_id,
          item_id: item_id,
          caption_node: caption_node
        )
      end

      # Create ResolvedData for a list reference
      def self.list(chapter_number:, item_number:, item_id:, chapter_id: nil, caption_node: nil)
        List.new(
          chapter_number: chapter_number,
          item_number: item_number,
          chapter_id: chapter_id,
          item_id: item_id,
          caption_node: caption_node
        )
      end

      # Create ResolvedData for an equation reference
      def self.equation(chapter_number:, item_number:, item_id:, caption_node: nil)
        Equation.new(
          chapter_number: chapter_number,
          item_number: item_number,
          item_id: item_id,
          caption_node: caption_node
        )
      end

      # Create ResolvedData for a footnote reference
      def self.footnote(item_number:, item_id:, caption_node: nil)
        Footnote.new(
          item_number: item_number,
          item_id: item_id,
          caption_node: caption_node
        )
      end

      # Create ResolvedData for an endnote reference
      def self.endnote(item_number:, item_id:, caption_node: nil)
        Endnote.new(
          item_number: item_number,
          item_id: item_id,
          caption_node: caption_node
        )
      end

      # Create ResolvedData for a chapter reference
      def self.chapter(chapter_number:, chapter_id:, chapter_title: nil, caption_node: nil)
        Chapter.new(
          chapter_number: chapter_number,
          chapter_id: chapter_id,
          item_id: chapter_id, # For chapter refs, item_id is same as chapter_id
          chapter_title: chapter_title,
          caption_node: caption_node
        )
      end

      # Create ResolvedData for a headline/section reference
      def self.headline(headline_number:, item_id:, chapter_id: nil, caption_node: nil)
        Headline.new(
          item_id: item_id,
          chapter_id: chapter_id,
          headline_number: headline_number, # Array format [1, 2, 3]
          caption_node: caption_node
        )
      end

      # Create ResolvedData for a word reference
      def self.word(word_content:, item_id:, caption_node: nil)
        Word.new(
          item_id: item_id,
          word_content: word_content,
          caption_node: caption_node
        )
      end

      # Create ResolvedData for a column reference
      def self.column(chapter_number:, item_number:, item_id:, chapter_id: nil, caption_node: nil)
        Column.new(
          chapter_number: chapter_number,
          item_number: item_number,
          chapter_id: chapter_id,
          item_id: item_id,
          caption_node: caption_node
        )
      end
    end

    # Concrete subclasses representing each reference type
    class ResolvedData
      class Image < ResolvedData
        def initialize(chapter_number:, item_number:, item_id:, chapter_id: nil, caption_node: nil)
          super()
          @chapter_number = chapter_number
          @item_number = item_number
          @chapter_id = chapter_id
          @item_id = item_id
          @caption_node = caption_node
        end

        def to_text
          format_captioned_reference('image')
        end

        # Double dispatch - delegate to formatter
        def format_with(formatter)
          formatter.format_image_reference(self)
        end
      end
    end

    class ResolvedData
      class Table < ResolvedData
        def initialize(chapter_number:, item_number:, item_id:, chapter_id: nil, caption_node: nil)
          super()
          @chapter_number = chapter_number
          @item_number = item_number
          @chapter_id = chapter_id
          @item_id = item_id
          @caption_node = caption_node
        end

        def to_text
          format_captioned_reference('table')
        end

        # Double dispatch - delegate to formatter
        def format_with(formatter)
          formatter.format_table_reference(self)
        end
      end
    end

    class ResolvedData
      class List < ResolvedData
        def initialize(chapter_number:, item_number:, item_id:, chapter_id: nil, caption_node: nil)
          super()
          @chapter_number = chapter_number
          @item_number = item_number
          @chapter_id = chapter_id
          @item_id = item_id
          @caption_node = caption_node
        end

        def to_text
          format_captioned_reference('list')
        end

        # Double dispatch - delegate to formatter
        def format_with(formatter)
          formatter.format_list_reference(self)
        end
      end
    end

    class ResolvedData
      class Equation < ResolvedData
        def initialize(chapter_number:, item_number:, item_id:, caption_node: nil)
          super()
          @chapter_number = chapter_number
          @item_number = item_number
          @item_id = item_id
          @caption_node = caption_node
        end

        def to_text
          format_captioned_reference('equation')
        end

        # Double dispatch - delegate to formatter
        def format_with(formatter)
          formatter.format_equation_reference(self)
        end
      end
    end

    class ResolvedData
      class Footnote < ResolvedData
        def initialize(item_number:, item_id:, caption_node: nil)
          super()
          @item_number = item_number
          @item_id = item_id
          @caption_node = caption_node
        end

        def to_text
          @item_number.to_s
        end

        # Double dispatch - delegate to formatter
        def format_with(formatter)
          formatter.format_footnote_reference(self)
        end
      end
    end

    class ResolvedData
      class Endnote < ResolvedData
        def initialize(item_number:, item_id:, caption_node: nil)
          super()
          @item_number = item_number
          @item_id = item_id
          @caption_node = caption_node
        end

        def to_text
          @item_number.to_s
        end

        # Double dispatch - delegate to formatter
        def format_with(formatter)
          formatter.format_endnote_reference(self)
        end
      end
    end

    class ResolvedData
      class Chapter < ResolvedData
        def initialize(chapter_number:, chapter_id:, item_id:, chapter_title: nil, caption_node: nil)
          super()
          @chapter_number = chapter_number
          @chapter_id = chapter_id
          @item_id = item_id
          @chapter_title = chapter_title
          @caption_node = caption_node
        end

        def to_text
          if @chapter_number && @chapter_title
            number_text = chapter_number_text(@chapter_number)
            safe_i18n('chapter_quote', [number_text, @chapter_title])
          elsif @chapter_title
            safe_i18n('chapter_quote_without_number', @chapter_title)
          elsif @chapter_number
            chapter_number_text(@chapter_number)
          else
            @item_id || ''
          end
        end

        # Double dispatch - delegate to formatter
        def format_with(formatter)
          formatter.format_chapter_reference(self)
        end
      end
    end

    class ResolvedData
      class Headline < ResolvedData
        def initialize(item_id:, headline_number:, chapter_id: nil, caption_node: nil)
          super()
          @item_id = item_id
          @chapter_id = chapter_id
          @headline_number = headline_number
          @caption_node = caption_node
        end

        def to_text
          caption = caption_text
          if @headline_number && !@headline_number.empty?
            number_text = @headline_number.join('.')
            safe_i18n('hd_quote', [number_text, caption])
          elsif !caption.empty?
            safe_i18n('hd_quote_without_number', caption)
          else
            @item_id || ''
          end
        end

        # Double dispatch - delegate to formatter
        def format_with(formatter)
          formatter.format_headline_reference(self)
        end
      end
    end

    class ResolvedData
      class Word < ResolvedData
        def initialize(item_id:, word_content:, caption_node: nil)
          super()
          @item_id = item_id
          @word_content = word_content
          @caption_node = caption_node
        end

        def to_text
          @word_content
        end

        # Double dispatch - delegate to formatter
        def format_with(formatter)
          formatter.format_word_reference(self)
        end
      end
    end

    class ResolvedData
      class Column < ResolvedData
        def initialize(chapter_number:, item_number:, item_id:, chapter_id: nil, caption_node: nil)
          super()
          @chapter_number = chapter_number
          @item_number = item_number
          @chapter_id = chapter_id
          @item_id = item_id
          @caption_node = caption_node
        end

        def to_text
          text = caption_text
          if text.empty?
            @item_id || ''
          else
            safe_i18n('column', text)
          end
        end

        # Double dispatch - delegate to formatter
        def format_with(formatter)
          formatter.format_column_reference(self)
        end
      end
    end
  end
end
