# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/htmlutils'
require 'review/escape_utils'

module ReVIEW
  module Renderer
    module Html
      # Context for inline element rendering with business logic
      # Used by InlineElementHandler
      class InlineContext
        include ReVIEW::HTMLUtils
        include ReVIEW::EscapeUtils

        attr_reader :config, :book, :chapter, :renderer, :img_math

        def initialize(config:, book:, chapter:, renderer:, img_math: nil)
          @config = config
          @book = book
          @chapter = chapter
          @renderer = renderer
          @img_math = img_math
        end

        # === Computed properties ===

        def extname
          ".#{config['htmlext'] || 'html'}"
        end

        def epub3?
          config['epubversion'].to_i == 3
        end

        def math_format
          config['math_format'] || 'mathjax'
        end

        # === HTMLUtils methods are available via include ===
        # - escape(str)
        # - escape_content(str) (if EscapeUtils is available)
        # - escape_comment(str)
        # - normalize_id(id)
        # - escape_url(str)

        # === Chapter/Book navigation logic ===

        def chapter_number(chapter_id)
          book.chapter_index.number(chapter_id)
        end

        def chapter_title(chapter_id)
          book.chapter_index.title(chapter_id)
        end

        def chapter_display_string(chapter_id)
          book.chapter_index.display_string(chapter_id)
        end

        # === Link generation logic ===

        def chapter_link_enabled?
          config['chapterlink']
        end

        def build_chapter_link(chapter_id, content)
          if chapter_link_enabled?
            %Q(<a href="./#{chapter_id}#{extname}">#{content}</a>)
          else
            content
          end
        end

        def build_anchor_link(anchor_id, content, css_class: 'link')
          %Q(<a href="##{normalize_id(anchor_id)}" class="#{css_class}">#{content}</a>)
        end

        def build_external_link(url, content, css_class: 'link')
          %Q(<a href="#{escape_content(url)}" class="#{css_class}">#{content}</a>)
        end

        # === Footnote logic ===

        def footnote_number(fn_id)
          chapter.footnote(fn_id).number
        end

        def build_footnote_link(fn_id, number)
          if epub3?
            %Q(<a id="fnb-#{normalize_id(fn_id)}" href="#fn-#{normalize_id(fn_id)}" class="noteref" epub:type="noteref">#{I18n.t('html_footnote_refmark', number)}</a>)
          else
            %Q(<a id="fnb-#{normalize_id(fn_id)}" href="#fn-#{normalize_id(fn_id)}" class="noteref">*#{number}</a>)
          end
        end

        # === Index/Keyword logic ===

        def build_index_comment(index_str)
          %Q(<!-- IDX:#{escape_comment(index_str)} -->)
        end

        def build_keyword_with_index(word, alt: nil)
          escaped_word = escape_content(word)

          if alt && !alt.empty?
            escaped_alt = escape_content(alt)
            # Include alt text in visible content, but only word in IDX comment
            text = "#{escaped_word} (#{escaped_alt})"
            %Q(<b class="kw">#{text}</b><!-- IDX:#{escaped_word} -->)
          else
            %Q(<b class="kw">#{escaped_word}</b><!-- IDX:#{escaped_word} -->)
          end
        end

        # === Ruby (furigana) logic ===

        def build_ruby(base, ruby_text)
          %Q(<ruby>#{escape_content(base)}<rt>#{escape_content(ruby_text)}</rt></ruby>)
        end

        # === Format detection ===

        def target_format?(format_name)
          format_name.to_s == 'html'
        end

        def parse_embed_formats(args_str)
          # Parse @<embed>{|html,latex|content} style
          if matched = args_str.match(/\|(.*?)\|(.*)/)
            formats = matched[1].split(',').map(&:strip)
            content = matched[2]
            [formats, content]
          else
            [nil, args_str]
          end
        end

        # === Icon/Image logic ===

        def build_icon_html(icon_id)
          image_item = chapter.image(icon_id)
          path = image_item.path.sub(%r{\A\./}, '')
          %Q(<img src="#{path}" alt="[#{icon_id}]" />)
        end

        # === Bibliography logic ===

        def bibpaper_number(bib_id)
          chapter.bibpaper(bib_id).number
        end

        def build_bib_reference_link(bib_id, number)
          bib_file = book.bib_file.gsub(/\.re\Z/, extname)
          %Q(<a href="#{bib_file}#bib-#{normalize_id(bib_id)}">[#{number}]</a>)
        end

        # === Endnote logic ===

        def build_endnote_link(endnote_id, number)
          if epub3?
            %Q(<a id="endnoteb-#{normalize_id(endnote_id)}" href="#endnote-#{normalize_id(endnote_id)}" class="noteref" epub:type="noteref">#{I18n.t('html_endnote_refmark', number)}</a>)
          else
            %Q(<a id="endnoteb-#{normalize_id(endnote_id)}" href="#endnote-#{normalize_id(endnote_id)}" class="noteref">#{number}</a>)
          end
        end

        # === Chapter/Section navigation helpers ===

        def over_secnolevel?(n)
          secnolevel = config['secnolevel'] || 0
          secnolevel >= n.to_s.split('.').size
        end

        def render_children(node)
          renderer.render_children(node)
        end
      end
    end
  end
end
