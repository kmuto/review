# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/htmlutils'
require 'review/html_escape_utils'
require_relative '../inline_render_proxy'

module ReVIEW
  module Renderer
    module Html
      # Context for inline element rendering with business logic
      # Used by InlineElementHandler
      class InlineContext

        include ReVIEW::HTMLUtils
        include ReVIEW::HtmlEscapeUtils

        attr_reader :config, :book, :chapter, :img_math

        def initialize(config:, book:, chapter:, renderer:, img_math: nil)
          @config = config
          @book = book
          @chapter = chapter
          # Automatically create proxy from renderer to limit access
          @render_proxy = InlineRenderProxy.new(renderer)
          @img_math = img_math
        end

        def extname
          ".#{config['htmlext'] || 'html'}"
        end

        def epub3?
          config['epubversion'].to_i == 3
        end

        def math_format
          config['math_format'] || 'mathjax'
        end

        # === HTMLUtils and HtmlEscapeUtils methods are available via include ===
        # From HTMLUtils:
        # - escape(str) or h(str) - Basic HTML escaping
        # - escape_comment(str) - HTML comment escaping (escapes '-' to '&#45;')
        # - normalize_id(id) - ID normalization for HTML elements
        # From HtmlEscapeUtils:
        # - escape_content(str) - Content escaping (same as escape)
        # - escape_url(str) - URL escaping using CGI.escape

        def chapter_number(chapter_id)
          book.chapter_index.number(chapter_id)
        end

        def chapter_title(chapter_id)
          book.chapter_index.title(chapter_id)
        end

        def chapter_display_string(chapter_id)
          book.chapter_index.display_string(chapter_id)
        end

        def chapter_link_enabled?
          config['chapterlink']
        end

        def footnote_number(fn_id)
          chapter.footnote(fn_id).number
        end

        def build_icon_html(icon_id)
          image_item = chapter.image(icon_id)
          path = image_item.path.sub(%r{\A\./}, '')
          %Q(<img src="#{path}" alt="[#{icon_id}]" />)
        end

        def bibpaper_number(bib_id)
          chapter.bibpaper(bib_id).number
        end

        def build_bib_reference_link(bib_id, number)
          bib_file = book.bib_file.gsub(/\.re\Z/, extname)
          %Q(<a href="#{bib_file}#bib-#{normalize_id(bib_id)}">[#{number}]</a>)
        end

        def over_secnolevel?(n)
          secnolevel = config['secnolevel'] || 0
          # Section level = chapter level (1) + n.size
          # Only show numbers if secnolevel is >= section level
          section_level = n.is_a?(::Array) ? (1 + n.size) : (1 + n.to_s.split('.').size)
          secnolevel >= section_level
        end

        def render_children(node)
          @render_proxy.render_children(node)
        end

        def text_formatter
          @render_proxy.text_formatter
        end
      end
    end
  end
end
