# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require_relative 'captioned_item_reference'

module ReVIEW
  module AST
    class ResolvedData
      class EquationReference < CaptionedItemReference
        # Equation doesn't have chapter_id parameter, so override initialize
        def initialize(chapter_number:, item_number:, item_id:, caption_node: nil)
          super(chapter_number: chapter_number,
                item_number: item_number,
                item_id: item_id,
                chapter_id: nil,
                caption_node: caption_node)
        end

        def label_key
          'equation'
        end

        def formatter_method
          :format_equation_reference
        end

        def self.deserialize_from_hash(hash)
          caption_node = if hash['caption_node']
                           ReVIEW::AST::JSONSerializer.deserialize_from_hash(hash['caption_node'])
                         end
          new(
            chapter_number: hash['chapter_number'],
            item_number: hash['item_number'],
            item_id: hash['item_id'],
            caption_node: caption_node
          )
        end
      end
    end
  end
end
