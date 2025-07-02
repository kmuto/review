# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/renderer/markdown_renderer'
require 'review/htmlutils'
require 'review/textutils'

module ReVIEW
  module Renderer
    class MarkdownRenderer < Base
      # Inline element renderer for Markdown output
      class InlineElementRenderer
        include ReVIEW::HTMLUtils
        include ReVIEW::TextUtils

        def initialize(renderer, book:, chapter:, rendering_context:)
          @renderer = renderer
          @book = book
          @chapter = chapter
          @rendering_context = rendering_context
        end

        def render(type, content, node)
          method_name = "render_inline_#{type}"
          if respond_to?(method_name, true)
            send(method_name, type, content, node)
          else
            raise NotImplementedError, "Unknown inline element: #{type}"
          end
        end

        private

        def render_inline_b(_type, content, _node)
          "**#{escape_asterisks(content)}**"
        end

        def render_inline_strong(_type, content, _node)
          "**#{escape_asterisks(content)}**"
        end

        def render_inline_i(_type, content, _node)
          "*#{escape_asterisks(content)}*"
        end

        def render_inline_em(_type, content, _node)
          "*#{escape_asterisks(content)}*"
        end

        def render_inline_code(_type, content, _node)
          "`#{content}`"
        end

        def render_inline_tt(_type, content, _node)
          "`#{content}`"
        end

        def render_inline_kbd(_type, content, _node)
          "`#{content}`"
        end

        def render_inline_samp(_type, content, _node)
          "`#{content}`"
        end

        def render_inline_var(_type, content, _node)
          "*#{escape_asterisks(content)}*"
        end

        def render_inline_sup(_type, content, _node)
          "<sup>#{escape_content(content)}</sup>"
        end

        def render_inline_sub(_type, content, _node)
          "<sub>#{escape_content(content)}</sub>"
        end

        def render_inline_del(_type, content, _node)
          "~~#{content}~~"
        end

        def render_inline_ins(_type, content, _node)
          "<ins>#{escape_content(content)}</ins>"
        end

        def render_inline_u(_type, content, _node)
          "<u>#{escape_content(content)}</u>"
        end

        def render_inline_br(_type, _content, _node)
          "\n"
        end

        def render_inline_raw(_type, content, node)
          if node.args && node.args.first
            format = node.args.first
            if format == 'markdown'
              content
            else
              '' # Ignore raw content for other formats
            end
          else
            content
          end
        end

        def render_inline_chap(_type, content, _node)
          escape_content(content)
        end

        def render_inline_title(_type, content, _node)
          "**#{escape_asterisks(content)}**"
        end

        def render_inline_chapref(_type, content, _node)
          escape_content(content)
        end

        def render_inline_list(_type, content, _node)
          escape_content(content)
        end

        def render_inline_img(_type, content, node)
          if node.args && node.args.first
            image_id = node.args.first
            "![#{escape_content(content)}](##{image_id})"
          else
            "![#{escape_content(content)}](##{content})"
          end
        end

        def render_inline_icon(_type, content, node)
          if node.args && node.args.first
            image_path = node.args.first
            image_path = image_path.sub(%r{\A\./}, '')
            "![](#{image_path})"
          else
            "![](#{content})"
          end
        end

        def render_inline_table(_type, content, _node)
          escape_content(content)
        end

        def render_inline_fn(_type, content, node)
          if node.args && node.args.first
            fn_id = node.args.first
            "[^#{fn_id}]"
          else
            "[^#{content}]"
          end
        end

        def render_inline_kw(_type, content, node)
          if node.args && node.args.length >= 2
            word = node.args[0]
            alt = node.args[1]
            "**#{escape_asterisks(word)}** (#{escape_content(alt)})"
          else
            "**#{escape_asterisks(content)}**"
          end
        end

        def render_inline_bou(_type, content, _node)
          "*#{escape_asterisks(content)}*"
        end

        def render_inline_ami(_type, content, _node)
          "*#{escape_asterisks(content)}*"
        end

        def render_inline_href(_type, content, node)
          args = node.args || []
          if args.length >= 2
            url = args[0]
            text = args[1]
            "[#{text}](#{url})"
          else
            "[#{content}](#{content})"
          end
        end

        def render_inline_url(_type, content, _node)
          "[#{content}](#{content})"
        end

        def render_inline_ruby(_type, content, node)
          if node.args && node.args.length >= 2
            base = node.args[0]
            ruby = node.args[1]
            "<ruby>#{escape_content(base)}<rt>#{escape_content(ruby)}</rt></ruby>"
          else
            escape_content(content)
          end
        end

        def render_inline_m(_type, content, _node)
          "$$#{content}$$"
        end

        def render_inline_idx(_type, content, _node)
          escape_content(content)
        end

        def render_inline_hidx(_type, _content, _node)
          ''
        end

        def render_inline_comment(_type, content, _node)
          if @book&.config&.[]('draft')
            "<!-- #{escape_content(content)} -->"
          else
            ''
          end
        end

        def render_inline_hd(_type, content, _node)
          escape_content(content)
        end

        def render_inline_sec(_type, content, _node)
          escape_content(content)
        end

        def render_inline_secref(_type, content, _node)
          escape_content(content)
        end

        def render_inline_labelref(_type, content, _node)
          escape_content(content)
        end

        def render_inline_ref(_type, content, _node)
          escape_content(content)
        end

        def render_inline_pageref(_type, content, _node)
          escape_content(content)
        end

        def render_inline_w(_type, content, _node)
          # Dictionary lookup for word substitution
          dictionary = @book&.config&.[]('dictionary') || {}
          translated = dictionary[content]
          escape_content(translated || "[missing word: #{content}]")
        end

        def render_inline_wb(_type, content, _node)
          # Dictionary lookup with bold formatting
          dictionary = @book&.config&.[]('dictionary') || {}
          word_content = dictionary[content] || "[missing word: #{content}]"
          "**#{escape_asterisks(word_content)}**"
        end

        # Helper methods
        def escape_content(str)
          escape(str)
        end

        def escape_asterisks(str)
          str.gsub('*', '\\*')
        end
      end
    end
  end
end
