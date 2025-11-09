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
        def initialize(item_id:, headline_number:, chapter_id: nil, chapter_number: nil, chapter_type: nil, caption_node: nil)
          super()
          @item_id = item_id
          @chapter_id = chapter_id
          @chapter_number = chapter_number
          @headline_number = headline_number
          @chapter_type = chapter_type
          @caption_node = caption_node
        end

        def reference_type
          :headline
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
            chapter_type: hash['chapter_type']&.to_sym,
            caption_node: caption_node
          )
        end
      end
    end
  end
end
