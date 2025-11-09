# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'digest/sha2'

module ReVIEW
  module Renderer
    module Idgxml
      # Inline element handler for IDGXML rendering
      # Uses InlineContext for shared logic
      class InlineElementHandler
        include ReVIEW::HTMLUtils
        include ReVIEW::Loggable

        def initialize(inline_context)
          @ctx = inline_context
          @img_math = @ctx.img_math
          @logger = ReVIEW.logger
        end

        # Basic formatting
        # Note: content is already escaped by visit_text, so don't escape again
        def render_inline_b(_type, content, _node)
          %Q(<b>#{content}</b>)
        end

        def render_inline_i(_type, content, _node)
          %Q(<i>#{content}</i>)
        end

        def render_inline_em(_type, content, _node)
          %Q(<em>#{content}</em>)
        end

        def render_inline_strong(_type, content, _node)
          %Q(<strong>#{content}</strong>)
        end

        def render_inline_tt(_type, content, _node)
          %Q(<tt>#{content}</tt>)
        end

        def render_inline_ttb(_type, content, _node)
          %Q(<tt style='bold'>#{content}</tt>)
        end

        def render_inline_ttbold(type, content, node)
          render_inline_ttb(type, content, node)
        end

        def render_inline_tti(_type, content, _node)
          %Q(<tt style='italic'>#{content}</tt>)
        end

        def render_inline_u(_type, content, _node)
          %Q(<underline>#{content}</underline>)
        end

        def render_inline_ins(_type, content, _node)
          %Q(<ins>#{content}</ins>)
        end

        def render_inline_del(_type, content, _node)
          %Q(<del>#{content}</del>)
        end

        def render_inline_sup(_type, content, _node)
          %Q(<sup>#{content}</sup>)
        end

        def render_inline_sub(_type, content, _node)
          %Q(<sub>#{content}</sub>)
        end

        def render_inline_ami(_type, content, _node)
          %Q(<ami>#{content}</ami>)
        end

        def render_inline_bou(_type, content, _node)
          %Q(<bou>#{content}</bou>)
        end

        def render_inline_keytop(_type, content, _node)
          %Q(<keytop>#{content}</keytop>)
        end

        # Code
        def render_inline_code(_type, content, _node)
          %Q(<tt type='inline-code'>#{content}</tt>)
        end

        # Hints
        def render_inline_hint(_type, content, _node)
          if @ctx.config['nolf']
            %Q(<hint>#{content}</hint>)
          else
            %Q(\n<hint>#{content}</hint>)
          end
        end

        # Maru (circled numbers/letters)
        def render_inline_maru(_type, content, node)
          str = node.args.first || content

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
        def render_inline_ruby(_type, content, node)
          if node.args.length >= 2
            base = escape(node.args[0])
            ruby = escape(node.args[1])
            %Q(<GroupRuby><aid:ruby xmlns:aid="http://ns.adobe.com/AdobeInDesign/3.0/"><aid:rb>#{base}</aid:rb><aid:rt>#{ruby}</aid:rt></aid:ruby></GroupRuby>)
          else
            content
          end
        end

        # Keyword
        def render_inline_kw(_type, content, node)
          if node.args.length >= 2
            word = node.args[0]
            alt = node.args[1]

            result = '<keyword>'
            result += if alt && !alt.empty?
                        escape("#{word}（#{alt.strip}）")
                      else
                        escape(word)
                      end
            result += '</keyword>'

            result += %Q(<index value="#{escape(word)}" />)

            if alt && !alt.empty?
              alt.split(/\s*,\s*/).each do |e|
                result += %Q(<index value="#{escape(e.strip)}" />)
              end
            end

            result
          elsif node.args.length == 1
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
        def render_inline_idx(_type, content, node)
          str = node.args.first || content
          %Q(#{escape(str)}<index value="#{escape(str)}" />)
        end

        def render_inline_hidx(_type, content, node)
          str = node.args.first || content
          %Q(<index value="#{escape(str)}" />)
        end

        # Links
        def render_inline_href(_type, content, node)
          if node.args.length >= 2
            url = node.args[0].gsub('\,', ',').strip
            label = node.args[1].gsub('\,', ',').strip
            %Q(<a linkurl='#{escape(url)}'>#{escape(label)}</a>)
          elsif node.args.length >= 1
            url = node.args[0].gsub('\,', ',').strip
            %Q(<a linkurl='#{escape(url)}'>#{escape(url)}</a>)
          else
            %Q(<a linkurl='#{content}'>#{content}</a>)
          end
        end

        # References
        def render_inline_list(_type, _content, node)
          ref_node = node.children.first
          unless ref_node.reference_node? && ref_node.resolved?
            raise 'BUG: Reference should be resolved at AST construction time'
          end

          data = ref_node.resolved_data
          base_ref = @ctx.text_formatter.format_reference(:list, data)
          "<span type='list'>#{base_ref}</span>"
        end

        def render_inline_table(_type, _content, node)
          ref_node = node.children.first
          unless ref_node.reference_node? && ref_node.resolved?
            raise 'BUG: Reference should be resolved at AST construction time'
          end

          data = ref_node.resolved_data
          base_ref = @ctx.text_formatter.format_reference(:table, data)
          "<span type='table'>#{base_ref}</span>"
        end

        def render_inline_img(_type, _content, node)
          ref_node = node.children.first
          unless ref_node.reference_node? && ref_node.resolved?
            raise 'BUG: Reference should be resolved at AST construction time'
          end

          data = ref_node.resolved_data
          base_ref = @ctx.text_formatter.format_reference(:image, data)
          "<span type='image'>#{base_ref}</span>"
        end

        def render_inline_eq(_type, _content, node)
          ref_node = node.children.first
          unless ref_node.reference_node? && ref_node.resolved?
            raise 'BUG: Reference should be resolved at AST construction time'
          end

          data = ref_node.resolved_data
          base_ref = @ctx.text_formatter.format_reference(:equation, data)
          "<span type='eq'>#{base_ref}</span>"
        end

        def render_inline_imgref(type, content, node)
          ref_node = node.children.first
          unless ref_node.reference_node? && ref_node.resolved?
            raise 'BUG: Reference should be resolved at AST construction time'
          end

          data = ref_node.resolved_data

          # If no caption, fall back to render_inline_img
          if data.caption_text.blank?
            return render_inline_img(type, content, node)
          end

          # Build reference with caption
          base_ref = @ctx.text_formatter.format_reference(:image, data)
          caption = @ctx.text_formatter.format_image_quote(data.caption_text)
          "<span type='image'>#{base_ref}#{caption}</span>"
        end

        # Column reference
        def render_inline_column(_type, _content, node)
          ref_node = node.children.first
          unless ref_node.reference_node? && ref_node.resolved?
            raise 'BUG: Reference should be resolved at AST construction time'
          end

          data = ref_node.resolved_data

          # Use caption_node to render inline elements if available
          # For cross-chapter references, caption_node may not be available, so fall back to caption_text
          compiled_caption = if data.caption_node
                               @ctx.render_caption_inline(data.caption_node)
                             else
                               escape(data.caption_text)
                             end

          column_text = @ctx.text_formatter.format_column_label(compiled_caption)

          if @ctx.chapter_link_enabled?
            %Q(<link href="column-#{data.item_number}">#{column_text}</link>)
          else
            column_text
          end
        end

        # Footnotes
        def render_inline_fn(_type, _content, node)
          ref_node = node.children.first
          unless ref_node.reference_node? && ref_node.resolved?
            raise 'BUG: Reference should be resolved at AST construction time'
          end

          data = ref_node.resolved_data
          if data.caption_node
            # Render the stored AST node when available to preserve inline markup
            rendered = @ctx.render_caption_inline(data.caption_node)
            %Q(<footnote>#{rendered}</footnote>)
          else
            # Fallback: use caption_text
            rendered_text = escape(data.caption_text.to_s.strip)
            %Q(<footnote>#{rendered_text}</footnote>)
          end
        end

        # Endnotes
        def render_inline_endnote(_type, _content, node)
          ref_node = node.children.first
          unless ref_node.reference_node? && ref_node.resolved?
            raise 'BUG: Reference should be resolved at AST construction time'
          end

          data = ref_node.resolved_data
          %Q(<span type='endnoteref' idref='endnoteb-#{normalize_id(data.item_id)}'>(#{data.item_number})</span>)
        end

        # Bibliography
        def render_inline_bib(_type, _content, node)
          ref_node = node.children.first
          unless ref_node.reference_node? && ref_node.resolved?
            raise 'BUG: Reference should be resolved at AST construction time'
          end

          data = ref_node.resolved_data
          bib_id = data.item_id
          bib_number = data.item_number
          %Q(<span type='bibref' idref='#{bib_id}'>[#{bib_number}]</span>)
        end

        # Headline reference
        def render_inline_hd(_type, content, node)
          ref_node = node.children.first
          return content unless ref_node.reference_node? && ref_node.resolved?

          data = ref_node.resolved_data
          @ctx.text_formatter.format_reference(:headline, data)
        end

        # Section number reference
        def render_inline_sec(_type, _content, node)
          ref_node = node.children.first
          return '' unless ref_node.reference_node? && ref_node.resolved?

          data = ref_node.resolved_data
          n = data.headline_number
          chapter_num = @ctx.text_formatter.format_chapter_number_short(data.chapter_number, data.chapter_type)
          # Get section number like Builder does (including chapter number)
          if n.present? && chapter_num && !chapter_num.empty? && @ctx.over_secnolevel?(n)
            ([chapter_num] + n).join('.')
          else
            ''
          end
        end

        # Section title reference
        def render_inline_sectitle(_type, content, node)
          ref_node = node.children.first
          return content unless ref_node.reference_node? && ref_node.resolved?

          if ref_node.resolved_data.caption_node
            @ctx.render_caption_inline(ref_node.resolved_data.caption_node)
          else
            ref_node.resolved_data.caption_text
          end
        end

        # Chapter reference
        def render_inline_chap(_type, _content, node)
          ref_node = node.children.first
          unless ref_node.reference_node? && ref_node.resolved?
            raise 'BUG: Reference should be resolved at AST construction time'
          end

          data = ref_node.resolved_data
          # Format chapter number to full form (e.g., "第1章", "付録A", "第II部")
          chapter_num = @ctx.text_formatter.format_chapter_number_full(data.chapter_number, data.chapter_type)
          if @ctx.chapter_link_enabled?
            %Q(<link href="#{data.item_id}">#{chapter_num}</link>)
          else
            chapter_num.to_s
          end
        end

        def render_inline_chapref(_type, _content, node)
          ref_node = node.children.first
          unless ref_node.reference_node? && ref_node.resolved?
            raise 'BUG: Reference should be resolved at AST construction time'
          end

          data = ref_node.resolved_data
          display_str = data.to_text
          if @ctx.chapter_link_enabled?
            %Q(<link href="#{data.item_id}">#{display_str}</link>)
          else
            display_str
          end
        end

        def render_inline_title(_type, _content, node)
          ref_node = node.children.first
          unless ref_node.reference_node? && ref_node.resolved?
            raise 'BUG: Reference should be resolved at AST construction time'
          end

          data = ref_node.resolved_data
          title = data.to_title_text
          if @ctx.chapter_link_enabled?
            %Q(<link href="#{data.item_id}">#{title}</link>)
          else
            title
          end
        end

        # Labels
        def render_inline_labelref(_type, content, node)
          # Get idref from node.args (raw, not escaped)
          idref = node.args.first || content
          marker = @ctx.text_formatter.format_label_marker(idref)
          %Q(<ref idref='#{escape(idref)}'>「#{escape(marker)}」</ref>)
        end

        def render_inline_ref(type, content, node)
          render_inline_labelref(type, content, node)
        end

        def render_inline_pageref(_type, content, node)
          idref = node.args.first || content
          %Q(<pageref idref='#{escape(idref)}'>●●</pageref>)
        end

        # Icon (inline image)
        def render_inline_icon(_type, content, node)
          id = node.args.first || content
          begin
            %Q(<Image href="file://#{@ctx.chapter.image(id).path.sub(%r{\A\./}, '')}" type="inline" />)
          rescue StandardError
            ''
          end
        end

        # Balloon
        def render_inline_balloon(_type, content, node)
          # Content is already escaped and rendered from children
          # Need to get raw text from node to process @maru markers
          # Since InlineNode processes children first, we need raw args
          if node.args.first
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
        def render_inline_uchar(_type, content, node)
          str = node.args.first || content
          %Q(&#x#{str};)
        end

        # Math
        def render_inline_m(_type, content, node)
          str = node.args.first || content

          if @ctx.math_format == 'imgmath'
            require 'review/img_math'
            @ctx.increment_texinlineequation

            math_str = '$' + str + '$'
            key = Digest::SHA256.hexdigest(str)
            @img_math ||= ReVIEW::ImgMath.new(@ctx.config)
            img_path = @img_math.defer_math_image(math_str, key)
            %Q(<inlineequation><Image href="file://#{img_path}" type="inline" /></inlineequation>)
          else
            counter_value = @ctx.increment_texinlineequation
            %Q(<replace idref="texinline-#{counter_value}"><pre>#{escape(str)}</pre></replace>)
          end
        end

        # DTP processing instruction
        def render_inline_dtp(_type, content, node)
          str = node.args.first || content
          "<?dtp #{str} ?>"
        end

        # Break
        # Returns a protected newline marker that will be preserved through paragraph
        # and nolf processing, then restored to an actual newline in visit_document
        def render_inline_br(_type, _content, _node)
          "\x01IDGXML_INLINE_NEWLINE\x01"
        end

        # Raw
        def render_inline_raw(_type, _content, node)
          if node.targeted_for?('idgxml')
            # Convert \\n to actual newlines
            (node.content || '').gsub('\\n', "\n")
          else
            ''
          end
        end

        def render_inline_embed(_type, _content, node)
          if node.targeted_for?('idgxml')
            # Convert \\n to actual newlines
            (node.content || '').gsub('\\n', "\n")
          else
            ''
          end
        end

        # Comment
        def render_inline_comment(_type, content, node)
          if @ctx.draft_mode?
            str = node.args.first || content
            %Q(<msg>#{escape(str)}</msg>)
          else
            ''
          end
        end

        # Recipe (FIXME placeholder)
        def render_inline_recipe(_type, content, node)
          id = node.args.first || content
          %Q(<recipe idref="#{escape(id)}">[XXX]「#{escape(id)}」　p.XX</recipe>)
        end

        # Alias for secref
        def render_inline_secref(type, content, node)
          render_inline_hd(type, content, node)
        end

        private

        def escape(str)
          @ctx.escape(str)
        end

        def normalize_id(id)
          # Normalize ID for XML attributes
          id.to_s.gsub(/[^a-zA-Z0-9_-]/, '_')
        end
      end
    end
  end
end
