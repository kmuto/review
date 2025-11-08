# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/htmlutils'

module ReVIEW
  module Renderer
    module Idgxml
      # Context for inline element rendering with business logic
      # Used by InlineElementHandler
      class InlineContext
        # Proxy that provides minimal interface to renderer
        # Only exposes render_children and render_caption_inline methods
        # This class is private and should not be used directly outside InlineContext
        class InlineRenderProxy
          def initialize(renderer)
            @renderer = renderer
          end

          def render_children(node)
            @renderer.render_children(node)
          end

          def render_caption_inline(caption_node)
            @renderer.render_caption_inline(caption_node)
          end

          def increment_texinlineequation
            @renderer.increment_texinlineequation
          end

          def text_formatter
            @renderer.text_formatter
          end
        end
        private_constant :InlineRenderProxy

        include ReVIEW::HTMLUtils

        attr_reader :config, :book, :chapter, :img_math

        def initialize(config:, book:, chapter:, renderer:, img_math: nil)
          @config = config
          @book = book
          @chapter = chapter
          # Automatically create proxy from renderer to limit access
          @render_proxy = InlineRenderProxy.new(renderer)
          @img_math = img_math
        end

        # === HTMLUtils methods are available via include ===
        # - escape_html(str)
        # - normalize_id(id)

        # Escape for IDGXML (uses HTML escaping)
        def escape(str)
          escape_html(str.to_s)
        end

        def chapter_link_enabled?
          config['chapterlink']
        end

        def draft_mode?
          config['draft']
        end

        def nolf_mode?
          config.key?('nolf') ? config['nolf'] : true
        end

        def math_format
          config['math_format']
        end

        def over_secnolevel?(n)
          secnolevel = config['secnolevel'] || 2
          secnolevel >= n.to_s.split('.').size
        end

        def get_chap # rubocop:disable Naming/AccessorMethodName
          if config['secnolevel'] && config['secnolevel'] > 0 &&
             !chapter.number.nil? && !chapter.number.to_s.empty?
            if chapter.is_a?(ReVIEW::Book::Part)
              return text_formatter.format_part_short(chapter)
            else
              return chapter.format_number(nil)
            end
          end
          nil
        end

        def bibpaper_number(bib_id)
          chapter.bibpaper(bib_id).number
        end

        def increment_texinlineequation
          @render_proxy.increment_texinlineequation
        end

        def render_children(node)
          @render_proxy.render_children(node)
        end

        def render_caption_inline(caption_node)
          @render_proxy.render_caption_inline(caption_node)
        end

        def text_formatter
          @render_proxy.text_formatter
        end
      end
    end
  end
end
