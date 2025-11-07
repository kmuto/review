# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

module ReVIEW
  module AST
    class ResolvedData
      class HeadlineReference < ResolvedData
        attr_reader :chapter_number

        def initialize(item_id:, headline_number:, chapter_id: nil, chapter_number: nil, caption_node: nil)
          super()
          @item_id = item_id
          @chapter_id = chapter_id
          @chapter_number = chapter_number
          @headline_number = headline_number
          @caption_node = caption_node
        end

        def to_text
          caption = caption_text
          if @headline_number && !@headline_number.empty?
            # Build full number with chapter number if available
            number_text = if @chapter_number
                            short_num = short_chapter_number
                            ([short_num] + @headline_number).join('.')
                          else
                            @headline_number.join('.')
                          end
            safe_i18n('hd_quote', [number_text, caption])
          elsif !caption.empty?
            safe_i18n('hd_quote_without_number', caption)
          else
            @item_id || ''
          end
        end

        def format_with(formatter)
          formatter.format_headline_reference(self)
        end

        def self.deserialize_from_hash(hash)
          caption_node = if hash['caption_node']
                           ReVIEW::AST::JSONSerializer.deserialize_from_hash(hash['caption_node'])
                         end
          new(
            item_id: hash['item_id'],
            headline_number: hash['headline_number'],
            chapter_id: hash['chapter_id'],
            chapter_number: hash['chapter_number'],
            caption_node: caption_node
          )
        end
      end
    end
  end
end
