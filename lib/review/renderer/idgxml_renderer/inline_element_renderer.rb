# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'digest/sha2'

module ReVIEW
  module Renderer
    class IdgxmlRenderer
      class InlineElementRenderer
        def initialize(parent_renderer, book:, chapter:, rendering_context:)
          @parent_renderer = parent_renderer
          @book = book
          @chapter = chapter
          @rendering_context = rendering_context
        end

        def render(type, content, node)
          # Dispatch to specific render method
          method_name = "render_#{type}".to_sym
          if respond_to?(method_name, true)
            send(method_name, content, node)
          else
            # Fallback: return content as-is
            content
          end
        end

        private

        # Basic formatting
        # Note: content is already escaped by visit_text, so don't escape again
        def render_b(content, _node)
          %Q(<b>#{content}</b>)
        end

        def render_i(content, _node)
          %Q(<i>#{content}</i>)
        end

        def render_em(content, _node)
          %Q(<em>#{content}</em>)
        end

        def render_strong(content, _node)
          %Q(<strong>#{content}</strong>)
        end

        def render_tt(content, _node)
          %Q(<tt>#{content}</tt>)
        end

        def render_ttb(content, _node)
          %Q(<tt style='bold'>#{content}</tt>)
        end

        alias_method :render_ttbold, :render_ttb

        def render_tti(content, _node)
          %Q(<tt style='italic'>#{escape(content)}</tt>)
        end

        def render_u(content, _node)
          %Q(<underline>#{escape(content)}</underline>)
        end

        def render_ins(content, _node)
          %Q(<ins>#{escape(content)}</ins>)
        end

        def render_del(content, _node)
          %Q(<del>#{escape(content)}</del>)
        end

        def render_sup(content, _node)
          %Q(<sup>#{escape(content)}</sup>)
        end

        def render_sub(content, _node)
          %Q(<sub>#{escape(content)}</sub>)
        end

        def render_ami(content, _node)
          %Q(<ami>#{escape(content)}</ami>)
        end

        def render_bou(content, _node)
          %Q(<bou>#{escape(content)}</bou>)
        end

        def render_keytop(content, _node)
          %Q(<keytop>#{escape(content)}</keytop>)
        end

        # Code
        def render_code(content, _node)
          %Q(<tt type='inline-code'>#{escape(content)}</tt>)
        end

        # Hints
        def render_hint(content, _node)
          if @book.config['nolf']
            %Q(<hint>#{escape(content)}</hint>)
          else
            %Q(\n<hint>#{escape(content)}</hint>)
          end
        end

        # Maru (circled numbers/letters)
        def render_maru(content, node)
          str = node.args&.first || content

          if /\A\d+\Z/.match?(str)
            sprintf('&#x%x;', 9311 + str.to_i)
          elsif /\A[A-Z]\Z/.match?(str)
            begin
              sprintf('&#x%x;', 9398 + str.codepoints.to_a[0] - 65)
            rescue NoMethodError
              sprintf('&#x%x;', 9398 + str[0] - 65)
            end
          elsif /\A[a-z]\Z/.match?(str)
            begin
              sprintf('&#x%x;', 9392 + str.codepoints.to_a[0] - 65)
            rescue NoMethodError
              sprintf('&#x%x;', 9392 + str[0] - 65)
            end
          else
            escape(str)
          end
        end

        # Ruby (furigana)
        def render_ruby(content, node)
          if node.args && node.args.length >= 2
            base = escape(node.args[0])
            ruby = escape(node.args[1])
            %Q(<GroupRuby><aid:ruby xmlns:aid="http://ns.adobe.com/AdobeInDesign/3.0/"><aid:rb>#{base}</aid:rb><aid:rt>#{ruby}</aid:rt></aid:ruby></GroupRuby>)
          else
            escape(content)
          end
        end

        # Keyword
        def render_kw(content, node)
          if node.args && node.args.length >= 2
            word = node.args[0]
            alt = node.args[1]

            result = '<keyword>'
            if alt && !alt.empty?
              result += escape("#{word}（#{alt.strip}）")
            else
              result += escape(word)
            end
            result += '</keyword>'

            result += %Q(<index value="#{escape(word)}" />)

            if alt && !alt.empty?
              alt.split(/\s*,\s*/).each do |e|
                result += %Q(<index value="#{escape(e.strip)}" />)
              end
            end

            result
          elsif node.args && node.args.length == 1
            # Single argument case - get raw string from args
            word = node.args[0]
            result = %Q(<keyword>#{escape(word)}</keyword>)
            result += %Q(<index value="#{escape(word)}" />)
            result
          else
            # Fallback
            %Q(<keyword>#{content}</keyword>)
          end
        end

        # Index
        def render_idx(content, node)
          str = node.args&.first || content
          %Q(#{escape(str)}<index value="#{escape(str)}" />)
        end

        def render_hidx(content, node)
          str = node.args&.first || content
          %Q(<index value="#{escape(str)}" />)
        end

        # Links
        def render_href(content, node)
          if node.args && node.args.length >= 2
            url = node.args[0].gsub('\,', ',').strip
            label = node.args[1].gsub('\,', ',').strip
            %Q(<a linkurl='#{escape(url)}'>#{escape(label)}</a>)
          elsif node.args && node.args.length >= 1
            url = node.args[0].gsub('\,', ',').strip
            %Q(<a linkurl='#{escape(url)}'>#{escape(url)}</a>)
          else
            %Q(<a linkurl='#{escape(content)}'>#{escape(content)}</a>)
          end
        end

        # References
        def render_list(content, node)
          id = node.args&.first || content
          begin
            # Get list reference using parent renderer's method
            base_ref = @parent_renderer.send(:get_list_reference, id)
            "<span type='list'>#{base_ref}</span>"
          rescue StandardError => e
            "<span type='list'>#{escape(id)}</span>"
          end
        end

        def render_table(content, node)
          id = node.args&.first || content
          begin
            # Get table reference using parent renderer's method
            base_ref = @parent_renderer.send(:get_table_reference, id)
            "<span type='table'>#{base_ref}</span>"
          rescue StandardError => e
            "<span type='table'>#{escape(id)}</span>"
          end
        end

        def render_img(content, node)
          id = node.args&.first || content
          begin
            # Get image reference using parent renderer's method
            base_ref = @parent_renderer.send(:get_image_reference, id)
            "<span type='image'>#{base_ref}</span>"
          rescue StandardError => e
            "<span type='image'>#{escape(id)}</span>"
          end
        end

        def render_eq(content, node)
          id = node.args&.first || content
          begin
            # Get equation reference using parent renderer's method
            base_ref = @parent_renderer.send(:get_equation_reference, id)
            "<span type='eq'>#{base_ref}</span>"
          rescue StandardError => e
            "<span type='eq'>#{escape(id)}</span>"
          end
        end

        def render_imgref(content, node)
          id = node.args&.first || content
          chapter, extracted_id = extract_chapter_id(id)

          if chapter.image(extracted_id).caption.blank?
            render_img(content, node)
          elsif get_chap(chapter).nil?
            "<span type='image'>#{I18n.t('image')}#{I18n.t('format_number_without_chapter', [chapter.image(extracted_id).number])}#{I18n.t('image_quote', chapter.image(extracted_id).caption)}</span>"
          else
            "<span type='image'>#{I18n.t('image')}#{I18n.t('format_number', [get_chap(chapter), chapter.image(extracted_id).number])}#{I18n.t('image_quote', chapter.image(extracted_id).caption)}</span>"
          end
        rescue StandardError
          "<span type='image'>#{escape(id)}</span>"
        end

        # Column reference
        def render_column(content, node)
          id = node.args&.first || content

          # Parse chapter|id format
          m = /\A([^|]+)\|(.+)/.match(id)
          if m && m[1]
            chapter = @book.contents.detect { |chap| chap.id == m[1] }
            column_id = m[2]
          else
            chapter = @chapter
            column_id = id
          end

          return escape(content) unless chapter

          # Render column reference
          if @book.config['chapterlink']
            num = chapter.column(column_id).number
            %Q(<link href="column-#{num}">#{I18n.t('column', chapter.column(column_id).caption)}</link>)
          else
            I18n.t('column', chapter.column(column_id).caption)
          end
        rescue StandardError
          escape(content)
        end

        # Footnotes
        def render_fn(content, node)
          id = node.args&.first || content
          begin
            fn_content = @chapter.footnote(id).content.strip
            # Compile inline elements in footnote content
            compiled_content = fn_content # TODO: may need to compile inline
            %Q(<footnote>#{compiled_content}</footnote>)
          rescue KeyError
            %Q(<footnote>#{escape(id)}</footnote>)
          end
        end

        # Endnotes
        def render_endnote(content, node)
          id = node.args&.first || content
          begin
            %Q(<span type='endnoteref' idref='endnoteb-#{normalize_id(id)}'>(#{@chapter.endnote(id).number})</span>)
          rescue KeyError
            %Q(<span type='endnoteref' idref='endnoteb-#{normalize_id(id)}'>(??)</span>)
          end
        end

        # Bibliography
        def render_bib(content, node)
          id = node.args&.first || content
          begin
            %Q(<span type='bibref' idref='#{id}'>[#{@chapter.bibpaper(id).number}]</span>)
          rescue KeyError
            %Q(<span type='bibref' idref='#{id}'>[??]</span>)
          end
        end

        # Headline reference
        def render_hd(content, node)
          if node.args && node.args.length >= 2
            chapter_id = node.args[0]
            headline_id = node.args[1]

            chap = @book.contents.detect { |c| c.id == chapter_id }
            if chap
              n = chap.headline_index.number(headline_id)
              if n.present? && chap.number && over_secnolevel?(n)
                I18n.t('hd_quote', [n, chap.headline(headline_id).caption])
              else
                I18n.t('hd_quote_without_number', chap.headline(headline_id).caption)
              end
            else
              escape(content)
            end
          else
            escape(content)
          end
        rescue StandardError
          escape(content)
        end

        # Chapter reference
        def render_chap(content, node)
          id = node.args&.first || content
          if @book.config['chapterlink']
            %Q(<link href="#{id}">#{@book.chapter_index.number(id)}</link>)
          else
            @book.chapter_index.number(id)
          end
        rescue KeyError
          escape(id)
        end

        def render_chapref(content, node)
          id = node.args&.first || content

          if @book.config.check_version('2', exception: false)
            # Backward compatibility
            chs = ['', '「', '」']
            if @book.config['chapref']
              chs2 = @book.config['chapref'].split(',')
              if chs2.size == 3
                chs = chs2
              end
            end
            s = "#{chs[0]}#{@book.chapter_index.number(id)}#{chs[1]}#{@book.chapter_index.title(id)}#{chs[2]}"
            if @book.config['chapterlink']
              %Q(<link href="#{id}">#{s}</link>)
            else
              s
            end
          else
            # Use parent renderer's method
            title = @book.chapter_index.title(id)
            if @book.config['chapterlink']
              %Q(<link href="#{id}">#{title}</link>)
            else
              title
            end
          end
        rescue KeyError
          escape(id)
        end

        def render_title(content, node)
          id = node.args&.first || content
          title = @book.chapter_index.title(id)
          if @book.config['chapterlink']
            %Q(<link href="#{id}">#{title}</link>)
          else
            title
          end
        rescue KeyError
          escape(id)
        end

        # Labels
        def render_labelref(content, node)
          # Get idref from node.args (raw, not escaped)
          idref = node.respond_to?(:args) && node.args&.first ? node.args.first : content
          %Q(<ref idref='#{escape(idref)}'>「#{I18n.t('label_marker')}#{escape(idref)}」</ref>)
        end

        alias_method :render_ref, :render_labelref

        def render_pageref(content, node)
          idref = node.args&.first || content
          %Q(<pageref idref='#{escape(idref)}'>●●</pageref>)
        end

        # Icon (inline image)
        def render_icon(content, node)
          id = node.args&.first || content
          begin
            %Q(<Image href="file://#{@chapter.image(id).path.sub(%r{\A\./}, '')}" type="inline" />)
          rescue StandardError
            ''
          end
        end

        # Balloon
        def render_balloon(content, node)
          # Content is already escaped and rendered from children
          # Need to get raw text from node to process @maru markers
          # Since InlineNode processes children first, we need raw args
          if node.respond_to?(:args) && node.args&.first
            # Get raw string from args (not escaped yet)
            str = node.args.first
            processed = escape(str).gsub(/@maru\[(\d+)\]/) do
              # $1 is the captured number string
              number = $1
              # Generate maru character directly
              if /\A\d+\Z/.match?(number)
                sprintf('&#x%x;', 9311 + number.to_i)
              else
                "@maru[#{number}]"
              end
            end
            %Q(<balloon>#{processed}</balloon>)
          else
            # Fallback: use content as-is
            %Q(<balloon>#{content}</balloon>)
          end
        end

        # Unicode character
        def render_uchar(content, node)
          str = node.args&.first || content
          %Q(&#x#{str};)
        end

        # Math
        def render_m(content, node)
          str = node.args&.first || content

          if @book.config['math_format'] == 'imgmath'
            require 'review/img_math'
            @parent_renderer.instance_variable_set(:@texinlineequation, @parent_renderer.instance_variable_get(:@texinlineequation) + 1)
            texinlineequation = @parent_renderer.instance_variable_get(:@texinlineequation)

            math_str = '$' + str + '$'
            key = Digest::SHA256.hexdigest(str)
            img_math = @parent_renderer.instance_variable_get(:@img_math)
            unless img_math
              img_math = ReVIEW::ImgMath.new(@book.config)
              @parent_renderer.instance_variable_set(:@img_math, img_math)
            end
            img_path = img_math.defer_math_image(math_str, key)
            %Q(<inlineequation><Image href="file://#{img_path}" type="inline" /></inlineequation>)
          else
            @parent_renderer.instance_variable_set(:@texinlineequation, @parent_renderer.instance_variable_get(:@texinlineequation) + 1)
            texinlineequation = @parent_renderer.instance_variable_get(:@texinlineequation)
            %Q(<replace idref="texinline-#{texinlineequation}"><pre>#{escape(str)}</pre></replace>)
          end
        end

        # DTP processing instruction
        def render_dtp(content, node)
          str = node.args&.first || content
          "<?dtp #{str} ?>"
        end

        # Break
        # Returns a protected newline marker that will be preserved through paragraph
        # and nolf processing, then restored to an actual newline in visit_document
        def render_br(content, _node)
          "\x01IDGXML_INLINE_NEWLINE\x01"
        end

        # Raw
        def render_raw(content, node)
          if node.args && node.args.first
            raw_content = node.args.first
            # Convert \\n to actual newlines
            raw_content.gsub('\\n', "\n")
          else
            content.gsub('\\n', "\n")
          end
        end

        # Comment
        def render_comment(content, node)
          if @book.config['draft']
            str = node.args&.first || content
            %Q(<msg>#{escape(str)}</msg>)
          else
            ''
          end
        end

        # Recipe (FIXME placeholder)
        def render_recipe(content, node)
          id = node.args&.first || content
          %Q(<recipe idref="#{escape(id)}">[XXX]「#{escape(id)}」　p.XX</recipe>)
        end

        # Helpers

        def escape(str)
          @parent_renderer.send(:escape, str.to_s)
        end

        def normalize_id(id)
          # Normalize ID for XML attributes
          id.to_s.gsub(/[^a-zA-Z0-9_-]/, '_')
        end

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
          if @book&.config&.[]('secnolevel') && @book.config['secnolevel'] > 0 &&
             !chapter.number.nil? && !chapter.number.to_s.empty?
            if chapter.is_a?(ReVIEW::Book::Part)
              return I18n.t('part_short', chapter.number)
            else
              return chapter.format_number(nil)
            end
          end
          nil
        end

        def over_secnolevel?(n)
          secnolevel = @book&.config&.[]('secnolevel') || 2
          n.to_s.split('.').size >= secnolevel
        end
      end
    end
  end
end
