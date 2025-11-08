# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require_relative 'text_formatter'

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
        caption_node&.to_inline_text || ''
      end

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

      def to_s
        parts = ['#<ResolvedData']
        parts << "chapter=#{@chapter_number}" if @chapter_number
        parts << "item=#{@item_number}" if @item_number
        parts << "chapter_id=#{@chapter_id}" if @chapter_id
        parts << "item_id=#{@item_id}"
        parts.join(' ') + '>'
      end

      # Serialize to hash
      # @param options [JSONSerializer::Options, nil] Serialization options
      # @return [Hash] Serialized hash representation
      def serialize_to_hash(options = nil)
        options ||= ReVIEW::AST::JSONSerializer::Options.new
        hash = { type: self.class.name.split('::').last }
        serialize_properties(hash, options)
        hash
      end

      # Serialize properties - to be overridden by subclasses
      # @param hash [Hash] Hash to populate with properties
      # @param options [JSONSerializer::Options] Serialization options
      # @return [Hash] Populated hash
      def serialize_properties(hash, options)
        hash[:chapter_number] = @chapter_number if @chapter_number
        hash[:item_number] = @item_number if @item_number
        hash[:chapter_id] = @chapter_id if @chapter_id
        hash[:item_id] = @item_id if @item_id
        hash[:chapter_title] = @chapter_title if @chapter_title
        hash[:headline_number] = @headline_number if @headline_number
        hash[:word_content] = @word_content if @word_content
        hash[:caption_node] = @caption_node.serialize_to_hash(options) if @caption_node
        hash
      end

      # @param hash [Hash] Hash to deserialize from
      # @return [ResolvedData] Deserialized ResolvedData instance
      def self.deserialize_from_hash(hash)
        return nil unless hash

        type = hash['type']
        return nil unless type

        # Get nested class by name using const_get
        klass = const_get(type)
        klass.deserialize_from_hash(hash)
      rescue NameError
        raise StandardError, "Unknown ResolvedData type: #{type}"
      end

      # Convert resolved data to human-readable text representation
      # This method should be implemented by each subclass
      # @return [String] Text representation
      def to_text
        @item_id || ''
      end

      # Get the reference type for this resolved data
      # @return [Symbol] Reference type (e.g., :image, :table, :list)
      def reference_type
        raise NotImplementedError, "#{self.class}#reference_type must be implemented"
      end

      # Format this reference as plain text using TextFormatter
      # Uses lazy initialization to avoid circular dependency issues
      # @return [String] Plain text representation of the reference
      def format_as_text
        @text_formatter ||= ReVIEW::AST::TextFormatter.new(format_type: :text, config: {})
        @text_formatter.format_reference(reference_type, self)
      end

      # Get short-form chapter number from long form
      # @return [String] Short chapter number ("1", "A", "II"), empty string if no chapter_number
      # @example
      #   "第1章" -> "1"
      #   "付録A" -> "A"
      #   "第II部" -> "II"
      def short_chapter_number
        return '' unless @chapter_number && !@chapter_number.to_s.empty?

        extract_short_chapter_number(@chapter_number)
      end

      # Extract short chapter number from formatted chapter number
      # "第1章" -> "1", "付録A" -> "A", "第II部" -> "II"
      def extract_short_chapter_number(long_num)
        long_num.to_s.gsub(/[^0-9A-Z]+/, '')
      end

      # Factory methods for common reference types

      def self.image(chapter_number:, item_number:, item_id:, chapter_id: nil, caption_node: nil)
        ImageReference.new(
          chapter_number: chapter_number,
          item_number: item_number,
          chapter_id: chapter_id,
          item_id: item_id,
          caption_node: caption_node
        )
      end

      def self.table(chapter_number:, item_number:, item_id:, chapter_id: nil, caption_node: nil)
        TableReference.new(
          chapter_number: chapter_number,
          item_number: item_number,
          chapter_id: chapter_id,
          item_id: item_id,
          caption_node: caption_node
        )
      end

      def self.list(chapter_number:, item_number:, item_id:, chapter_id: nil, caption_node: nil)
        ListReference.new(
          chapter_number: chapter_number,
          item_number: item_number,
          chapter_id: chapter_id,
          item_id: item_id,
          caption_node: caption_node
        )
      end

      def self.equation(chapter_number:, item_number:, item_id:, caption_node: nil)
        EquationReference.new(
          chapter_number: chapter_number,
          item_number: item_number,
          item_id: item_id,
          caption_node: caption_node
        )
      end

      def self.footnote(item_number:, item_id:, caption_node: nil)
        FootnoteReference.new(
          item_number: item_number,
          item_id: item_id,
          caption_node: caption_node
        )
      end

      def self.endnote(item_number:, item_id:, caption_node: nil)
        EndnoteReference.new(
          item_number: item_number,
          item_id: item_id,
          caption_node: caption_node
        )
      end

      def self.chapter(chapter_number:, chapter_id:, chapter_title: nil, caption_node: nil)
        ChapterReference.new(
          chapter_number: chapter_number,
          chapter_id: chapter_id,
          item_id: chapter_id, # For chapter refs, item_id is same as chapter_id
          chapter_title: chapter_title,
          caption_node: caption_node
        )
      end

      def self.headline(headline_number:, item_id:, chapter_id: nil, chapter_number: nil, caption_node: nil)
        HeadlineReference.new(
          item_id: item_id,
          chapter_id: chapter_id,
          chapter_number: chapter_number,
          headline_number: headline_number, # Array format [1, 2, 3]
          caption_node: caption_node
        )
      end

      def self.word(word_content:, item_id:, caption_node: nil)
        WordReference.new(
          item_id: item_id,
          word_content: word_content,
          caption_node: caption_node
        )
      end

      def self.column(chapter_number:, item_number:, item_id:, chapter_id: nil, caption_node: nil)
        ColumnReference.new(
          chapter_number: chapter_number,
          item_number: item_number,
          chapter_id: chapter_id,
          item_id: item_id,
          caption_node: caption_node
        )
      end

      def self.bibpaper(item_number:, item_id:, caption_node: nil)
        BibpaperReference.new(
          item_number: item_number,
          item_id: item_id,
          caption_node: caption_node
        )
      end
    end
  end
end

# Require nested class files
require_relative 'resolved_data/captioned_item_reference'
require_relative 'resolved_data/image_reference'
require_relative 'resolved_data/table_reference'
require_relative 'resolved_data/list_reference'
require_relative 'resolved_data/equation_reference'
require_relative 'resolved_data/footnote_reference'
require_relative 'resolved_data/endnote_reference'
require_relative 'resolved_data/chapter_reference'
require_relative 'resolved_data/headline_reference'
require_relative 'resolved_data/word_reference'
require_relative 'resolved_data/column_reference'
require_relative 'resolved_data/bibpaper_reference'
