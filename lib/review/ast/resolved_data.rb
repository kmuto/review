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
      attr_reader :chapter_number, :item_number, :chapter_id, :item_id
      attr_reader :chapter_title, :headline_number, :headline_caption, :word_content
      attr_reader :caption

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
          @caption == other.caption &&
          @chapter_title == other.chapter_title &&
          @headline_number == other.headline_number &&
          @headline_caption == other.headline_caption &&
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

      # Factory methods for common reference types

      # Create ResolvedData for an image reference
      def self.image(chapter_number:, item_number:, item_id:, chapter_id: nil, caption: nil)
        Image.new(
          chapter_number: chapter_number,
          item_number: item_number,
          chapter_id: chapter_id,
          item_id: item_id,
          caption: caption
        )
      end

      # Create ResolvedData for a table reference
      def self.table(chapter_number:, item_number:, item_id:, chapter_id: nil, caption: nil)
        Table.new(
          chapter_number: chapter_number,
          item_number: item_number,
          chapter_id: chapter_id,
          item_id: item_id,
          caption: caption
        )
      end

      # Create ResolvedData for a list reference
      def self.list(chapter_number:, item_number:, item_id:, chapter_id: nil, caption: nil)
        List.new(
          chapter_number: chapter_number,
          item_number: item_number,
          chapter_id: chapter_id,
          item_id: item_id,
          caption: caption
        )
      end

      # Create ResolvedData for an equation reference
      def self.equation(chapter_number:, item_number:, item_id:, caption: nil)
        Equation.new(
          chapter_number: chapter_number,
          item_number: item_number,
          item_id: item_id,
          caption: caption
        )
      end

      # Create ResolvedData for a footnote reference
      def self.footnote(item_number:, item_id:, caption: nil)
        Footnote.new(
          item_number: item_number,
          item_id: item_id,
          caption: caption
        )
      end

      # Create ResolvedData for an endnote reference
      def self.endnote(item_number:, item_id:, caption: nil)
        Endnote.new(
          item_number: item_number,
          item_id: item_id,
          caption: caption
        )
      end

      # Create ResolvedData for a chapter reference
      def self.chapter(chapter_number:, chapter_id:, chapter_title: nil, caption: nil)
        Chapter.new(
          chapter_number: chapter_number,
          chapter_id: chapter_id,
          item_id: chapter_id, # For chapter refs, item_id is same as chapter_id
          chapter_title: chapter_title,
          caption: caption
        )
      end

      # Create ResolvedData for a headline/section reference
      def self.headline(headline_number:, headline_caption:, item_id:, chapter_id: nil, caption: nil)
        Headline.new(
          item_id: item_id,
          chapter_id: chapter_id,
          headline_number: headline_number, # Array format [1, 2, 3]
          headline_caption: headline_caption,
          caption: caption || headline_caption
        )
      end

      # Create ResolvedData for a word reference
      def self.word(word_content:, item_id:, caption: nil)
        Word.new(
          item_id: item_id,
          word_content: word_content,
          caption: caption
        )
      end

      # Create ResolvedData for a column reference
      def self.column(chapter_number:, item_number:, item_id:, chapter_id: nil, caption: nil)
        Column.new(
          chapter_number: chapter_number,
          item_number: item_number,
          chapter_id: chapter_id,
          item_id: item_id,
          caption: caption
        )
      end
    end

    # Concrete subclasses representing each reference type
    class ResolvedData
      class Image < ResolvedData
        def initialize(chapter_number:, item_number:, item_id:, chapter_id: nil, caption: nil)
          super()
          @chapter_number = chapter_number
          @item_number = item_number
          @chapter_id = chapter_id
          @item_id = item_id
          @caption = caption
        end
      end
    end

    class ResolvedData
      class Table < ResolvedData
        def initialize(chapter_number:, item_number:, item_id:, chapter_id: nil, caption: nil)
          super()
          @chapter_number = chapter_number
          @item_number = item_number
          @chapter_id = chapter_id
          @item_id = item_id
          @caption = caption
        end
      end
    end

    class ResolvedData
      class List < ResolvedData
        def initialize(chapter_number:, item_number:, item_id:, chapter_id: nil, caption: nil)
          super()
          @chapter_number = chapter_number
          @item_number = item_number
          @chapter_id = chapter_id
          @item_id = item_id
          @caption = caption
        end
      end
    end

    class ResolvedData
      class Equation < ResolvedData
        def initialize(chapter_number:, item_number:, item_id:, caption: nil)
          super()
          @chapter_number = chapter_number
          @item_number = item_number
          @item_id = item_id
          @caption = caption
        end
      end
    end

    class ResolvedData
      class Footnote < ResolvedData
        def initialize(item_number:, item_id:, caption: nil)
          super()
          @item_number = item_number
          @item_id = item_id
          @caption = caption
        end
      end
    end

    class ResolvedData
      class Endnote < ResolvedData
        def initialize(item_number:, item_id:, caption: nil)
          super()
          @item_number = item_number
          @item_id = item_id
          @caption = caption
        end
      end
    end

    class ResolvedData
      class Chapter < ResolvedData
        def initialize(chapter_number:, chapter_id:, item_id:, chapter_title: nil, caption: nil)
          super()
          @chapter_number = chapter_number
          @chapter_id = chapter_id
          @item_id = item_id
          @chapter_title = chapter_title
          @caption = caption
        end
      end
    end

    class ResolvedData
      class Headline < ResolvedData
        def initialize(item_id:, headline_number:, headline_caption:, chapter_id: nil, caption: nil)
          super()
          @item_id = item_id
          @chapter_id = chapter_id
          @headline_number = headline_number
          @headline_caption = headline_caption
          @caption = caption
        end
      end
    end

    class ResolvedData
      class Word < ResolvedData
        def initialize(item_id:, word_content:, caption: nil)
          super()
          @item_id = item_id
          @word_content = word_content
          @caption = caption
        end
      end
    end

    class ResolvedData
      class Column < ResolvedData
        def initialize(chapter_number:, item_number:, item_id:, chapter_id: nil, caption: nil)
          super()
          @chapter_number = chapter_number
          @item_number = item_number
          @chapter_id = chapter_id
          @item_id = item_id
          @caption = caption
        end
      end
    end
  end
end
