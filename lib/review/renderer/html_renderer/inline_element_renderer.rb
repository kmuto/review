# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/renderer/html_renderer'
require 'review/htmlutils'
require 'review/textutils'

module ReVIEW
  module Renderer
    class HtmlRenderer < Base
      # Inline element renderer for HTML output
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
          %Q(<b>#{escape_content(content)}</b>)
        end

        def render_inline_strong(_type, content, _node)
          %Q(<strong>#{escape_content(content)}</strong>)
        end

        def render_inline_i(_type, content, _node)
          %Q(<i>#{escape_content(content)}</i>)
        end

        def render_inline_em(_type, content, _node)
          %Q(<em>#{escape_content(content)}</em>)
        end

        def render_inline_code(_type, content, _node)
          %Q(<code class="inline-code tt">#{escape_content(content)}</code>)
        end

        def render_inline_tt(_type, content, _node)
          %Q(<code class="tt">#{escape_content(content)}</code>)
        end

        def render_inline_kbd(_type, content, _node)
          %Q(<kbd>#{escape_content(content)}</kbd>)
        end

        def render_inline_samp(_type, content, _node)
          %Q(<samp>#{escape_content(content)}</samp>)
        end

        def render_inline_var(_type, content, _node)
          %Q(<var>#{escape_content(content)}</var>)
        end

        def render_inline_sup(_type, content, _node)
          %Q(<sup>#{escape_content(content)}</sup>)
        end

        def render_inline_sub(_type, content, _node)
          %Q(<sub>#{escape_content(content)}</sub>)
        end

        def render_inline_del(_type, content, _node)
          %Q(<del>#{escape_content(content)}</del>)
        end

        def render_inline_ins(_type, content, _node)
          %Q(<ins>#{escape_content(content)}</ins>)
        end

        def render_inline_u(_type, content, _node)
          %Q(<u>#{escape_content(content)}</u>)
        end

        def render_inline_br(_type, _content, _node)
          '<br />'
        end

        def render_inline_raw(_type, content, node)
          if node.args && node.args.first
            format = node.args.first
            if format == 'html'
              content
            else
              '' # Ignore raw content for other formats
            end
          else
            content
          end
        end

        def render_inline_chap(_type, content, node)
          if node.args && node.args.first
            node.args.first
            # Simple chapter reference
          end
          escape_content(content)
        end

        def render_inline_title(_type, content, _node)
          %Q(<span class="title">#{escape_content(content)}</span>)
        end

        def render_inline_chapref(_type, content, _node)
          escape_content(content)
        end

        def render_inline_list(_type, content, _node)
          escape_content(content)
        end

        def render_inline_img(_type, content, _node)
          escape_content(content)
        end

        def render_inline_table(_type, content, _node)
          escape_content(content)
        end

        def render_inline_fn(_type, content, node)
          if node.args && node.args.first
            fn_id = node.args.first
            %Q(<a id="fnb-#{fn_id}" href="#fn-#{fn_id}" class="noteref">*#{content}</a>)
          else
            escape_content(content)
          end
        end

        def render_inline_kw(_type, content, node)
          if node.args && node.args.length >= 2
            word = node.args[0]
            alt = node.args[1]
            %Q(<b class="kw">#{escape_content(word)}</b>（#{escape_content(alt)}）)
          else
            %Q(<b class="kw">#{escape_content(content)}</b>)
          end
        end

        def render_inline_bou(_type, content, _node)
          %Q(<span class="bou">#{escape_content(content)}</span>)
        end

        def render_inline_ami(_type, content, _node)
          %Q(<span class="ami">#{escape_content(content)}</span>)
        end

        def render_inline_href(_type, content, node)
          args = node.args || []
          if args.length >= 2
            url = escape_content(args[0])
            text = args[1]
            %Q(<a href="#{url}" class="link">#{text}</a>)
          else
            %Q(<a href="#{content}" class="link">#{content}</a>)
          end
        end

        def render_inline_url(_type, content, _node)
          %Q(<a href="#{escape_content(content)}">#{content}</a>)
        end

        def render_inline_ruby(_type, content, node)
          if node.args && node.args.length >= 2
            base = node.args[0]
            ruby = node.args[1]
            %Q(<ruby>#{escape_content(base)}<rt>#{escape_content(ruby)}</rt></ruby>)
          else
            escape_content(content)
          end
        end

        def render_inline_m(_type, content, _node)
          %Q(<span class="math">#{escape_content(content)}</span>)
        end

        def render_inline_idx(_type, content, _node)
          %Q(<a id="idx-#{content.tr(' ', '-')}"></a>#{escape_content(content)})
        end

        def render_inline_hidx(_type, content, _node)
          %Q(<a id="hidx-#{content.tr(' ', '-')}"></a>)
        end

        def render_inline_comment(_type, content, _node)
          if @book&.config&.[]('draft')
            %Q(<span class="draft-comment">#{escape_content(content)}</span>)
          else
            ''
          end
        end

        def render_inline_hd(_type, content, _node)
          %Q(<span class="headline-ref">#{escape_content(content)}</span>)
        end

        def render_inline_sec(_type, content, _node)
          %Q(<span class="section-ref">#{escape_content(content)}</span>)
        end

        def render_inline_secref(_type, content, _node)
          %Q(<span class="section-ref">#{escape_content(content)}</span>)
        end

        def render_inline_labelref(_type, content, _node)
          %Q(<span class="label-ref">#{escape_content(content)}</span>)
        end

        def render_inline_ref(_type, content, _node)
          %Q(<span class="label-ref">#{escape_content(content)}</span>)
        end

        def render_inline_w(_type, content, _node)
          # Dictionary lookup for word substitution
          dictionary = @book&.config&.[]('dictionary') || {}
          translated = dictionary[content]
          if translated
            escape_content(translated)
          else
            # Warn if logger is available
            @renderer.warn("word not bound: #{content}") if @renderer.respond_to?(:warn)
            escape_content("[missing word: #{content}]")
          end
        end

        def render_inline_wb(_type, content, _node)
          # Dictionary lookup with bold formatting
          dictionary = @book&.config&.[]('dictionary') || {}
          word_content = dictionary[content] || "[missing word: #{content}]"
          %Q(<b>#{escape_content(word_content)}</b>)
        end

        # Helper method to escape content
        def escape_content(str)
          escape(str)
        end
      end
    end
  end
end
