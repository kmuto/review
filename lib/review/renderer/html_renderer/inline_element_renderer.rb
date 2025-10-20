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

        def render_inline_raw(_type, content, node)
          if node.args.first
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

        def render_inline_embed(_type, content, node)
          # @<embed> simply outputs its content as-is, like Builder's inline_embed
          # It can optionally specify target formats like @<embed>{|html,latex|content}
          if node.args.first
            args = node.args.first
            # DEBUG
            if ENV['REVIEW_DEBUG']
              puts "DEBUG render_inline_embed: content=#{content.inspect}, args=#{args.inspect}"
            end
            if matched = args.match(/\|(.*?)\|(.*)/)
              builders = matched[1].split(',').map { |i| i.gsub(/\s/, '') }
              if builders.include?('html')
                matched[2]
              else
                ''
              end
            else
              args
            end
          else
            content
          end
        end

        def render_inline_chap(_type, _content, node)
          id = node.reference_id
          begin
            chapter_num = @book.chapter_index.number(id)
            if config['chapterlink']
              %Q(<a href="./#{id}#{extname}">#{chapter_num}</a>)
            else
              chapter_num
            end
          rescue ReVIEW::KeyError
            app_error "unknown chapter: #{id}"
          end
        end

        def render_inline_title(_type, _content, node)
          id = node.reference_id
          begin
            # Find the chapter and get its title
            chapter = find_chapter_by_id(id)
            raise ReVIEW::KeyError unless chapter

            title = compile_inline(chapter.title)
            if config['chapterlink']
              %Q(<a href="./#{id}#{extname}">#{title}</a>)
            else
              title
            end
          rescue ReVIEW::KeyError
            app_error "unknown chapter: #{id}"
          end
        end

        def render_inline_chapref(_type, _content, node)
          id = node.reference_id
          begin
            # Use display_string like Builder to get chapter number + title
            # This returns formatted string like "第1章「タイトル」" from I18n.t('chapter_quote')
            display_str = @book.chapter_index.display_string(id)
            if config['chapterlink']
              %Q(<a href="./#{id}#{extname}">#{display_str}</a>)
            else
              display_str
            end
          rescue ReVIEW::KeyError
            app_error "unknown chapter: #{id}"
          end
        end

        def render_inline_list(_type, _content, node)
          id = node.reference_id
          @renderer.render_list(id, node)
        end

        def render_inline_img(_type, _content, node)
          id = node.reference_id
          @renderer.render_img(id, node)
        end

        def render_inline_table(_type, _content, node)
          id = node.reference_id
          @renderer.render_inline_table(id, node)
        end

        def render_inline_fn(_type, content, node)
          fn_id = node.reference_id
          if fn_id
            # Get footnote number from chapter like HTMLBuilder
            begin
              fn_number = @chapter.footnote(fn_id).number
              # Check epubversion for consistent output with HTMLBuilder
              if @book.config['epubversion'].to_i == 3
                %Q(<a id="fnb-#{normalize_id(fn_id)}" href="#fn-#{normalize_id(fn_id)}" class="noteref" epub:type="noteref">#{I18n.t('html_footnote_refmark', fn_number)}</a>)
              else
                %Q(<a id="fnb-#{normalize_id(fn_id)}" href="#fn-#{normalize_id(fn_id)}" class="noteref">*#{fn_number}</a>)
              end
            rescue ReVIEW::KeyError
              # Fallback if footnote not found
              content
            end
          else
            content
          end
        end

        def render_inline_kw(_type, content, node)
          if node.args.length >= 2
            word = escape_content(node.args[0])
            alt = escape_content(node.args[1].strip)
            # Format like HTMLBuilder: word + space + parentheses with alt inside <b> tag
            text = "#{word} (#{alt})"
            # IDX comment uses only the word, like HTMLBuilder
            %Q(<b class="kw">#{text}</b><!-- IDX:#{word} -->)
          else
            # content is already escaped, use node.args.first for IDX comment
            index_term = node.args.first || content
            %Q(<b class="kw">#{content}</b><!-- IDX:#{escape_content(index_term)} -->)
          end
        end

        def render_inline_bou(_type, content, _node)
          %Q(<span class="bou">#{content}</span>)
        end

        def render_inline_ami(_type, content, _node)
          %Q(<span class="ami">#{content}</span>)
        end

        def render_inline_href(_type, content, node)
          args = node.args || []
          if args.length >= 2
            # Get raw URL and text from args, escape them
            url = escape_content(args[0])
            text = escape_content(args[1])
            # Handle internal references (URLs starting with #)
            if args[0].start_with?('#')
              anchor = args[0].sub(/\A#/, '')
              %Q(<a href="##{escape_content(anchor)}" class="link">#{text}</a>)
            else
              %Q(<a href="#{url}" class="link">#{text}</a>)
            end
          elsif node.args.first
            # Single argument case - use raw arg for URL
            url = escape_content(node.args.first)
            if node.args.first.start_with?('#')
              anchor = node.args.first.sub(/\A#/, '')
              %Q(<a href="##{escape_content(anchor)}" class="link">#{content}</a>)
            else
              %Q(<a href="#{url}" class="link">#{content}</a>)
            end
          else
            # Fallback: content is already escaped
            %Q(<a href="#{content}" class="link">#{content}</a>)
          end
        end

        def render_inline_ruby(_type, content, node)
          if node.args.length >= 2
            base = node.args[0]
            ruby = node.args[1]
            %Q(<ruby>#{escape_content(base)}<rt>#{escape_content(ruby)}</rt></ruby>)
          else
            content
          end
        end

        def render_inline_m(_type, content, _node)
          # Use 'equation' class like HTMLBuilder
          %Q(<span class="equation">#{content}</span>)
        end

        def render_inline_idx(_type, content, node)
          # Use HTML comment format like HTMLBuilder
          # content is already escaped for display
          index_str = node.args.first || content
          %Q(#{content}<!-- IDX:#{escape_comment(index_str)} -->)
        end

        def render_inline_hidx(_type, _content, node)
          # Use HTML comment format like HTMLBuilder
          # hidx doesn't display content, only outputs the index comment
          index_str = node.args.first || ''
          %Q(<!-- IDX:#{escape_comment(index_str)} -->)
        end

        def render_inline_comment(_type, content, _node)
          if config['draft']
            %Q(<span class="draft-comment">#{content}</span>)
          else
            ''
          end
        end

        def render_inline_sec(_type, _content, node)
          # Section number reference: @<sec>{id} or @<sec>{chapter|id}
          # This should match HTMLBuilder's inline_sec behavior
          id = node.reference_id
          begin
            chap, id2 = extract_chapter_id(id)
            n = chap.headline_index.number(id2)

            # Get section number like Builder does
            section_number = if n.present? && chap.number && over_secnolevel?(n, chap)
                               n
                             else
                               ''
                             end

            if config['chapterlink']
              anchor = 'h' + n.tr('.', '-')
              %Q(<a href="#{chap.id}#{extname}##{anchor}">#{section_number}</a>)
            else
              section_number
            end
          rescue ReVIEW::KeyError
            app_error "unknown headline: #{id}"
          end
        end

        def render_inline_secref(type, content, node)
          render_inline_hd(type, content, node)
        end

        def render_inline_labelref(_type, content, node)
          # Label reference: @<labelref>{id}
          # This should match HTMLBuilder's inline_labelref behavior
          idref = node.reference_id || content
          %Q(<a target='#{escape_content(idref)}'>「#{I18n.t('label_marker')}#{escape_content(idref)}」</a>)
        end

        def render_inline_ref(type, content, node)
          render_inline_labelref(type, content, node)
        end

        def render_inline_w(_type, content, _node)
          # Content should already be resolved by ReferenceResolver
          content
        end

        def render_inline_wb(_type, content, _node)
          # Content should already be resolved by ReferenceResolver
          %Q(<b>#{content}</b>)
        end

        def render_inline_abbr(_type, content, _node)
          %Q(<abbr>#{content}</abbr>)
        end

        def render_inline_acronym(_type, content, _node)
          %Q(<acronym>#{content}</acronym>)
        end

        def render_inline_cite(_type, content, _node)
          %Q(<cite>#{content}</cite>)
        end

        def render_inline_dfn(_type, content, _node)
          %Q(<dfn>#{content}</dfn>)
        end

        def render_inline_big(_type, content, _node)
          %Q(<big>#{content}</big>)
        end

        def render_inline_small(_type, content, _node)
          %Q(<small>#{content}</small>)
        end

        def render_inline_dtp(_type, content, _node)
          "<?dtp #{content} ?>"
        end

        def render_inline_recipe(_type, content, _node)
          %Q(<span class="recipe">「#{content}」</span>)
        end

        def render_inline_icon(_type, content, node)
          # Icon is an image reference
          id = node.args.first || content
          begin
            %Q(<img src="#{@chapter.image(id).path.sub(%r{\A\./}, '')}" alt="[#{id}]" />)
          rescue ReVIEW::KeyError, NoMethodError
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
          %Q(<span class="#{style}">#{content}</span>)
        end

        def render_inline_balloon(_type, content, _node)
          %Q(<span class="balloon">#{content}</span>)
        end

        def render_inline_bib(_type, content, node)
          # Bibliography reference
          id = node.args.first || content
          begin
            bib_file = @book.bib_file.gsub(/\.re\Z/, ".#{config['htmlext'] || 'html'}")
            number = @chapter.bibpaper(id).number
            %Q(<a href="#{bib_file}#bib-#{normalize_id(id)}">[#{number}]</a>)
          rescue ReVIEW::KeyError
            %Q([#{id}])
          end
        end

        def render_inline_endnote(_type, content, node)
          # Endnote reference
          id = node.reference_id
          begin
            number = @chapter.endnote(id).number
            %Q(<a id="endnoteb-#{normalize_id(id)}" href="#endnote-#{normalize_id(id)}" class="noteref" epub:type="noteref">#{I18n.t('html_endnote_refmark', number)}</a>)
          rescue ReVIEW::KeyError
            %Q(<a href="#endnote-#{normalize_id(id)}" class="noteref">#{content}</a>)
          end
        end

        def render_inline_eq(_type, content, node)
          # Equation reference
          id = node.reference_id
          begin
            chapter, extracted_id = extract_chapter_id(id)
            equation_number = if get_chap(chapter)
                                %Q(#{I18n.t('equation')}#{I18n.t('format_number', [get_chap(chapter), chapter.equation(extracted_id).number])})
                              else
                                %Q(#{I18n.t('equation')}#{I18n.t('format_number_without_chapter', [chapter.equation(extracted_id).number])})
                              end

            if config['chapterlink']
              %Q(<span class="eqref"><a href="./#{chapter.id}#{extname}##{normalize_id(extracted_id)}">#{equation_number}</a></span>)
            else
              %Q(<span class="eqref">#{equation_number}</span>)
            end
          rescue ReVIEW::KeyError
            %Q(<span class="eqref">#{content}</span>)
          end
        end

        def render_inline_hd(_type, _content, node)
          # Headline reference: @<hd>{id} or @<hd>{chapter|id}
          # This should match HTMLBuilder's inline_hd_chap behavior
          id = node.reference_id
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

            # Use compile_inline to process the caption, not escape_content
            str = if n.present? && chapter.number && over_secnolevel?(n, chapter)
                    I18n.t('hd_quote', [n, compile_inline(caption)])
                  else
                    I18n.t('hd_quote_without_number', compile_inline(caption))
                  end

            if config['chapterlink']
              anchor = 'h' + n.tr('.', '-')
              %Q(<a href="#{chapter.id}#{extname}##{anchor}">#{str}</a>)
            else
              str
            end
          rescue ReVIEW::KeyError
            app_error "unknown headline: #{id}"
          end
        end

        def render_inline_column(_type, _content, node)
          # Column reference: @<column>{id} or @<column>{chapter|id}
          id = node.reference_id
          m = /\A([^|]+)\|(.+)/.match(id)

          chapter = if m && m[1]
                      find_chapter_by_id(m[1])
                    else
                      @chapter
                    end

          column_id = m ? m[2] : id

          begin
            app_error "unknown chapter: #{m[1]}" if m && !chapter
            return '' unless chapter

            column_caption = chapter.column(column_id).caption
            column_number = chapter.column(column_id).number

            anchor = "column-#{column_number}"
            if config['chapterlink']
              %Q(<a href="#{chapter.id}#{extname}##{anchor}" class="columnref">#{I18n.t('column', escape_content(column_caption))}</a>)
            else
              I18n.t('column', escape_content(column_caption))
            end
          rescue ReVIEW::KeyError
            app_error "unknown column: #{column_id}"
          end
        end

        def render_inline_sectitle(_type, content, node)
          # Section title reference
          id = node.reference_id
          begin
            if config['chapterlink']
              chap, id2 = extract_chapter_id(id)
              anchor = 'h' + chap.headline_index.number(id2).tr('.', '-')
              title = chap.headline(id2).caption
              %Q(<a href="#{chap.id}#{extname}##{anchor}">#{escape_content(title)}</a>)
            else
              content
            end
          rescue ReVIEW::KeyError
            content
          end
        end

        def render_inline_pageref(_type, content, _node)
          # Page reference is unsupported in HTML
          content
        end

        # Configuration accessor - returns book config or empty hash for nil safety
        def config
          @book&.config || {}
        end

        # Helper method to escape content
        def escape_content(str)
          escape(str)
        end

        # Helper methods for references
        def extract_chapter_id(chap_ref)
          m = /\A([\w+-]+)\|(.+)/.match(chap_ref)
          if m
            ch = find_chapter_by_id(m[1])
            raise ReVIEW::KeyError unless ch

            return [ch, m[2]]
          end
          [@chapter, chap_ref]
        end

        def get_chap(chapter = @chapter)
          if config['secnolevel'] && config['secnolevel'] > 0 &&
             !chapter.number.nil? && !chapter.number.to_s.empty?
            if chapter.is_a?(ReVIEW::Book::Part)
              return I18n.t('part_short', chapter.number)
            else
              return chapter.format_number(nil)
            end
          end
          nil
        end

        def find_chapter_by_id(chapter_id)
          return nil unless @book

          begin
            item = @book.chapter_index[chapter_id]
            return item.content if item.respond_to?(:content)
          rescue ReVIEW::KeyError
            # fall back to contents search
          end

          Array(@book.contents).find { |chap| chap.id == chapter_id }
        end

        def extname
          ".#{config['htmlext'] || 'html'}"
        end

        def over_secnolevel?(n, _chapter = @chapter)
          secnolevel = config['secnolevel'] || 0
          secnolevel >= n.to_s.split('.').size
        end

        def compile_inline(str)
          # Simple inline compilation - just return the string for now
          # In the future, this could process inline Re:VIEW markup
          return '' if str.nil? || str.empty?

          str.to_s
        end
      end
    end
  end
end
