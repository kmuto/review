# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

module ReVIEW
  module Renderer
    module Formatters
      # Format resolved references for TOP output
      class TopReferenceFormatter
        def initialize(renderer)
          @renderer = renderer
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
          compose_numbered_reference('equation', data)
        end

        def format_footnote_reference(data)
          number = data.item_number || data.item_id
          "【注#{number}】"
        end

        def format_endnote_reference(data)
          number = data.item_number || data.item_id
          "【後注#{number}】"
        end

        def format_word_reference(data)
          data.word_content.to_s
        end

        def format_chapter_reference(data)
          chapter_number = data.chapter_number
          chapter_title = data.chapter_title

          if chapter_title && chapter_number
            number_text = formatted_chapter_number(chapter_number)
            I18n.t('chapter_quote', [number_text, chapter_title])
          elsif chapter_title
            I18n.t('chapter_quote_without_number', chapter_title)
          elsif chapter_number
            formatted_chapter_number(chapter_number)
          else
            data.item_id.to_s
          end
        end

        def format_headline_reference(data)
          caption = data.caption_text
          headline_numbers = Array(data.headline_number).compact

          if !headline_numbers.empty?
            number_str = headline_numbers.join('.')
            I18n.t('hd_quote', [number_str, caption])
          elsif !caption.empty?
            I18n.t('hd_quote_without_number', caption)
          else
            data.item_id.to_s
          end
        end

        def format_column_reference(data)
          label = I18n.t('columnname')
          number_text = reference_number_text(data)
          "#{label}#{number_text || data.item_id || ''}"
        end

        private

        # Delegate helper methods to renderer
        def compose_numbered_reference(label_key, data)
          @renderer.send(:compose_numbered_reference, label_key, data)
        end

        def reference_number_text(data)
          @renderer.send(:reference_number_text, data)
        end

        def formatted_chapter_number(chapter_number)
          @renderer.send(:formatted_chapter_number, chapter_number)
        end
      end
    end
  end
end
