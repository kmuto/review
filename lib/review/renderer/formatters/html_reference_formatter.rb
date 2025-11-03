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
      # Format resolved references for HTML output
      class HtmlReferenceFormatter
        include ReVIEW::HTMLUtils

        def initialize(config:)
          @config = config
        end

        def format_image_reference(data)
          number_text = if data.chapter_number
                          "#{I18n.t('image')}#{I18n.t('format_number', [data.chapter_number, data.item_number])}"
                        else
                          "#{I18n.t('image')}#{I18n.t('format_number_without_chapter', [data.item_number])}"
                        end

          if config['chapterlink'] && data.cross_chapter?
            %Q(<span class="imgref"><a href="./#{data.chapter_id}#{extname}##{normalize_id(data.item_id)}">#{number_text}</a></span>)
          elsif config['chapterlink']
            %Q(<span class="imgref"><a href="##{normalize_id(data.item_id)}">#{number_text}</a></span>)
          else
            %Q(<span class="imgref">#{number_text}</span>)
          end
        end

        def format_table_reference(data)
          number_text = if data.chapter_number
                          "#{I18n.t('table')}#{I18n.t('format_number', [data.chapter_number, data.item_number])}"
                        else
                          "#{I18n.t('table')}#{I18n.t('format_number_without_chapter', [data.item_number])}"
                        end

          if config['chapterlink'] && data.cross_chapter?
            %Q(<span class="tableref"><a href="./#{data.chapter_id}#{extname}##{normalize_id(data.item_id)}">#{number_text}</a></span>)
          elsif config['chapterlink']
            %Q(<span class="tableref"><a href="##{normalize_id(data.item_id)}">#{number_text}</a></span>)
          else
            %Q(<span class="tableref">#{number_text}</span>)
          end
        end

        def format_list_reference(data)
          number_text = if data.chapter_number
                          "#{I18n.t('list')}#{I18n.t('format_number', [data.chapter_number, data.item_number])}"
                        else
                          "#{I18n.t('list')}#{I18n.t('format_number_without_chapter', [data.item_number])}"
                        end

          if config['chapterlink'] && data.cross_chapter?
            %Q(<span class="listref"><a href="./#{data.chapter_id}#{extname}##{normalize_id(data.item_id)}">#{number_text}</a></span>)
          elsif config['chapterlink']
            %Q(<span class="listref"><a href="##{normalize_id(data.item_id)}">#{number_text}</a></span>)
          else
            %Q(<span class="listref">#{number_text}</span>)
          end
        end

        def format_equation_reference(data)
          number_text = "#{I18n.t('equation')}#{I18n.t('format_number', [data.chapter_number, data.item_number])}"
          if config['chapterlink']
            %Q(<span class="eqref"><a href="##{normalize_id(data.item_id)}">#{number_text}</a></span>)
          else
            %Q(<span class="eqref">#{number_text}</span>)
          end
        end

        def format_footnote_reference(data)
          data.item_number.to_s
        end

        def format_endnote_reference(data)
          data.item_number.to_s
        end

        def format_chapter_reference(data)
          # For chap and chapref, format based on parent inline type
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
          "#{I18n.t('column')}#{I18n.t('format_number', [data.chapter_number, data.item_number])}"
        end

        def format_word_reference(data)
          escape(data.word_content)
        end

        def format_bibpaper_reference(data)
          bib_number = data.item_number
          %Q(<span class="bibref">[#{bib_number}]</span>)
        end

        private

        attr_reader :config

        def extname
          ".#{config['htmlext'] || 'html'}"
        end
      end
    end
  end
end
