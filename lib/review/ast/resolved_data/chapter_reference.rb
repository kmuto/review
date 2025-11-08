# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

module ReVIEW
  module AST
    class ResolvedData
      # ChapterReference - represents chapter references (@<chap>, @<chapref>, @<title>)
      class ChapterReference < ResolvedData
        def initialize(chapter_number:, chapter_id:, item_id:, chapter_title: nil, caption_node: nil)
          super()
          @chapter_number = chapter_number
          @chapter_id = chapter_id
          @item_id = item_id
          @chapter_title = chapter_title
          @caption_node = caption_node
        end

        # Return chapter number only (for @<chap>)
        # Example: "第1章", "付録A", "第II部"
        # chapter_number already contains the long form
        def to_number_text
          @chapter_number || @item_id || ''
        end

        # Return chapter title only (for @<title>)
        # Example: "章見出し", "付録の見出し"
        def to_title_text
          @chapter_title || @item_id || ''
        end

        # Return full chapter reference (for @<chapref>)
        # Example: "第1章「章見出し」"
        # Uses TextFormatter for consistent I18n handling
        def to_text
          format_as_text
        end

        def reference_type
          :chapter
        end

        def self.deserialize_from_hash(hash)
          caption_node = if hash['caption_node']
                           ReVIEW::AST::JSONSerializer.deserialize_from_hash(hash['caption_node'])
                         end
          new(
            chapter_number: hash['chapter_number'],
            chapter_id: hash['chapter_id'],
            item_id: hash['item_id'],
            chapter_title: hash['chapter_title'],
            caption_node: caption_node
          )
        end
      end
    end
  end
end
