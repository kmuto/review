# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/htmlutils'

module ReVIEW
  module Renderer
    module Formatters
      # Format resolved references for IDGXML output
      class IdgxmlReferenceFormatter
        include ReVIEW::HTMLUtils

        def initialize(config:)
          @config = config
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
          number_text = reference_number_text(data)
          label = I18n.t('equation')
          escape("#{label}#{number_text || data.item_id || ''}")
        end

        def format_footnote_reference(data)
          data.item_number.to_s
        end

        def format_endnote_reference(data)
          data.item_number.to_s
        end

        def format_chapter_reference(data)
          chapter_number = data.chapter_number
          chapter_title = data.chapter_title

          if chapter_title && chapter_number
            number_text = formatted_chapter_number(chapter_number)
            escape(I18n.t('chapter_quote', [number_text, chapter_title]))
          elsif chapter_title
            escape(I18n.t('chapter_quote_without_number', chapter_title))
          elsif chapter_number
            escape(formatted_chapter_number(chapter_number))
          else
            escape(data.item_id || '')
          end
        end

        def format_headline_reference(data)
          caption = data.caption_text
          headline_numbers = Array(data.headline_number).compact

          if !headline_numbers.empty?
            number_str = headline_numbers.join('.')
            escape(I18n.t('hd_quote', [number_str, caption]))
          elsif !caption.empty?
            escape(I18n.t('hd_quote_without_number', caption))
          else
            escape(data.item_id || '')
          end
        end

        def format_column_reference(data)
          label = I18n.t('columnname')
          number_text = reference_number_text(data)
          escape("#{label}#{number_text || data.item_id || ''}")
        end

        def format_word_reference(data)
          escape(data.word_content)
        end

        private

        attr_reader :config

        # Helper methods for formatting references
        def compose_numbered_reference(label_key, data)
          label = I18n.t(label_key)
          number_text = reference_number_text(data)
          escape("#{label}#{number_text || data.item_id || ''}")
        end

        def reference_number_text(data)
          item_number = data.item_number
          return nil unless item_number

          chapter_number = data.chapter_number
          if chapter_number && !chapter_number.to_s.empty?
            I18n.t('format_number', [chapter_number, item_number])
          else
            I18n.t('format_number_without_chapter', [item_number])
          end
        rescue StandardError
          nil
        end

        def formatted_chapter_number(chapter_number)
          if chapter_number.to_s.match?(/\A-?\d+\z/)
            I18n.t('chapter', chapter_number.to_i)
          else
            chapter_number.to_s
          end
        end
      end
    end
  end
end
