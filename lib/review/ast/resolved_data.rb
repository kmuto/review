# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

module ReVIEW
  module AST
    # ResolvedData - Immutable data structure holding resolved reference information
    #
    # This class contains structured data about resolved references,
    # separating the logical resolution (what is being referenced)
    # from the presentation (how it should be displayed).
    class ResolvedData
      attr_reader :type, :chapter_number, :item_number, :chapter_id, :item_id
      attr_reader :chapter_title, :headline_number, :headline_caption, :word_content
      attr_reader :caption

      # Initialize ResolvedData with reference information
      #
      # @param type [Symbol, String] Type of reference (:image, :table, :list, :equation, etc.)
      # @param chapter_number [String, nil] Chapter number (e.g., "1", "2.3")
      # @param item_number [Integer, String, nil] Item number within the chapter
      # @param chapter_id [String, nil] Chapter identifier
      # @param item_id [String] Item identifier within the chapter
      # @param chapter_title [String, nil] Chapter title (for chapter references)
      # @param headline_number [Array, nil] Headline number array (for headline references)
      # @param headline_caption [String, nil] Headline caption (for headline references)
      # @param word_content [String, nil] Word content (for word references)
      def initialize(type:, # rubocop:disable Metrics/ParameterLists
                     item_id:,
                     chapter_number: nil,
                     item_number: nil,
                     chapter_id: nil,
                     chapter_title: nil,
                     headline_number: nil,
                     headline_caption: nil,
                     word_content: nil,
                     caption: nil)
        @type = type.to_sym
        @chapter_number = chapter_number
        @item_number = item_number
        @chapter_id = chapter_id
        @item_id = item_id
        @chapter_title = chapter_title
        @headline_number = headline_number
        @headline_caption = headline_caption
        @word_content = word_content
        @caption = caption
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

      # Create a string representation for debugging
      # @return [String] Debug string representation
      def to_s
        parts = ['#<ResolvedData']
        parts << "type=#{@type}"
        parts << "chapter=#{@chapter_number}" if @chapter_number
        parts << "item=#{@item_number}" if @item_number
        parts << "chapter_id=#{@chapter_id}" if @chapter_id
        parts << "item_id=#{@item_id}"
        parts.join(' ') + '>'
      end

      # Check equality with another ResolvedData
      # @param other [Object] Object to compare with
      # @return [Boolean] true if equal
      def ==(other)
        other.is_a?(ResolvedData) &&
          @type == other.type &&
          @chapter_number == other.chapter_number &&
          @item_number == other.item_number &&
          @chapter_id == other.chapter_id &&
          @item_id == other.item_id &&
          @caption == other.caption
      end

      alias_method :eql?, :==

      # Generate hash code for use as hash key
      # @return [Integer] Hash code
      def hash
        [@type, @chapter_number, @item_number, @chapter_id, @item_id, @caption].hash
      end

      # Factory methods for common reference types

      # Create ResolvedData for an image reference
      def self.image(chapter_number:, item_number:, item_id:, chapter_id: nil, caption: nil)
        new(
          type: :image,
          chapter_number: chapter_number,
          item_number: item_number,
          chapter_id: chapter_id,
          item_id: item_id,
          caption: caption
        )
      end

      # Create ResolvedData for a table reference
      def self.table(chapter_number:, item_number:, item_id:, chapter_id: nil, caption: nil)
        new(
          type: :table,
          chapter_number: chapter_number,
          item_number: item_number,
          chapter_id: chapter_id,
          item_id: item_id,
          caption: caption
        )
      end

      # Create ResolvedData for a list reference
      def self.list(chapter_number:, item_number:, item_id:, chapter_id: nil, caption: nil)
        new(
          type: :list,
          chapter_number: chapter_number,
          item_number: item_number,
          chapter_id: chapter_id,
          item_id: item_id,
          caption: caption
        )
      end

      # Create ResolvedData for an equation reference
      def self.equation(chapter_number:, item_number:, item_id:, caption: nil)
        new(
          type: :equation,
          chapter_number: chapter_number,
          item_number: item_number,
          item_id: item_id,
          caption: caption
        )
      end

      # Create ResolvedData for a footnote reference
      def self.footnote(item_number:, item_id:, caption: nil)
        new(
          type: :footnote,
          item_number: item_number,
          item_id: item_id,
          caption: caption
        )
      end

      # Create ResolvedData for an endnote reference
      def self.endnote(item_number:, item_id:, caption: nil)
        new(
          type: :endnote,
          item_number: item_number,
          item_id: item_id,
          caption: caption
        )
      end

      # Create ResolvedData for a chapter reference
      def self.chapter(chapter_number:, chapter_id:, chapter_title: nil, caption: nil)
        new(
          type: :chapter,
          chapter_number: chapter_number,
          chapter_id: chapter_id,
          item_id: chapter_id, # For chapter refs, item_id is same as chapter_id
          chapter_title: chapter_title,
          caption: caption
        )
      end

      # Create ResolvedData for a headline/section reference
      def self.headline(headline_number:, headline_caption:, item_id:, chapter_id: nil, caption: nil)
        new(
          type: :headline,
          item_id: item_id,
          chapter_id: chapter_id,
          headline_number: headline_number, # Array format [1, 2, 3]
          headline_caption: headline_caption,
          caption: caption || headline_caption
        )
      end

      # Create ResolvedData for a word reference
      def self.word(word_content:, item_id:, caption: nil)
        new(
          type: :word,
          item_id: item_id,
          word_content: word_content,
          caption: caption
        )
      end
    end
  end
end
