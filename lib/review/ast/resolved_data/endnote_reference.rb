# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

module ReVIEW
  module AST
    class ResolvedData
      class EndnoteReference < ResolvedData
        def initialize(item_number:, item_id:, caption_node: nil)
          super()
          @item_number = item_number
          @item_id = item_id
          @caption_node = caption_node
        end

        def to_text
          @item_number.to_s
        end

        def formatter_method
          :format_endnote_reference
        end

        def self.deserialize_from_hash(hash)
          caption_node = if hash['caption_node']
                           ReVIEW::AST::JSONSerializer.deserialize_from_hash(hash['caption_node'])
                         end
          new(
            item_number: hash['item_number'],
            item_id: hash['item_id'],
            caption_node: caption_node
          )
        end
      end
    end
  end
end
