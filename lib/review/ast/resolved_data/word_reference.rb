# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

module ReVIEW
  module AST
    class ResolvedData
      class WordReference < ResolvedData
        def initialize(item_id:, word_content:, caption_node: nil)
          super()
          @item_id = item_id
          @word_content = word_content
          @caption_node = caption_node
        end

        def to_text
          @word_content
        end

        def formatter_method
          :format_word_reference
        end

        def self.deserialize_from_hash(hash)
          caption_node = if hash['caption_node']
                           ReVIEW::AST::JSONSerializer.deserialize_from_hash(hash['caption_node'])
                         end
          new(
            item_id: hash['item_id'],
            word_content: hash['word_content'],
            caption_node: caption_node
          )
        end
      end
    end
  end
end
