# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'digest'
require 'review/htmlutils'
require 'review/html_escape_utils'

module ReVIEW
  module Renderer
    module Html
      # Inline element handler for HTML rendering
      # Uses InlineContext for shared logic
      class InlineElementHandler
        include ReVIEW::HTMLUtils
        include ReVIEW::HtmlEscapeUtils
        include ReVIEW::Loggable

        def initialize(inline_context)
          @ctx = inline_context
          @img_math = @ctx.img_math
          @logger = ReVIEW.logger
        end

        def render_inline_b(_type, content, _node)
          %Q(<b>#{content}</b>)
        end

        def render_inline_strong(_type, content, _node)
          %Q(<strong>#{content}</strong>)
        end

        def render_inline_i(_type, content, _node)
          %Q(<i>#{content}</i>)
        end

        def render_inline_em(_type, content, _node)
          %Q(<em>#{content}</em>)
        end

        def render_inline_code(_type, content, _node)
          %Q(<code class="inline-code tt">#{content}</code>)
        end

        def render_inline_tt(_type, content, _node)
          %Q(<code class="tt">#{content}</code>)
        end

        def render_inline_ttb(_type, content, _node)
          %Q(<code class="tt"><b>#{content}</b></code>)
        end

        def render_inline_tti(_type, content, _node)
          %Q(<code class="tt"><i>#{content}</i></code>)
        end

        def render_inline_kbd(_type, content, _node)
          %Q(<kbd>#{content}</kbd>)
        end

        def render_inline_samp(_type, content, _node)
          %Q(<samp>#{content}</samp>)
        end

        def render_inline_var(_type, content, _node)
          %Q(<var>#{content}</var>)
        end

        def render_inline_sup(_type, content, _node)
          %Q(<sup>#{content}</sup>)
        end

        def render_inline_sub(_type, content, _node)
          %Q(<sub>#{content}</sub>)
        end

        def render_inline_del(_type, content, _node)
          %Q(<del>#{content}</del>)
        end

        def render_inline_ins(_type, content, _node)
          %Q(<ins>#{content}</ins>)
        end

        def render_inline_u(_type, content, _node)
          %Q(<u>#{content}</u>)
        end

        def render_inline_br(_type, _content, _node)
          '<br />'
        end

        def render_inline_bou(_type, content, _node)
          %Q(<span class="bou">#{content}</span>)
        end

        def render_inline_ami(_type, content, _node)
          %Q(<span class="ami">#{content}</span>)
        end

        def render_inline_big(_type, content, _node)
          %Q(<big>#{content}</big>)
        end

        def render_inline_small(_type, content, _node)
          %Q(<small>#{content}</small>)
        end

        def render_inline_balloon(_type, content, _node)
          %Q(<span class="balloon">#{content}</span>)
        end

        def render_inline_cite(_type, content, _node)
          %Q(<cite>#{content}</cite>)
        end

        def render_inline_dfn(_type, content, _node)
          %Q(<dfn>#{content}</dfn>)
        end

        def render_inline_chap(_type, _content, node)
          ref_node = node.children.first
          unless ref_node.reference_node? && ref_node.resolved?
            raise 'BUG: Reference should be resolved at AST construction time'
          end

          data = ref_node.resolved_data
          chapter_num = data.to_number_text
          build_chapter_link(data.item_id, chapter_num)
        end

        def render_inline_chapref(_type, _content, node)
          ref_node = node.children.first
          unless ref_node.reference_node? && ref_node.resolved?
            raise 'BUG: Reference should be resolved at AST construction time'
          end

          data = ref_node.resolved_data
          display_str = data.to_text
          build_chapter_link(data.item_id, display_str)
        end

        def render_inline_title(_type, _content, node)
          ref_node = node.children.first
          unless ref_node.reference_node? && ref_node.resolved?
            raise 'BUG: Reference should be resolved at AST construction time'
          end

          data = ref_node.resolved_data
          title = data.to_title_text
          build_chapter_link(data.item_id, title)
        end

        def render_inline_fn(_type, _content, node)
          # Footnote reference
          ref_node = node.children.first
          unless ref_node.reference_node? && ref_node.resolved?
            raise 'BUG: Reference should be resolved at AST construction time'
          end

          data = ref_node.resolved_data
          build_footnote_link(data.item_id, data.item_number)
        end

        def render_inline_kw(_type, content, node)
          if node.args.length >= 2
            build_keyword_with_index(node.args[0], alt: node.args[1].strip)
          elsif node.args.length == 1
            build_keyword_with_index(node.args[0])
          else
            build_keyword_with_index(content)
          end
        end

        def render_inline_idx(_type, content, node)
          index_str = node.args.first || content
          content + build_index_comment(index_str)
        end

        def render_inline_hidx(_type, _content, node)
          index_str = node.args.first
          build_index_comment(index_str)
        end

        def render_inline_href(_type, _content, node)
          args = node.args
          if args.length >= 2
            url = args[0]
            text = escape_content(args[1])
            if url.start_with?('#')
              build_anchor_link(url[1..-1], text)
            else
              build_external_link(url, text)
            end
          elsif args.length >= 1
            url = args[0]
            escaped_url = escape_content(url)
            if url.start_with?('#')
              build_anchor_link(url[1..-1], escaped_url)
            else
              build_external_link(url, escaped_url)
            end
          else
            content
          end
        end

        def render_inline_ruby(_type, content, node)
          if node.args.length >= 2
            build_ruby(node.args[0], node.args[1])
          else
            content
          end
        end

        def render_inline_raw(_type, _content, node)
          node.targeted_for?('html') ? (node.content || '') : ''
        end

        def render_inline_embed(_type, _content, node)
          node.targeted_for?('html') ? (node.content || '') : ''
        end

        def render_inline_abbr(_type, content, _node)
          %Q(<abbr>#{content}</abbr>)
        end

        def render_inline_acronym(_type, content, _node)
          %Q(<acronym>#{content}</acronym>)
        end

        def render_inline_list(_type, _content, node)
          ref_node = node.children.first
          unless ref_node.reference_node? && ref_node.resolved?
            raise 'BUG: Reference should be resolved at AST construction time'
          end

          data = ref_node.resolved_data
          text = @ctx.text_formatter.format_reference_text(:list, data)
          wrap_reference_with_html(text, data, 'listref')
        end

        def render_inline_table(_type, _content, node)
          ref_node = node.children.first
          unless ref_node.reference_node? && ref_node.resolved?
            raise 'BUG: Reference should be resolved at AST construction time'
          end

          data = ref_node.resolved_data
          text = @ctx.text_formatter.format_reference_text(:table, data)
          wrap_reference_with_html(text, data, 'tableref')
        end

        def render_inline_img(_type, _content, node)
          ref_node = node.children.first
          unless ref_node.reference_node? && ref_node.resolved?
            raise 'BUG: Reference should be resolved at AST construction time'
          end

          data = ref_node.resolved_data
          text = @ctx.text_formatter.format_reference_text(:image, data)
          wrap_reference_with_html(text, data, 'imgref')
        end

        def render_inline_comment(_type, content, _node)
          if @ctx.config['draft']
            %Q(<span class="draft-comment">#{content}</span>)
          else
            ''
          end
        end

        def render_inline_w(_type, content, _node)
          # Content should already be resolved by ReferenceResolver
          content
        end

        def render_inline_wb(_type, content, _node)
          # Content should already be resolved by ReferenceResolver
          %Q(<b>#{content}</b>)
        end

        def render_inline_dtp(_type, content, _node)
          "<?dtp #{content} ?>"
        end

        def render_inline_recipe(_type, content, _node)
          %Q(<span class="recipe">「#{content}」</span>)
        end

        def render_inline_uchar(_type, content, _node)
          %Q(&#x#{content};)
        end

        def render_inline_tcy(_type, content, _node)
          style = 'tcy'
          if content.size == 1 && content.match(/[[:ascii:]]/)
            style = 'upright'
          end
          %Q(<span class="#{style}">#{content}</span>)
        end

        def render_inline_pageref(_type, content, _node)
          # Page reference is unsupported in HTML
          content
        end

        def render_inline_icon(_type, content, node)
          # Icon is an image reference
          id = node.args.first || content
          begin
            @ctx.build_icon_html(id)
          rescue ReVIEW::KeyError, NoMethodError
            warn "image not bound: #{id}"
            %Q(<pre>missing image: #{id}</pre>)
          end
        end

        def render_inline_bib(_type, _content, node)
          ref_node = node.children.first
          unless ref_node.reference_node? && ref_node.resolved?
            raise 'BUG: Reference should be resolved at AST construction time'
          end

          data = ref_node.resolved_data
          bib_id = data.item_id
          bib_number = data.item_number
          @ctx.build_bib_reference_link(bib_id, bib_number)
        end

        def render_inline_endnote(_type, _content, node)
          # Endnote reference
          ref_node = node.children.first
          unless ref_node.reference_node? && ref_node.resolved?
            raise 'BUG: Reference should be resolved at AST construction time'
          end

          data = ref_node.resolved_data
          build_endnote_link(data.item_id, data.item_number)
        end

        def render_inline_m(_type, content, node)
          # Math/equation rendering
          # Get raw string from node args (content is already escaped)
          str = node.args.first || content

          # Use 'equation' class like HTMLBuilder
          case @ctx.config['math_format']
          when 'mathml'
            begin
              require 'math_ml'
              require 'math_ml/symbol/character_reference'
            rescue LoadError
              app_error 'not found math_ml'
              return %Q(<span class="equation">#{escape(str)}</span>)
            end
            parser = MathML::LaTeX::Parser.new(symbol: MathML::Symbol::CharacterReference)
            # parser.parse returns MathML::Math object, need to convert to string
            %Q(<span class="equation">#{parser.parse(str, nil)}</span>)
          when 'mathjax'
            %Q(<span class="equation">\\( #{str.gsub('<', '\lt{}').gsub('>', '\gt{}').gsub('&', '&amp;')} \\)</span>)
          when 'imgmath'
            unless @img_math
              app_error 'ImgMath not initialized'
              return %Q(<span class="equation">#{escape(str)}</span>)
            end

            math_str = '$' + str + '$'
            key = Digest::SHA256.hexdigest(str)
            img_path = @img_math.defer_math_image(math_str, key)
            %Q(<span class="equation"><img src="#{img_path}" class="math_gen_#{key}" alt="#{escape(str)}" /></span>)
          else
            %Q(<span class="equation">#{escape(str)}</span>)
          end
        end

        def render_inline_sec(_type, _content, node)
          # Section number reference: @<sec>{id} or @<sec>{chapter|id}
          ref_node = node.children.first
          unless ref_node.reference_node? && ref_node.resolved?
            raise 'BUG: Reference should be resolved at AST construction time'
          end

          data = ref_node.resolved_data
          n = data.headline_number
          chapter_num = @ctx.text_formatter.format_chapter_number_short(data.chapter_number, data.chapter_type)

          # Build full section number including chapter number
          full_number = if n.present? && chapter_num && !chapter_num.to_s.empty? && @ctx.over_secnolevel?(n)
                          ([chapter_num] + n).join('.')
                        else
                          ''
                        end

          if @ctx.config['chapterlink'] && full_number.present?
            # Get target chapter ID for link
            chapter_id = data.chapter_id || @ctx.chapter.id
            anchor = 'h' + full_number.tr('.', '-')
            %Q(<a href="#{chapter_id}#{@ctx.extname}##{anchor}">#{full_number}</a>)
          else
            full_number
          end
        end

        def render_inline_secref(type, content, node)
          render_inline_hd(type, content, node)
        end

        def render_inline_labelref(_type, content, node)
          # Label reference: @<labelref>{id}
          # This should match HTMLBuilder's inline_labelref behavior
          idref = node.target_item_id || content
          marker = @ctx.text_formatter.format_label_marker(idref)
          %Q(<a target='#{escape_content(idref)}'>「#{marker}」</a>)
        end

        def render_inline_ref(type, content, node)
          render_inline_labelref(type, content, node)
        end

        def render_inline_eq(_type, _content, node)
          # Equation reference
          ref_node = node.children.first
          unless ref_node.reference_node? && ref_node.resolved?
            raise 'BUG: Reference should be resolved at AST construction time'
          end

          data = ref_node.resolved_data
          text = @ctx.text_formatter.format_reference_text(:equation, data)
          wrap_reference_with_html(text, data, 'eqref')
        end

        def render_inline_hd(_type, _content, node)
          # Headline reference: @<hd>{id} or @<hd>{chapter|id}
          ref_node = node.children.first
          unless ref_node.reference_node? && ref_node.resolved?
            raise 'BUG: Reference should be resolved at AST construction time'
          end

          data = ref_node.resolved_data
          n = data.headline_number
          chapter_num = @ctx.text_formatter.format_chapter_number_short(data.chapter_number, data.chapter_type)

          # Render caption with inline markup
          caption_html = if data.caption_node
                           @ctx.render_children(data.caption_node)
                         else
                           data.caption_text
                         end

          # Build full section number including chapter number
          full_number = if n.present? && chapter_num && !chapter_num.to_s.empty? && @ctx.over_secnolevel?(n)
                          ([chapter_num] + n).join('.')
                        end

          str = @ctx.text_formatter.format_headline_quote(full_number, caption_html)

          if @ctx.config['chapterlink'] && full_number
            # Get target chapter ID for link
            chapter_id = data.chapter_id || @ctx.chapter.id
            anchor = 'h' + full_number.tr('.', '-')
            %Q(<a href="#{chapter_id}#{@ctx.extname}##{anchor}">#{str}</a>)
          else
            str
          end
        end

        def render_inline_column(_type, _content, node)
          # Column reference: @<column>{id} or @<column>{chapter|id}
          ref_node = node.children.first
          unless ref_node.reference_node? && ref_node.resolved?
            raise 'BUG: Reference should be resolved at AST construction time'
          end

          data = ref_node.resolved_data

          # Render caption with inline markup
          caption_html = if data.caption_node
                           @ctx.render_children(data.caption_node)
                         else
                           escape_content(data.caption_text)
                         end

          anchor = "column-#{data.item_number}"
          column_text = @ctx.text_formatter.format_column_label(caption_html)

          if @ctx.config['chapterlink']
            chapter_id = data.chapter_id || @ctx.chapter.id
            %Q(<a href="#{chapter_id}#{@ctx.extname}##{anchor}" class="columnref">#{column_text}</a>)
          else
            column_text
          end
        end

        def render_inline_sectitle(_type, _content, node)
          # Section title reference
          ref_node = node.children.first
          unless ref_node.reference_node? && ref_node.resolved?
            raise 'BUG: Reference should be resolved at AST construction time'
          end

          data = ref_node.resolved_data

          # Render caption with inline markup
          title_html = if data.caption_node
                         @ctx.render_children(data.caption_node)
                       else
                         escape_content(data.caption_text)
                       end

          if @ctx.config['chapterlink']
            n = data.headline_number
            chapter_num = @ctx.text_formatter.format_chapter_number_short(data.chapter_number, data.chapter_type)
            full_number = ([chapter_num] + n).join('.')
            anchor = 'h' + full_number.tr('.', '-')

            # Get target chapter ID for link
            chapter_id = data.chapter_id || @ctx.chapter.id
            %Q(<a href="#{chapter_id}#{@ctx.extname}##{anchor}">#{title_html}</a>)
          else
            title_html
          end
        end

        private

        def target_format?(format_name)
          format_name.to_s == 'html'
        end

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

        def build_ruby(base, ruby_text)
          %Q(<ruby>#{escape_content(base)}<rt>#{escape_content(ruby_text)}</rt></ruby>)
        end

        def build_anchor_link(anchor_id, content, css_class: 'link')
          %Q(<a href="##{normalize_id(anchor_id)}" class="#{css_class}">#{content}</a>)
        end

        def build_external_link(url, content, css_class: 'link')
          %Q(<a href="#{escape_content(url)}" class="#{css_class}">#{content}</a>)
        end

        def build_footnote_link(fn_id, number)
          if @ctx.epub3?
            %Q(<a id="fnb-#{normalize_id(fn_id)}" href="#fn-#{normalize_id(fn_id)}" class="noteref" epub:type="noteref">#{@ctx.text_formatter.format_footnote_mark(number)}</a>)
          else
            %Q(<a id="fnb-#{normalize_id(fn_id)}" href="#fn-#{normalize_id(fn_id)}" class="noteref">*#{number}</a>)
          end
        end

        def build_chapter_link(chapter_id, content)
          if @ctx.chapter_link_enabled?
            %Q(<a href="./#{chapter_id}#{@ctx.extname}">#{content}</a>)
          else
            content
          end
        end

        def build_endnote_link(endnote_id, number)
          if @ctx.epub3?
            %Q(<a id="endnoteb-#{normalize_id(endnote_id)}" href="#endnote-#{normalize_id(endnote_id)}" class="noteref" epub:type="noteref">#{@ctx.text_formatter.format_endnote_mark(number)}</a>)
          else
            %Q(<a id="endnoteb-#{normalize_id(endnote_id)}" href="#endnote-#{normalize_id(endnote_id)}" class="noteref">#{number}</a>)
          end
        end

        # Wrap reference text with HTML decoration (span and optional link)
        # @param text [String] Plain text reference (e.g., "図1.1")
        # @param data [ResolvedData] Resolved reference data
        # @param css_class [String] CSS class name (e.g., 'imgref', 'tableref', 'listref', 'eqref')
        # @return [String] HTML with span and optional link
        def wrap_reference_with_html(text, data, css_class)
          escaped_text = escape_content(text)

          return %Q(<span class="#{css_class}">#{escaped_text}</span>) unless @ctx.config['chapterlink']

          # Build link with chapter_id and item_id
          chapter_id = data.chapter_id || @ctx.chapter&.id
          extname = ".#{@ctx.config['htmlext'] || 'html'}"
          %Q(<span class="#{css_class}"><a href="./#{chapter_id}#{extname}##{normalize_id(data.item_id)}">#{escaped_text}</a></span>)
        end
      end
    end
  end
end
