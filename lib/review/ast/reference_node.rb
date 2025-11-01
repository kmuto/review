# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/ast/text_node'
require 'review/ast/resolved_data'
require 'review/i18n'

module ReVIEW
  module AST
    # ReferenceNode - 参照情報を保持するノード（InlineNodeの子ノードとして使用）
    #
    # 従来のTextNodeの代わりに参照系InlineNodeの子ノードとして配置される。
    # このノードはイミュータブルであり、参照解決時には新しいインスタンスが作成される。
    class ReferenceNode < TextNode
      attr_reader :ref_id, :context_id, :resolved, :resolved_data

      # @param ref_id [String] 参照ID（主要な参照先）
      # @param context_id [String] コンテキストID（章ID等、オプション）
      # @param resolved [Boolean] 参照が解決済みかどうか
      # @param resolved_content [String, nil] 解決された内容（後方互換性のため）
      # @param resolved_data [ResolvedData, nil] 構造化された解決済みデータ
      # @param location [SnapshotLocation, nil] ソースコード内の位置情報
      def initialize(ref_id, context_id = nil, resolved_data: nil, location: nil)
        # 解決済みの場合はresolved_dataを、未解決の場合は元の参照IDを表示
        content = if resolved_data
                    # resolved_dataから適切なコンテンツを生成（デフォルト表現）
                    generate_content_from_data(resolved_data)
                  else
                    context_id ? "#{context_id}|#{ref_id}" : ref_id
                  end

        super(content: content, location: location)

        @ref_id = ref_id
        @context_id = context_id
        @resolved_data = resolved_data
        @resolved = !!resolved_data
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

      # 参照が解決済みかどうかを判定
      # @return [Boolean] 解決済みの場合true
      def resolved?
        !!@resolved_data
      end

      # 構造化データで解決済みの新しいReferenceNodeインスタンスを返す
      # @param data [ResolvedData] 構造化された解決済みデータ
      # @return [ReferenceNode] 解決済みの新しいインスタンス
      def with_resolved_data(data)
        self.class.new(
          @ref_id,
          @context_id,
          resolved_data: data,
          location: @location
        )
      end

      # ノードの説明文字列
      # @return [String] デバッグ用の文字列表現
      def to_s
        id_part = @context_id ? "#{@context_id}|#{@ref_id}" : @ref_id
        status = resolved? ? "resolved: #{@content}" : 'unresolved'
        "#<ReferenceNode {#{id_part}} #{status}>"
      end
    end
  end
end
