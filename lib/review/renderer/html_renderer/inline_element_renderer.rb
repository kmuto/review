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
        include ReVIEW::Loggable

        def initialize(renderer, book:, chapter:, rendering_context:)
          @renderer = renderer
          @book = book
          @chapter = chapter
          @rendering_context = rendering_context
          @logger = ReVIEW.logger
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

        def render_inline_ttb(_type, content, _node)
          %Q(<code class="tt"><b>#{escape_content(content)}</b></code>)
        end

        def render_inline_tti(_type, content, _node)
          %Q(<code class="tt"><i>#{escape_content(content)}</i></code>)
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

        def render_inline_list(_type, content, node)
          # Delegate to renderer's render_list method for proper reference handling
          @renderer.render_list(content, node)
        end

        def render_inline_img(_type, content, node)
          # Delegate to renderer's render_img method for proper reference handling
          @renderer.render_img(content, node)
        end

        def render_inline_table(_type, content, node)
          # Delegate to renderer's render_inline_table method for proper reference handling
          @renderer.render_inline_table(content, node)
        end

        def render_inline_fn(_type, content, node)
          if node.args && node.args.first
            fn_id = node.args.first
            # Check epubversion for consistent output with HTMLBuilder
            if @book&.config&.[]('epubversion').to_i == 3
              %Q(<a id="fnb-#{normalize_id(fn_id)}" href="#fn-#{normalize_id(fn_id)}" class="noteref" epub:type="noteref">#{I18n.t('html_footnote_refmark', content)}</a>)
            else
              %Q(<a id="fnb-#{normalize_id(fn_id)}" href="#fn-#{normalize_id(fn_id)}" class="noteref">*#{content}</a>)
            end
          else
            escape_content(content)
          end
        end

        def render_inline_kw(_type, content, node)
          if node.args && node.args.length >= 2
            word = escape_content(node.args[0])
            alt = escape_content(node.args[1].strip)
            # Format like HTMLBuilder: word + space + parentheses with alt inside <b> tag
            text = "#{word} (#{alt})"
            # IDX comment uses only the word, like HTMLBuilder
            %Q(<b class="kw">#{text}</b><!-- IDX:#{word} -->)
          else
            %Q(<b class="kw">#{escape_content(content)}</b><!-- IDX:#{escape_content(content)} -->)
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
            url = args[0]
            text = args[1]
            # Handle internal references (URLs starting with #)
            if url.start_with?('#')
              anchor = url.sub(/\A#/, '')
              %Q(<a href="##{escape_content(anchor)}" class="link">#{escape_content(text)}</a>)
            else
              %Q(<a href="#{escape_content(url)}" class="link">#{escape_content(text)}</a>)
            end
          elsif content.start_with?('#')
            # Handle internal references (URLs starting with #)
            anchor = content.sub(/\A#/, '')
            %Q(<a href="##{escape_content(anchor)}" class="link">#{escape_content(content)}</a>)
          else
            %Q(<a href="#{escape_content(content)}" class="link">#{escape_content(content)}</a>)
          end
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

        def render_inline_idx(_type, content, node)
          # Get the raw index string from args (before any processing)
          index_str = node.args&.first || content
          # Create ID from the hierarchical index path (replace <<>> with -)
          index_id = normalize_id(index_str.gsub('<<>>', '-'))
          %Q(<a id="idx-#{index_id}"></a>#{escape_content(content)})
        end

        def render_inline_hidx(_type, content, node)
          # Get the raw index string from args (before any processing)
          index_str = node.args&.first || content
          # Create ID from the hierarchical index path (replace <<>> with -)
          index_id = normalize_id(index_str.gsub('<<>>', '-'))
          %Q(<a id="hidx-#{index_id}"></a>)
        end

        def render_inline_comment(_type, content, _node)
          if @book.config['draft']
            %Q(<span class="draft-comment">#{escape_content(content)}</span>)
          else
            ''
          end
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
          # Content should already be resolved by ReferenceResolver
          escape_content(content)
        end

        def render_inline_wb(_type, content, _node)
          # Content should already be resolved by ReferenceResolver
          %Q(<b>#{escape_content(content)}</b>)
        end

        def render_inline_abbr(_type, content, _node)
          %Q(<abbr>#{escape_content(content)}</abbr>)
        end

        def render_inline_acronym(_type, content, _node)
          %Q(<acronym>#{escape_content(content)}</acronym>)
        end

        def render_inline_cite(_type, content, _node)
          %Q(<cite>#{escape_content(content)}</cite>)
        end

        def render_inline_dfn(_type, content, _node)
          %Q(<dfn>#{escape_content(content)}</dfn>)
        end

        def render_inline_big(_type, content, _node)
          %Q(<big>#{escape_content(content)}</big>)
        end

        def render_inline_small(_type, content, _node)
          %Q(<small>#{escape_content(content)}</small>)
        end

        def render_inline_dtp(_type, content, _node)
          "<?dtp #{content} ?>"
        end

        def render_inline_recipe(_type, content, _node)
          %Q(<span class="recipe">「#{escape_content(content)}」</span>)
        end

        def render_inline_icon(_type, content, node)
          # Icon is an image reference
          id = node.args&.first || content
          begin
            %Q(<img src="#{@chapter.image(id).path.sub(%r{\A\./}, '')}" alt="[#{id}]" />)
          rescue KeyError, NoMethodError
            warn "image not bound: #{id}"
            %Q(<pre>missing image: #{id}</pre>)
          end
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
          %Q(<span class="#{style}">#{escape_content(content)}</span>)
        end

        def render_inline_balloon(_type, content, _node)
          %Q(<span class="balloon">#{escape_content(content)}</span>)
        end

        def render_inline_bib(_type, content, node)
          # Bibliography reference
          id = node.args&.first || content
          begin
            bib_file = @book.bib_file.gsub(/\.re\Z/, ".#{@book.config['htmlext'] || 'html'}")
            number = @chapter.bibpaper(id).number
            %Q(<a href="#{bib_file}#bib-#{normalize_id(id)}">[#{number}]</a>)
          rescue KeyError
            %Q([#{id}])
          end
        end

        def render_inline_endnote(_type, content, node)
          # Endnote reference
          id = node.args&.first || content
          begin
            number = @chapter.endnote(id).number
            %Q(<a id="endnoteb-#{normalize_id(id)}" href="#endnote-#{normalize_id(id)}" class="noteref" epub:type="noteref">#{I18n.t('html_endnote_refmark', number)}</a>)
          rescue KeyError
            %Q(<a href="#endnote-#{normalize_id(id)}" class="noteref">#{content}</a>)
          end
        end

        def render_inline_eq(_type, content, node)
          # Equation reference
          id = node.args&.first || content
          begin
            chapter, extracted_id = extract_chapter_id(id)
            equation_number = if get_chap(chapter)
                                %Q(#{I18n.t('equation')}#{I18n.t('format_number', [get_chap(chapter), chapter.equation(extracted_id).number])})
                              else
                                %Q(#{I18n.t('equation')}#{I18n.t('format_number_without_chapter', [chapter.equation(extracted_id).number])})
                              end

            if @book.config['chapterlink']
              %Q(<span class="eqref"><a href="./#{chapter.id}#{extname}##{normalize_id(extracted_id)}">#{equation_number}</a></span>)
            else
              %Q(<span class="eqref">#{equation_number}</span>)
            end
          rescue KeyError
            %Q(<span class="eqref">#{content}</span>)
          end
        end

        def render_inline_hd(_type, content, node)
          # Headline reference: @<hd>{id} or @<hd>{chapter|id}
          id = node.args&.first || content
          m = /\A([^|]+)\|(.+)/.match(id)

          chapter = if m && m[1]
                      @book.contents.detect { |chap| chap.id == m[1] }
                    else
                      @chapter
                    end

          headline_id = m ? m[2] : id

          begin
            return '' unless chapter

            n = chapter.headline_index.number(headline_id)
            caption = chapter.headline(headline_id).caption

            str = if n.present? && chapter.number && over_secnolevel?(n, chapter)
                    I18n.t('hd_quote', [n, escape_content(caption)])
                  else
                    I18n.t('hd_quote_without_number', escape_content(caption))
                  end

            if @book.config['chapterlink']
              anchor = 'h' + n.tr('.', '-')
              %Q(<a href="#{chapter.id}#{extname}##{anchor}">#{str}</a>)
            else
              str
            end
          rescue KeyError
            escape_content(content)
          end
        end

        def render_inline_column(_type, content, node)
          # Column reference: @<column>{id} or @<column>{chapter|id}
          id = node.args&.first || content
          m = /\A([^|]+)\|(.+)/.match(id)

          chapter = if m && m[1]
                      @book.chapters.detect { |chap| chap.id == m[1] }
                    else
                      @chapter
                    end

          column_id = m ? m[2] : id

          begin
            return '' unless chapter

            column_caption = chapter.column(column_id).caption
            column_number = chapter.column(column_id).number

            if @book.config['chapterlink']
              %Q(<a href="#{chapter.id}#{extname}#column-#{column_number}" class="columnref">#{I18n.t('column', escape_content(column_caption))}</a>)
            else
              I18n.t('column', escape_content(column_caption))
            end
          rescue KeyError
            escape_content(content)
          end
        end

        def render_inline_sectitle(_type, content, node)
          # Section title reference
          id = node.args&.first || content
          begin
            if @book.config['chapterlink']
              chap, id2 = extract_chapter_id(id)
              anchor = 'h' + chap.headline_index.number(id2).tr('.', '-')
              title = chap.headline(id2).caption
              %Q(<a href="#{chap.id}#{extname}##{anchor}">#{escape_content(title)}</a>)
            else
              escape_content(content)
            end
          rescue KeyError
            escape_content(content)
          end
        end

        def render_inline_pageref(_type, content, _node)
          # Page reference is unsupported in HTML
          escape_content(content)
        end

        # Helper method to escape content
        def escape_content(str)
          escape(str)
        end

        # Helper methods for references
        def extract_chapter_id(chap_ref)
          m = /\A([\w+-]+)\|(.+)/.match(chap_ref)
          if m
            ch = @book.contents.detect { |chap| chap.id == m[1] }
            raise KeyError unless ch

            return [ch, m[2]]
          end
          [@chapter, chap_ref]
        end

        def get_chap(chapter = @chapter)
          if @book.config['secnolevel'] && @book.config['secnolevel'] > 0 &&
             !chapter.number.nil? && !chapter.number.to_s.empty?
            if chapter.is_a?(ReVIEW::Book::Part)
              return I18n.t('part_short', chapter.number)
            else
              return chapter.format_number(nil)
            end
          end
          nil
        end

        def extname
          ".#{@book.config['htmlext'] || 'html'}"
        end

        def over_secnolevel?(n, _chapter = @chapter)
          secnolevel = @book.config['secnolevel'] || 0
          secnolevel >= n.to_s.split('.').size
        end
      end
    end
  end
end
