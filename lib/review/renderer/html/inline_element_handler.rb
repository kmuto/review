# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'digest'

module ReVIEW
  module Renderer
    module Html
      # Inline element handler for HTML rendering
      # Uses InlineContext for shared logic
      class InlineElementHandler
        def initialize(inline_context)
          @ctx = inline_context
        end

        # === Pure inline elements (simple HTML wrapping) ===

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

        # === Logic-dependent inline elements (use InlineContext) ===

        def render_inline_chap(_type, _content, node)
          id = node.args.first
          chapter_num = @ctx.chapter_number(id)
          @ctx.build_chapter_link(id, chapter_num)
        end

        def render_inline_chapref(_type, _content, node)
          id = node.args.first
          display_str = @ctx.chapter_display_string(id)
          @ctx.build_chapter_link(id, display_str)
        end

        def render_inline_title(_type, _content, node)
          id = node.args.first
          title = @ctx.chapter_title(id)
          @ctx.build_chapter_link(id, title)
        end

        def render_inline_fn(_type, _content, node)
          fn_id = node.args.first
          fn_number = @ctx.footnote_number(fn_id)
          @ctx.build_footnote_link(fn_id, fn_number)
        end

        def render_inline_kw(_type, content, node)
          if node.args.length >= 2
            @ctx.build_keyword_with_index(node.args[0], alt: node.args[1].strip)
          elsif node.args.length == 1
            @ctx.build_keyword_with_index(node.args[0])
          else
            @ctx.build_keyword_with_index(content)
          end
        end

        def render_inline_idx(_type, content, node)
          index_str = node.args.first || content
          content + @ctx.build_index_comment(index_str)
        end

        def render_inline_hidx(_type, _content, node)
          index_str = node.args.first
          @ctx.build_index_comment(index_str)
        end

        def render_inline_href(_type, _content, node)
          args = node.args
          if args.length >= 2
            url = args[0]
            text = @ctx.escape_content(args[1])
            if url.start_with?('#')
              @ctx.build_anchor_link(url[1..-1], text)
            else
              @ctx.build_external_link(url, text)
            end
          elsif args.length >= 1
            url = args[0]
            escaped_url = @ctx.escape_content(url)
            if url.start_with?('#')
              @ctx.build_anchor_link(url[1..-1], escaped_url)
            else
              @ctx.build_external_link(url, escaped_url)
            end
          else
            content
          end
        end

        def render_inline_ruby(_type, _content, node)
          if node.args.length >= 2
            @ctx.build_ruby(node.args[0], node.args[1])
          else
            content
          end
        end

        # === Format-dependent rendering ===

        def render_inline_raw(_type, content, node)
          if node.args.first
            format = node.args.first
            @ctx.target_format?(format) ? content : ''
          else
            content
          end
        end

        def render_inline_embed(_type, content, node)
          if node.args.first
            formats, embed_content = @ctx.parse_embed_formats(node.args.first)
            if formats
              formats.include?('html') ? embed_content : ''
            else
              embed_content
            end
          else
            content
          end
        end

        # === Special cases that need raw args ===

        def render_inline_abbr(_type, content, _node)
          %Q(<abbr>#{content}</abbr>)
        end

        def render_inline_acronym(_type, content, _node)
          %Q(<acronym>#{content}</acronym>)
        end

        # === Reference inline elements ===

        def render_inline_list(_type, _content, node)
          ref_node = node.children.first
          unless ref_node.is_a?(ReVIEW::AST::ReferenceNode) && ref_node.resolved_data
            raise 'BUG: Reference should be resolved at AST construction time'
          end

          data = ref_node.resolved_data
          list_number = if data.chapter_number
                          "#{I18n.t('list')}#{I18n.t('format_number', [data.chapter_number, data.item_number])}"
                        else
                          "#{I18n.t('list')}#{I18n.t('format_number_without_chapter', [data.item_number])}"
                        end

          if @ctx.chapter_link_enabled?
            chapter_id = data.chapter_id || @ctx.chapter.id
            %Q(<span class="listref"><a href="./#{chapter_id}#{@ctx.extname}##{@ctx.normalize_id(data.item_id)}">#{list_number}</a></span>)
          else
            %Q(<span class="listref">#{list_number}</span>)
          end
        end

        def render_inline_table(_type, _content, node)
          ref_node = node.children.first
          unless ref_node.is_a?(ReVIEW::AST::ReferenceNode) && ref_node.resolved_data
            raise 'BUG: Reference should be resolved at AST construction time'
          end

          data = ref_node.resolved_data
          table_number = if data.chapter_number
                           "#{I18n.t('table')}#{I18n.t('format_number', [data.chapter_number, data.item_number])}"
                         else
                           "#{I18n.t('table')}#{I18n.t('format_number_without_chapter', [data.item_number])}"
                         end

          if @ctx.chapter_link_enabled?
            chapter_id = data.chapter_id || @ctx.chapter.id
            %Q(<span class="tableref"><a href="./#{chapter_id}#{@ctx.extname}##{@ctx.normalize_id(data.item_id)}">#{table_number}</a></span>)
          else
            %Q(<span class="tableref">#{table_number}</span>)
          end
        end

        def render_inline_img(_type, _content, node)
          ref_node = node.children.first
          unless ref_node.is_a?(ReVIEW::AST::ReferenceNode) && ref_node.resolved_data
            raise 'BUG: Reference should be resolved at AST construction time'
          end

          data = ref_node.resolved_data
          image_number = if data.chapter_number
                           "#{I18n.t('image')}#{I18n.t('format_number', [data.chapter_number, data.item_number])}"
                         else
                           "#{I18n.t('image')}#{I18n.t('format_number_without_chapter', [data.item_number])}"
                         end

          if @ctx.chapter_link_enabled?
            chapter_id = data.chapter_id || @ctx.chapter.id
            %Q(<span class="imgref"><a href="./#{chapter_id}#{@ctx.extname}##{@ctx.normalize_id(data.item_id)}">#{image_number}</a></span>)
          else
            %Q(<span class="imgref">#{image_number}</span>)
          end
        end

        # === Special inline elements ===

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
          # 縦中横用のtcy、uprightのCSSスタイルについては電書協ガイドラインを参照
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

        def render_inline_bib(_type, content, node)
          # Bibliography reference
          id = node.args.first || content
          begin
            number = @ctx.bibpaper_number(id)
            @ctx.build_bib_reference_link(id, number)
          rescue ReVIEW::KeyError
            %Q([#{id}])
          end
        end

        def render_inline_endnote(_type, _content, node)
          # Endnote reference
          ref_node = node.children.first
          unless ref_node.is_a?(ReVIEW::AST::ReferenceNode) && ref_node.resolved_data
            raise 'BUG: Reference should be resolved at AST construction time'
          end

          data = ref_node.resolved_data
          @ctx.build_endnote_link(data.item_id, data.item_number)
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
              @ctx.renderer.app_error 'not found math_ml'
              return %Q(<span class="equation">#{@ctx.escape(str)}</span>)
            end
            parser = MathML::LaTeX::Parser.new(symbol: MathML::Symbol::CharacterReference)
            # parser.parse returns MathML::Math object, need to convert to string
            %Q(<span class="equation">#{parser.parse(str, nil)}</span>)
          when 'mathjax'
            %Q(<span class="equation">\\( #{str.gsub('<', '\lt{}').gsub('>', '\gt{}').gsub('&', '&amp;')} \\)</span>)
          when 'imgmath'
            unless @img_math
              @ctx.renderer.app_error 'ImgMath not initialized'
              return %Q(<span class="equation">#{@ctx.escape(str)}</span>)
            end

            math_str = '$' + str + '$'
            key = Digest::SHA256.hexdigest(str)
            img_path = @img_math.defer_math_image(math_str, key)
            %Q(<span class="equation"><img src="#{img_path}" class="math_gen_#{key}" alt="#{@ctx.escape(str)}" /></span>)
          else
            %Q(<span class="equation">#{@ctx.escape(str)}</span>)
          end
        end

        def render_inline_sec(_type, _content, node)
          # Section number reference: @<sec>{id} or @<sec>{chapter|id}
          ref_node = node.children.first
          unless ref_node.is_a?(ReVIEW::AST::ReferenceNode) && ref_node.resolved_data
            raise 'BUG: Reference should be resolved at AST construction time'
          end

          data = ref_node.resolved_data
          n = data.headline_number
          chapter_num = data.chapter_number

          # Build full section number including chapter number
          full_number = if n.present? && chapter_num && @ctx.over_secnolevel?(n)
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
          %Q(<a target='#{@ctx.escape_content(idref)}'>「#{ReVIEW::I18n.t('label_marker')}#{@ctx.escape_content(idref)}」</a>)
        end

        def render_inline_ref(type, content, node)
          render_inline_labelref(type, content, node)
        end

        def render_inline_eq(_type, _content, node)
          # Equation reference
          ref_node = node.children.first
          unless ref_node.is_a?(ReVIEW::AST::ReferenceNode) && ref_node.resolved_data
            raise 'BUG: Reference should be resolved at AST construction time'
          end

          data = ref_node.resolved_data
          equation_number = if data.chapter_number
                              %Q(#{ReVIEW::I18n.t('equation')}#{ReVIEW::I18n.t('format_number', [data.chapter_number, data.item_number])})
                            else
                              %Q(#{ReVIEW::I18n.t('equation')}#{ReVIEW::I18n.t('format_number_without_chapter', [data.item_number])})
                            end

          if @ctx.config['chapterlink']
            chapter_id = data.chapter_id || @ctx.chapter.id
            %Q(<span class="eqref"><a href="./#{chapter_id}#{@ctx.extname}##{@ctx.normalize_id(data.item_id)}">#{equation_number}</a></span>)
          else
            %Q(<span class="eqref">#{equation_number}</span>)
          end
        end

        def render_inline_hd(_type, _content, node)
          # Headline reference: @<hd>{id} or @<hd>{chapter|id}
          ref_node = node.children.first
          unless ref_node.is_a?(ReVIEW::AST::ReferenceNode) && ref_node.resolved_data
            raise 'BUG: Reference should be resolved at AST construction time'
          end

          data = ref_node.resolved_data
          n = data.headline_number
          chapter_num = data.chapter_number

          # Render caption with inline markup
          caption_html = if data.caption_node
                           @ctx.render_children(data.caption_node)
                         else
                           data.caption_text
                         end

          # Build full section number including chapter number
          full_number = if n.present? && chapter_num && @ctx.over_secnolevel?(n)
                          ([chapter_num] + n).join('.')
                        end

          str = if full_number
                  ReVIEW::I18n.t('hd_quote', [full_number, caption_html])
                else
                  ReVIEW::I18n.t('hd_quote_without_number', caption_html)
                end

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
          unless ref_node.is_a?(ReVIEW::AST::ReferenceNode) && ref_node.resolved_data
            raise 'BUG: Reference should be resolved at AST construction time'
          end

          data = ref_node.resolved_data

          # Render caption with inline markup
          caption_html = if data.caption_node
                           @ctx.render_children(data.caption_node)
                         else
                           @ctx.escape_content(data.caption_text)
                         end

          anchor = "column-#{data.item_number}"
          column_text = ReVIEW::I18n.t('column', caption_html)

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
          unless ref_node.is_a?(ReVIEW::AST::ReferenceNode) && ref_node.resolved_data
            raise 'BUG: Reference should be resolved at AST construction time'
          end

          data = ref_node.resolved_data

          # Render caption with inline markup
          title_html = if data.caption_node
                         @ctx.render_children(data.caption_node)
                       else
                         @ctx.escape_content(data.caption_text)
                       end

          if @ctx.config['chapterlink']
            n = data.headline_number
            chapter_num = data.chapter_number
            full_number = ([chapter_num] + n).join('.')
            anchor = 'h' + full_number.tr('.', '-')

            # Get target chapter ID for link
            chapter_id = data.chapter_id || @ctx.chapter.id
            %Q(<a href="#{chapter_id}#{@ctx.extname}##{anchor}">#{title_html}</a>)
          else
            title_html
          end
        end
      end
    end
  end
end
