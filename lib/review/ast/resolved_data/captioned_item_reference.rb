# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

module ReVIEW
  module AST
    class ResolvedData
      # Base class for references with chapter number, item number, and caption
      # This class consolidates the common pattern used by ImageReference, TableReference,
      # ListReference, EquationReference, and ColumnReference
      class CaptionedItemReference < ResolvedData
        def initialize(chapter_number:, item_number:, item_id:, chapter_id: nil, caption_node: nil)
          super()
          @chapter_number = chapter_number
          @item_number = item_number
          @chapter_id = chapter_id
          @item_id = item_id
          @caption_node = caption_node
        end

        # Subclasses should override label_key to specify their I18n label
        def to_text
          format_captioned_reference(label_key)
        end

        # Template method - subclasses must implement this
        # @return [String] The I18n key for the label (e.g., 'image', 'table', 'list')
        def label_key
          raise NotImplementedError, "#{self.class} must implement #label_key"
        end

        # Template method for double dispatch formatting
        def format_with(formatter)
          formatter.send(formatter_method, self)
        end

        # Template method - subclasses must implement this
        # @return [Symbol] The formatter method name (e.g., :format_image_reference)
        def formatter_method
          raise NotImplementedError, "#{self.class} must implement #formatter_method"
        end
      end
    end
  end
end
