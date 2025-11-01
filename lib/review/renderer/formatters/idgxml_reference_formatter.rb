# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

module ReVIEW
  module Renderer
    module Formatters
      # Format resolved references for IDGXML output
      class IdgxmlReferenceFormatter
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
          # Use caption_node to render inline elements like IDGXMLBuilder does
          caption = render_caption_inline(data.caption_node)
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

        # Delegate helper methods to renderer
        def compose_numbered_reference(label_key, data)
          @renderer.compose_numbered_reference(label_key, data)
        end

        def reference_number_text(data)
          @renderer.reference_number_text(data)
        end

        def formatted_chapter_number(chapter_number)
          @renderer.formatted_chapter_number(chapter_number)
        end

        def render_caption_inline(caption_node)
          @renderer.render_caption_inline(caption_node)
        end

        def escape(str)
          @renderer.escape(str)
        end
      end
    end
  end
end
