# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/latexutils'

module ReVIEW
  module Renderer
    module Formatters
      # Format resolved references for LaTeX output
      class LaTeXReferenceFormatter
        include ReVIEW::LaTeXUtils

        def initialize(renderer, config:)
          @renderer = renderer
          @config = config
          # Initialize LaTeX character escaping
          initialize_metachars(config['texcommand'])
        end

        def format_image_reference(data)
          # LaTeX uses \ref{} for cross-references
          if data.cross_chapter?
            # For cross-chapter references, use full path
            "\\ref{#{data.chapter_id}:#{data.item_id}}"
          else
            "\\ref{#{data.item_id}}"
          end
        end

        def format_table_reference(data)
          # LaTeX uses \ref{} for cross-references
          if data.cross_chapter?
            "\\ref{#{data.chapter_id}:#{data.item_id}}"
          else
            "\\ref{#{data.item_id}}"
          end
        end

        def format_list_reference(data)
          # LaTeX uses \ref{} for cross-references
          if data.cross_chapter?
            "\\ref{#{data.chapter_id}:#{data.item_id}}"
          else
            "\\ref{#{data.item_id}}"
          end
        end

        def format_equation_reference(data)
          # LaTeX equation references
          "\\ref{#{data.item_id}}"
        end

        def format_footnote_reference(data)
          # LaTeX footnote references use the footnote number
          "\\footnotemark[#{data.item_number}]"
        end

        def format_endnote_reference(data)
          data.item_number.to_s
        end

        def format_chapter_reference(data)
          # Format chapter reference
          if data.chapter_title
            "第#{data.chapter_number}章「#{escape(data.chapter_title)}」"
          else
            "第#{data.chapter_number}章"
          end
        end

        def format_headline_reference(data)
          number_str = data.headline_number.join('.')
          caption = data.caption_text

          if number_str.empty?
            "「#{escape(caption)}」"
          else
            "#{number_str} #{escape(caption)}"
          end
        end

        def format_column_reference(data)
          "コラム#{data.chapter_number}.#{data.item_number}"
        end

        def format_word_reference(data)
          escape(data.word_content)
        end

        private

        attr_reader :config
      end
    end
  end
end
