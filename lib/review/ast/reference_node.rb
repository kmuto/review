# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/ast/text_node'
require 'review/ast/resolved_data'
require 'review/i18n'

module ReVIEW
  module AST
    # ReferenceNode - node that holds reference information (used as a child of InlineNode)
    #
    # Placed as a child node of reference-type InlineNode instead of traditional TextNode.
    # This node is immutable, and a new instance is created when resolving references.
    class ReferenceNode < TextNode
      attr_reader :ref_id, :context_id, :resolved_data

      # @param ref_id [String] reference ID (primary reference target)
      # @param context_id [String] context ID (chapter ID, etc., optional)
      # @param resolved_data [ResolvedData, nil] structured resolved data
      # @param location [SnapshotLocation, nil] location in source code
      def initialize(ref_id, context_id = nil, location:, resolved_data: nil)
        # Display resolved_data if resolved, otherwise display original reference ID
        content = if resolved_data
                    # Generate appropriate content from resolved_data (default representation)
                    generate_content_from_data(resolved_data)
                  else
                    context_id ? "#{context_id}|#{ref_id}" : ref_id
                  end

        super(content: content, location: location)

        @ref_id = ref_id
        @context_id = context_id
        @resolved_data = resolved_data
      end

      private

      # Generate default content string from ResolvedData
      def generate_content_from_data(data)
        case data
        when ResolvedData::Image
          format_captioned_reference('image', data)
        when ResolvedData::Table
          format_captioned_reference('table', data)
        when ResolvedData::List
          format_captioned_reference('list', data)
        when ResolvedData::Equation
          format_captioned_reference('equation', data)
        when ResolvedData::Footnote, ResolvedData::Endnote
          data.item_number.to_s
        when ResolvedData::Chapter
          format_chapter_reference(data)
        when ResolvedData::Headline
          format_headline_reference(data)
        when ResolvedData::Column
          format_column_reference(data)
        when ResolvedData::Word
          data.word_content
        else
          data.item_id || @ref_id
        end
      end

      def format_captioned_reference(label_key, data)
        label = safe_i18n(label_key)
        number_text = format_reference_number(data)
        base = "#{label}#{number_text}"
        caption_text = data.caption_text
        if caption_text.empty?
          base
        else
          "#{base}#{caption_separator}#{caption_text}"
        end
      end

      def format_reference_number(data)
        chapter_number = data.chapter_number
        if chapter_number && !chapter_number.to_s.empty?
          safe_i18n('format_number', [chapter_number, data.item_number])
        else
          safe_i18n('format_number_without_chapter', [data.item_number])
        end
      end

      def format_chapter_reference(data)
        chapter_number = data.chapter_number
        chapter_title = data.chapter_title

        if chapter_number && chapter_title
          number_text = chapter_number_text(chapter_number)
          safe_i18n('chapter_quote', [number_text, chapter_title])
        elsif chapter_title
          safe_i18n('chapter_quote_without_number', chapter_title)
        elsif chapter_number
          chapter_number_text(chapter_number)
        else
          data.item_id || @ref_id
        end
      end

      def format_headline_reference(data)
        headline_number = data.headline_number
        caption = data.caption_text
        if headline_number && !headline_number.empty?
          number_text = headline_number.join('.')
          safe_i18n('hd_quote', [number_text, caption])
        elsif !caption.empty?
          safe_i18n('hd_quote_without_number', caption)
        else
          data.item_id || @ref_id
        end
      end

      def format_column_reference(data)
        caption_text = data.caption_text
        if caption_text.empty?
          data.item_id || @ref_id
        else
          safe_i18n('column', caption_text)
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

      def safe_i18n(key, args = nil)
        ReVIEW::I18n.t(key, args)
      rescue StandardError
        key
      end

      def chapter_number_text(chapter_number)
        if numeric_string?(chapter_number)
          safe_i18n('chapter', chapter_number.to_i)
        else
          chapter_number.to_s
        end
      end

      def numeric_string?(value)
        value.to_s.match?(/\A-?\d+\z/)
      end

      public

      # Check if the reference has been resolved
      # @return [Boolean] true if resolved
      def resolved?
        !!@resolved_data
      end

      # Return the full reference ID (concatenated with context_id if present)
      # @return [String] full reference ID
      def full_ref_id
        @context_id ? "#{@context_id}|#{@ref_id}" : @ref_id
      end

      # Return a new ReferenceNode instance resolved with structured data
      # @param data [ResolvedData] structured resolved data
      # @return [ReferenceNode] new resolved instance
      def with_resolved_data(data)
        self.class.new(
          @ref_id,
          @context_id,
          resolved_data: data,
          location: @location
        )
      end

      # Node description string for debugging
      # @return [String] debug string representation
      def to_s
        status = resolved? ? "resolved: #{@content}" : 'unresolved'
        "#<ReferenceNode {#{full_ref_id}} #{status}>"
      end
    end
  end
end
