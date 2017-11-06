# Copyright (c) 2008-2017 Minero Aoki, Kenshi Muto, Masayoshi Takahashi,
#                         KADO Masanori
#               2002-2007 Minero Aoki
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

require 'review/builder'
require 'review/htmlutils'
require 'review/template'
require 'review/textutils'
require 'review/webtocprinter'
require 'digest'
require 'tmpdir'

module ReVIEW
  class HTMLBuilder < Builder
    include TextUtils
    include HTMLUtils

    [:ref].each { |e| Compiler.definline(e) }
    Compiler.defblock(:planning, 0..1)
    Compiler.defblock(:best, 0..1)
    Compiler.defblock(:security, 0..1)
    Compiler.defblock(:point, 0..1)
    Compiler.defblock(:shoot, 0..1)

    def pre_paragraph
      '<p>'
    end

    def post_paragraph
      '</p>'
    end

    def extname
      ".#{@book.config['htmlext']}"
    end

    def builder_init(no_error = false)
      @no_error = no_error
      @noindent = nil
      @ol_num = nil
      @error_messages = nil
      @warning_messages = nil
    end
    private :builder_init

    def builder_init_file
      @warns = []
      @errors = []
      @chapter.book.image_types = %w[.png .jpg .jpeg .gif .svg]
      @column = 0
      @sec_counter = SecCounter.new(5, @chapter)
      @nonum_counter = 0
      @first_line_num = nil
      @body_ext = nil
      @toc = nil
    end
    private :builder_init_file

    def layoutfile
      if @book.config.maker == 'webmaker'
        htmldir = 'web/html'
        localfilename = 'layout-web.html.erb'
      else
        htmldir = 'html'
        localfilename = 'layout.html.erb'
      end
      if @book.htmlversion == 5
        htmlfilename = File.join(htmldir, 'layout-html5.html.erb')
      else
        htmlfilename = File.join(htmldir, 'layout-xhtml1.html.erb')
      end

      layout_file = File.join(@book.basedir, 'layouts', localfilename)
      if !File.exist?(layout_file) && File.exist?(File.join(@book.basedir, 'layouts', 'layout.erb'))
        raise ReVIEW::ConfigError, 'layout.erb is obsoleted. Please use layout.html.erb.'
      end
      if File.exist?(layout_file)
        if ENV['REVIEW_SAFE_MODE'].to_i & 4 > 0
          warn %Q(user's layout is prohibited in safe mode. ignored.)
          layout_file = File.expand_path(htmlfilename, ReVIEW::Template::TEMPLATE_DIR)
        end
      else
        layout_file = File.expand_path(htmlfilename, ReVIEW::Template::TEMPLATE_DIR)
      end
      layout_file
    end

    def result
      # default XHTML header/footer
      @title = strip_html(compile_inline(@chapter.title))
      @body = @output.string
      @language = @book.config['language']
      @stylesheets = @book.config['stylesheet']
      @next = @chapter.next_chapter
      @prev = @chapter.prev_chapter
      @next_title = @next ? compile_inline(@next.title) : ''
      @prev_title = @prev ? compile_inline(@prev.title) : ''

      @toc = ReVIEW::WEBTOCPrinter.book_to_string(@book) if @book.config.maker == 'webmaker'

      ReVIEW::Template.load(layoutfile).result(binding)
    end

    def xmlns_ops_prefix
      if @book.config['epubversion'].to_i == 3
        'epub'
      else
        'ops'
      end
    end

    def headline(level, label, caption)
      prefix, anchor = headline_prefix(level)
      prefix = %Q(<span class="secno">#{prefix}</span>) if prefix
      puts '' if level > 1
      a_id = ''
      a_id = %Q(<a id="h#{anchor}"></a>) if anchor

      if caption.empty?
        puts a_id if label
      elsif label
        puts %Q(<h#{level} id="#{normalize_id(label)}">#{a_id}#{prefix}#{compile_inline(caption)}</h#{level}>)
      else
        puts %Q(<h#{level}>#{a_id}#{prefix}#{compile_inline(caption)}</h#{level}>)
      end
    end

    def nonum_begin(level, label, caption)
      @nonum_counter += 1
      puts if level > 1
      return unless caption.present?
      if label
        puts %Q(<h#{level} id="#{normalize_id(label)}">#{compile_inline(caption)}</h#{level}>)
      else
        id = normalize_id("#{@chapter.name}_nonum#{@nonum_counter}")
        puts %Q(<h#{level} id="#{id}">#{compile_inline(caption)}</h#{level}>)
      end
    end

    def nonum_end(level)
    end

    def notoc_begin(level, label, caption)
      @nonum_counter += 1
      puts if level > 1
      return unless caption.present?
      if label
        puts %Q(<h#{level} id="#{normalize_id(label)}" notoc="true">#{compile_inline(caption)}</h#{level}>)
      else
        id = normalize_id("#{@chapter.name}_nonum#{@nonum_counter}")
        puts %Q(<h#{level} id="#{id}" notoc="true">#{compile_inline(caption)}</h#{level}>)
      end
    end

    def notoc_end(level)
    end

    def nodisp_begin(level, label, caption)
      @nonum_counter += 1
      puts '' if level > 1
      return unless caption.present?
      if label
        puts %Q(<a id="#{normalize_id(label)}" /><h#{level} id="#{normalize_id(label)}" hidden="true">#{compile_inline(caption)}</h#{level}>)
      else
        id = normalize_id("#{@chapter.name}_nonum#{@nonum_counter}")
        puts %Q(<a id="#{id}" /><h#{level} id="#{id}" hidden="true">#{compile_inline(caption)}</h#{level}>)
      end
    end

    def nodisp_end(level)
    end

    def column_begin(level, label, caption)
      puts %Q(<div class="column">)

      @column += 1
      puts if level > 1
      a_id = %Q(<a id="column-#{@column}"></a>)

      if caption.empty?
        puts a_id if label
      elsif label
        puts %Q(<h#{level} id="#{normalize_id(label)}">#{a_id}#{compile_inline(caption)}</h#{level}>)
      else
        puts %Q(<h#{level}>#{a_id}#{compile_inline(caption)}</h#{level}>)
      end
    end

    def column_end(_level)
      puts '</div>'
    end

    def xcolumn_begin(level, label, caption)
      puts %Q(<div class="xcolumn">)
      headline(level, label, caption)
    end

    def xcolumn_end(_level)
      puts '</div>'
    end

    def ref_begin(level, label, caption)
      print %Q(<div class="reference">)
      headline(level, label, caption)
    end

    def ref_end(_level)
      puts '</div>'
    end

    def sup_begin(level, label, caption)
      print %Q(<div class="supplement">)
      headline(level, label, caption)
    end

    def sup_end(_level)
      puts '</div>'
    end

    def captionblock(type, lines, caption)
      puts %Q(<div class="#{type}">)
      puts %Q(<p class="caption">#{compile_inline(caption)}</p>) if caption.present?
      blocked_lines = split_paragraph(lines)
      puts blocked_lines.join("\n")
      puts '</div>'
    end

    def memo(lines, caption = nil)
      captionblock('memo', lines, caption)
    end

    def tip(lines, caption = nil)
      captionblock('tip', lines, caption)
    end

    def info(lines, caption = nil)
      captionblock('info', lines, caption)
    end

    def planning(lines, caption = nil)
      captionblock('planning', lines, caption)
    end

    def best(lines, caption = nil)
      captionblock('best', lines, caption)
    end

    def important(lines, caption = nil)
      captionblock('important', lines, caption)
    end

    def security(lines, caption = nil)
      captionblock('security', lines, caption)
    end

    def caution(lines, caption = nil)
      captionblock('caution', lines, caption)
    end

    def notice(lines, caption = nil)
      captionblock('notice', lines, caption)
    end

    def warning(lines, caption = nil)
      captionblock('warning', lines, caption)
    end

    def point(lines, caption = nil)
      captionblock('point', lines, caption)
    end

    def shoot(lines, caption = nil)
      captionblock('shoot', lines, caption)
    end

    def box(lines, caption = nil)
      puts %Q(<div class="syntax">)
      puts %Q(<p class="caption">#{compile_inline(caption)}</p>) if caption.present?
      print %Q(<pre class="syntax">)
      lines.each { |line| puts detab(line) }
      puts '</pre>'
      puts '</div>'
    end

    def note(lines, caption = nil)
      captionblock('note', lines, caption)
    end

    def ul_begin
      puts '<ul>'
    end

    def ul_item_begin(lines)
      print "<li>#{lines.join}"
    end

    def ul_item_end
      puts '</li>'
    end

    def ul_end
      puts '</ul>'
    end

    def ol_begin
      if @ol_num
        puts %Q(<ol start="#{@ol_num}">) # it's OK in HTML5, but not OK in XHTML1.1
        @ol_num = nil
      else
        puts '<ol>'
      end
    end

    def ol_item(lines, _num)
      puts "<li>#{lines.join}</li>"
    end

    def ol_end
      puts '</ol>'
    end

    def dl_begin
      puts '<dl>'
    end

    def dt(line)
      puts "<dt>#{line}</dt>"
    end

    def dd(lines)
      puts "<dd>#{lines.join}</dd>"
    end

    def dl_end
      puts '</dl>'
    end

    def paragraph(lines)
      if @noindent
        puts %Q(<p class="noindent">#{lines.join}</p>)
        @noindent = nil
      else
        puts "<p>#{lines.join}</p>"
      end
    end

    def parasep
      puts '<br />'
    end

    def read(lines)
      blocked_lines = split_paragraph(lines)
      puts %Q(<div class="lead">\n#{blocked_lines.join("\n")}\n</div>)
    end

    alias_method :lead, :read

    def list(lines, id, caption, lang = nil)
      puts %Q(<div id="#{normalize_id(id)}" class="caption-code">)
      begin
        list_header id, caption, lang
      rescue KeyError
        error "no such list: #{id}"
      end
      list_body id, lines, lang
      puts '</div>'
    end

    def list_header(id, caption, _lang)
      if get_chap
        puts %Q(<p class="caption">#{I18n.t('list')}#{I18n.t('format_number_header', [get_chap, @chapter.list(id).number])}#{I18n.t('caption_prefix')}#{compile_inline(caption)}</p>)
      else
        puts %Q(<p class="caption">#{I18n.t('list')}#{I18n.t('format_number_header_without_chapter', [@chapter.list(id).number])}#{I18n.t('caption_prefix')}#{compile_inline(caption)}</p>)
      end
    end

    def list_body(id, lines, lang)
      id ||= ''
      class_names = ['list']
      lexer = lang || File.extname(id).gsub('.', '')
      class_names.push("language-#{lexer}") unless lexer.blank?
      class_names.push('highlight') if highlight?
      print %Q(<pre class="#{class_names.join(' ')}">)
      body = lines.inject('') { |i, j| i + detab(j) + "\n" }
      puts highlight(body: body, lexer: lexer, format: 'html')
      puts '</pre>'
    end

    def source(lines, caption = nil, lang = nil)
      puts %Q(<div class="source-code">)
      source_header caption
      source_body caption, lines, lang
      puts '</div>'
    end

    def source_header(caption)
      puts %Q(<p class="caption">#{compile_inline(caption)}</p>) if caption.present?
    end

    def source_body(id, lines, lang)
      id ||= ''
      print %Q(<pre class="source">)
      body = lines.inject('') { |i, j| i + detab(j) + "\n" }
      lexer = lang || File.extname(id).gsub('.', '')
      puts highlight(body: body, lexer: lexer, format: 'html')
      puts '</pre>'
    end

    def listnum(lines, id, caption, lang = nil)
      puts %Q(<div id="#{normalize_id(id)}" class="code">)
      begin
        list_header id, caption, lang
      rescue KeyError
        error "no such list: #{id}"
      end
      listnum_body lines, lang
      puts '</div>'
    end

    def listnum_body(lines, lang)
      if highlight?
        body = lines.inject('') { |i, j| i + detab(j) + "\n" }
        lexer = lang
        first_line_number = line_num
        puts highlight(body: body, lexer: lexer, format: 'html', linenum: true,
                       options: { linenostart: first_line_number })
      else
        class_names = ['list']
        class_names.push("language-#{lang}") unless lang.blank?
        class_names.push('highlight') if highlight?
        print %Q(<pre class="#{class_names.join(' ')}">)
        first_line_num = line_num
        lines.each_with_index { |line, i| puts detab((i + first_line_num).to_s.rjust(2) + ': ' + line) }
        puts '</pre>'
      end
    end

    def emlist(lines, caption = nil, lang = nil)
      puts %Q(<div class="emlist-code">)
      puts %Q(<p class="caption">#{compile_inline(caption)}</p>) if caption.present?
      class_names = ['emlist']
      class_names.push("language-#{lang}") unless lang.blank?
      class_names.push('highlight') if highlight?
      print %Q(<pre class="#{class_names.join(' ')}">)
      body = lines.inject('') { |i, j| i + detab(j) + "\n" }
      lexer = lang
      puts highlight(body: body, lexer: lexer, format: 'html')
      puts '</pre>'
      puts '</div>'
    end

    def emlistnum(lines, caption = nil, lang = nil)
      puts %Q(<div class="emlistnum-code">)
      puts %Q(<p class="caption">#{compile_inline(caption)}</p>) if caption.present?

      if highlight?
        body = lines.inject('') { |i, j| i + detab(j) + "\n" }
        lexer = lang
        first_line_number = line_num
        puts highlight(body: body, lexer: lexer, format: 'html', linenum: true,
                       options: { linenostart: first_line_number })
      else
        class_names = ['emlist']
        class_names.push("language-#{lang}") unless lang.blank?
        class_names.push('highlight') if highlight?
        print %Q(<pre class="#{class_names.join(' ')}">)
        first_line_num = line_num
        lines.each_with_index { |line, i| puts detab((i + first_line_num).to_s.rjust(2) + ': ' + line) }
        puts '</pre>'
      end

      puts '</div>'
    end

    def cmd(lines, caption = nil)
      puts %Q(<div class="cmd-code">)
      puts %Q(<p class="caption">#{compile_inline(caption)}</p>) if caption.present?
      print %Q(<pre class="cmd">)
      body = lines.inject('') { |i, j| i + detab(j) + "\n" }
      lexer = 'shell-session'
      puts highlight(body: body, lexer: lexer, format: 'html')
      puts '</pre>'
      puts '</div>'
    end

    def quotedlist(lines, css_class)
      print %Q(<blockquote><pre class="#{css_class}">)
      lines.each { |line| puts detab(line) }
      puts '</pre></blockquote>'
    end
    private :quotedlist

    def quote(lines)
      blocked_lines = split_paragraph(lines)
      puts %Q(<blockquote>#{blocked_lines.join("\n")}</blockquote>)
    end

    def doorquote(lines, ref)
      blocked_lines = split_paragraph(lines)
      puts %Q(<blockquote style="text-align:right;">)
      puts blocked_lines.join("\n")
      puts %Q(<p>#{ref}より</p>)
      puts '</blockquote>'
    end

    def talk(lines)
      puts %Q(<div class="talk">)
      blocked_lines = split_paragraph(lines)
      puts blocked_lines.join("\n")
      puts '</div>'
    end

    def texequation(lines)
      puts %Q(<div class="equation">)
      if @book.config['mathml']
        require 'math_ml'
        require 'math_ml/symbol/character_reference'
        p = MathML::LaTeX::Parser.new(symbol: MathML::Symbol::CharacterReference)
        puts p.parse(unescape_html(lines.join("\n")), true)
      elsif @book.config['imgmath']
        puts %Q(<div class="equation">)
        math_str = "\\begin{equation*}\n" + unescape_html(lines.join("\n")) + "\n\\end{equation*}\n"
        key = Digest::SHA256.hexdigest(math_str)
        math_dir = "./#{@book.config['imagedir']}/_review_math"
        Dir.mkdir(math_dir) unless Dir.exist?(math_dir)
        img_path = "./#{math_dir}/_gen_#{key}.png"
        make_math_image(math_str, img_path)
        puts %Q(<img src="#{img_path}" />)
        puts '</div>'
      else
        print '<pre>'
        puts lines.join("\n")
        puts '</pre>'
      end
      puts '</div>'
    end

    def handle_metric(str)
      return { 'class' => sprintf('width-%03dper', ($1.to_f * 100).round) } if str =~ /\Ascale=([\d.]+)\Z/

      k, v = str.split('=', 2)
      { k => v.sub(/\A["']/, '').sub(/["']\Z/, '') }
    end

    def result_metric(array)
      attrs = {}
      array.each do |item|
        k = item.keys[0]
        if attrs[k]
          attrs[k] << item[k]
        else
          attrs[k] = [item[k]]
        end
      end
      ' ' + attrs.map { |k, v| %Q(#{k}="#{v.join(' ')}") }.join(' ')
    end

    def image_image(id, caption, metric)
      metrics = parse_metric('html', metric)
      puts %Q(<div id="#{normalize_id(id)}" class="image">)
      puts %Q(<img src="#{@chapter.image(id).path.sub(%r{\A\./}, '')}" alt="#{escape_html(compile_inline(caption))}"#{metrics} />)
      image_header id, caption
      puts '</div>'
    end

    def image_dummy(id, caption, lines)
      warn "image not bound: #{id}"
      puts %Q(<div id="#{normalize_id(id)}" class="image">)
      puts %Q(<pre class="dummyimage">)
      lines.each { |line| puts detab(line) }
      puts '</pre>'
      image_header id, caption
      puts '</div>'
    end

    def image_header(id, caption)
      puts %Q(<p class="caption">)
      if get_chap
        puts %Q(#{I18n.t('image')}#{I18n.t('format_number_header', [get_chap, @chapter.image(id).number])}#{I18n.t('caption_prefix')}#{compile_inline(caption)})
      else
        puts %Q(#{I18n.t('image')}#{I18n.t('format_number_header_without_chapter', [@chapter.image(id).number])}#{I18n.t('caption_prefix')}#{compile_inline(caption)})
      end
      puts '</p>'
    end

    def table(lines, id = nil, caption = nil)
      rows = []
      sepidx = nil
      lines.each_with_index do |line, idx|
        if /\A[\=\-]{12}/ =~ line
          # just ignore
          # error "too many table separator" if sepidx
          sepidx ||= idx
          next
        end
        rows.push(line.strip.split(/\t+/).map { |s| s.sub(/\A\./, '') })
      end
      rows = adjust_n_cols(rows)

      if id
        puts %Q(<div id="#{normalize_id(id)}" class="table">)
      else
        puts %Q(<div class="table">)
      end
      begin
        table_header id, caption if caption.present?
      rescue KeyError
        error "no such table: #{id}"
      end
      table_begin rows.first.size
      return if rows.empty?
      if sepidx
        sepidx.times { tr(rows.shift.map { |s| th(s) }) }
        rows.each { |cols| tr(cols.map { |s| td(s) }) }
      else
        rows.each do |cols|
          h, *cs = *cols
          tr([th(h)] + cs.map { |s| td(s) })
        end
      end
      table_end
      puts '</div>'
    end

    def table_header(id, caption)
      if id.nil?
        puts %Q(<p class="caption">#{compile_inline(caption)}</p>)
      elsif get_chap
        puts %Q(<p class="caption">#{I18n.t('table')}#{I18n.t('format_number_header', [get_chap, @chapter.table(id).number])}#{I18n.t('caption_prefix')}#{compile_inline(caption)}</p>)
      else
        puts %Q(<p class="caption">#{I18n.t('table')}#{I18n.t('format_number_header_without_chapter', [@chapter.table(id).number])}#{I18n.t('caption_prefix')}#{compile_inline(caption)}</p>)
      end
    end

    def table_begin(_ncols)
      puts '<table>'
    end

    def tr(rows)
      puts "<tr>#{rows.join}</tr>"
    end

    def th(str)
      "<th>#{str}</th>"
    end

    def td(str)
      "<td>#{str}</td>"
    end

    def table_end
      puts '</table>'
    end

    def imgtable(lines, id, caption = nil, metric = nil)
      unless @chapter.image(id).bound?
        warn "image not bound: #{id}"
        image_dummy id, caption, lines
        return
      end

      puts %Q(<div id="#{normalize_id(id)}" class="imgtable image">)
      begin
        table_header id, caption if caption.present?
      rescue KeyError
        error "no such table: #{id}"
      end

      imgtable_image(id, caption, metric)

      puts '</div>'
    end

    def imgtable_image(id, caption, metric)
      metrics = parse_metric('html', metric)
      puts %Q(<img src="#{@chapter.image(id).path.sub(%r{\A\./}, '')}" alt="#{escape_html(compile_inline(caption))}"#{metrics} />)
    end

    def emtable(lines, caption = nil)
      table(lines, nil, caption)
    end

    def comment(lines, comment = nil)
      lines ||= []
      lines.unshift comment unless comment.blank?
      return unless @book.config['draft']
      str = lines.join('<br />')
      puts %Q(<div class="draft-comment">#{escape_html(str)}</div>)
    end

    def footnote(id, str)
      if @book.config['epubversion'].to_i == 3
        puts %Q(<div class="footnote" epub:type="footnote" id="fn-#{normalize_id(id)}"><p class="footnote">[*#{@chapter.footnote(id).number}] #{compile_inline(str)}</p></div>)
      else
        puts %Q(<div class="footnote" id="fn-#{normalize_id(id)}"><p class="footnote">[<a href="#fnb-#{normalize_id(id)}">*#{@chapter.footnote(id).number}</a>] #{compile_inline(str)}</p></div>)
      end
    end

    def indepimage(lines, id, caption = '', metric = nil)
      metrics = parse_metric('html', metric)
      caption = '' unless caption.present?
      puts %Q(<div id="#{normalize_id(id)}" class="image">)
      begin
        puts %Q(<img src="#{@chapter.image(id).path.sub(%r{\A\./}, '')}" alt="#{escape_html(compile_inline(caption))}"#{metrics} />)
      rescue
        warn "image not bound: #{id}"
        if lines
          puts %Q(<pre class="dummyimage">)
          lines.each { |line| puts detab(line) }
          puts '</pre>'
        end
      end

      if caption.present?
        puts %Q(<p class="caption">)
        puts %Q(#{I18n.t('numberless_image')}#{I18n.t('caption_prefix')}#{compile_inline(caption)})
        puts '</p>'
      end
      puts '</div>'
    end

    alias_method :numberlessimage, :indepimage

    def hr
      puts '<hr />'
    end

    def label(id)
      puts %Q(<a id="#{normalize_id(id)}"></a>)
    end

    def linebreak
      puts '<br />'
    end

    def pagebreak
      puts %Q(<br class="pagebreak" />)
    end

    def bpo(lines)
      puts '<bpo>'
      lines.each { |line| puts detab(line) }
      puts '</bpo>'
    end

    def noindent
      @noindent = true
    end

    def inline_labelref(idref)
      %Q(<a target='#{escape_html(idref)}'>「#{I18n.t('label_marker')}#{escape_html(idref)}」</a>)
    end

    alias_method :inline_ref, :inline_labelref

    def inline_pageref(id)
      error "pageref op is unsupported on this builder: #{id}"
    end

    def inline_chapref(id)
      title = super
      if @book.config['chapterlink']
        %Q(<a href="./#{id}#{extname}">#{title}</a>)
      else
        title
      end
    rescue KeyError
      error "unknown chapter: #{id}"
      nofunc_text("[UnknownChapter:#{id}]")
    end

    def inline_chap(id)
      if @book.config['chapterlink']
        %Q(<a href="./#{id}#{extname}">#{@book.chapter_index.number(id)}</a>)
      else
        @book.chapter_index.number(id)
      end
    rescue KeyError
      error "unknown chapter: #{id}"
      nofunc_text("[UnknownChapter:#{id}]")
    end

    def inline_title(id)
      title = super
      if @book.config['chapterlink']
        %Q(<a href="./#{id}#{extname}">#{title}</a>)
      else
        title
      end
    rescue KeyError
      error "unknown chapter: #{id}"
      nofunc_text("[UnknownChapter:#{id}]")
    end

    def inline_fn(id)
      if @book.config['epubversion'].to_i == 3
        %Q(<a id="fnb-#{normalize_id(id)}" href="#fn-#{normalize_id(id)}" class="noteref" epub:type="noteref">*#{@chapter.footnote(id).number}</a>)
      else
        %Q(<a id="fnb-#{normalize_id(id)}" href="#fn-#{normalize_id(id)}" class="noteref">*#{@chapter.footnote(id).number}</a>)
      end
    end

    def compile_ruby(base, ruby)
      if @book.htmlversion == 5
        %Q(<ruby>#{escape_html(base)}<rp>#{I18n.t('ruby_prefix')}</rp><rt>#{escape_html(ruby)}</rt><rp>#{I18n.t('ruby_postfix')}</rp></ruby>)
      else
        %Q(<ruby><rb>#{escape_html(base)}</rb><rp>#{I18n.t('ruby_prefix')}</rp><rt>#{ruby}</rt><rp>#{I18n.t('ruby_postfix')}</rp></ruby>)
      end
    end

    def compile_kw(word, alt)
      %Q(<b class="kw">) +
        if alt
        then escape_html(word + " (#{alt.strip})")
        else escape_html(word)
        end +
        "</b><!-- IDX:#{escape_comment(escape_html(word))} -->"
    end

    def inline_i(str)
      %Q(<i>#{escape_html(str)}</i>)
    end

    def inline_b(str)
      %Q(<b>#{escape_html(str)}</b>)
    end

    def inline_ami(str)
      %Q(<span class="ami">#{escape_html(str)}</span>)
    end

    def inline_bou(str)
      %Q(<span class="bou">#{escape_html(str)}</span>)
    end

    def inline_tti(str)
      if @book.htmlversion == 5
        %Q(<code class="tt"><i>#{escape_html(str)}</i></code>)
      else
        %Q(<tt><i>#{escape_html(str)}</i></tt>)
      end
    end

    def inline_ttb(str)
      if @book.htmlversion == 5
        %Q(<code class="tt"><b>#{escape_html(str)}</b></code>)
      else
        %Q(<tt><b>#{escape_html(str)}</b></tt>)
      end
    end

    def inline_dtp(str)
      "<?dtp #{str} ?>"
    end

    def inline_code(str)
      if @book.htmlversion == 5
        %Q(<code class="inline-code tt">#{escape_html(str)}</code>)
      else
        %Q(<tt class="inline-code">#{escape_html(str)}</tt>)
      end
    end

    def inline_idx(str)
      %Q(#{escape_html(str)}<!-- IDX:#{escape_comment(escape_html(str))} -->)
    end

    def inline_hidx(str)
      %Q(<!-- IDX:#{escape_comment(escape_html(str))} -->)
    end

    def inline_br(_str)
      '<br />'
    end

    def inline_m(str)
      if @book.config['mathml']
        require 'math_ml'
        require 'math_ml/symbol/character_reference'
        parser = MathML::LaTeX::Parser.new(symbol: MathML::Symbol::CharacterReference)
        %Q(<span class="equation">#{parser.parse(str, nil)}</span>)
      elsif @book.config['imgmath']
        math_str = '$' + str + '$'
        key = Digest::SHA256.hexdigest(str)
        math_dir = "./#{@book.config['imagedir']}/_review_math"
        Dir.mkdir(math_dir) unless Dir.exist?(math_dir)
        img_path = "./#{math_dir}/_gen_#{key}.png"
        make_math_image(math_str, img_path)
        %Q(<span class="equation"><img src="#{img_path}" /></span>)
      else
        %Q(<span class="equation">#{escape_html(str)}</span>)
      end
    end

    def text(str)
      str
    end

    def bibpaper(lines, id, caption)
      puts %Q(<div class="bibpaper">)
      bibpaper_header id, caption
      bibpaper_bibpaper id, caption, lines unless lines.empty?
      puts '</div>'
    end

    def bibpaper_header(id, caption)
      print %Q(<a id="bib-#{normalize_id(id)}">)
      print "[#{@chapter.bibpaper(id).number}]"
      print '</a>'
      puts " #{compile_inline(caption)}"
    end

    def bibpaper_bibpaper(_id, _caption, lines)
      print split_paragraph(lines).join
    end

    def inline_bib(id)
      %Q(<a href="#{@book.bib_file.gsub(/\.re\Z/, ".#{@book.config['htmlext']}")}#bib-#{normalize_id(id)}">[#{@chapter.bibpaper(id).number}]</a>)
    end

    def inline_hd_chap(chap, id)
      n = chap.headline_index.number(id)
      if chap.number and @book.config['secnolevel'] >= n.split('.').size
        str = I18n.t('chapter_quote', "#{n} #{compile_inline(chap.headline(id).caption)}")
      else
        str = I18n.t('chapter_quote', compile_inline(chap.headline(id).caption))
      end
      if @book.config['chapterlink']
        anchor = 'h' + n.gsub('.', '-')
        %Q(<a href="#{chap.id}#{extname}##{anchor}">#{str}</a>)
      else
        str
      end
    end

    def column_label(id, chapter = @chapter)
      num = chapter.column(id).number
      "column-#{num}"
    end
    private :column_label

    def inline_column_chap(chapter, id)
      if @book.config['chapterlink']
        %Q(<a href="\##{column_label(id, chapter)}" class="columnref">#{I18n.t('column', compile_inline(chapter.column(id).caption))}</a>)
      else
        I18n.t('column', compile_inline(chapter.column(id).caption))
      end
    end

    def inline_list(id)
      chapter, id = extract_chapter_id(id)
      str =
        if get_chap(chapter)
          "#{I18n.t('list')}#{I18n.t('format_number', [get_chap(chapter), chapter.list(id).number])}"
        else
          "#{I18n.t('list')}#{I18n.t('format_number_without_chapter', [chapter.list(id).number])}"
        end
      if @book.config['chapterlink']
        %Q(<span class="listref"><a href="./#{chapter.id}#{extname}##{id}">#{str}</a></span>)
      else
        %Q(<span class="listref">#{str}</span>)
      end
    rescue KeyError
      error "unknown list: #{id}"
      nofunc_text("[UnknownList:#{id}]")
    end

    def inline_table(id)
      chapter, id = extract_chapter_id(id)
      str =
        if get_chap(chapter)
          "#{I18n.t('table')}#{I18n.t('format_number', [get_chap(chapter), chapter.table(id).number])}"
        else
          "#{I18n.t('table')}#{I18n.t('format_number_without_chapter', [chapter.table(id).number])}"
        end
      if @book.config['chapterlink']
        %Q(<span class="tableref"><a href="./#{chapter.id}#{extname}##{id}">#{str}</a></span>)
      else
        %Q(<span class="tableref">#{str}</span>)
      end
    rescue KeyError
      error "unknown table: #{id}"
      nofunc_text("[UnknownTable:#{id}]")
    end

    def inline_img(id)
      chapter, id = extract_chapter_id(id)
      str =
        if get_chap(chapter)
          "#{I18n.t('image')}#{I18n.t('format_number', [get_chap(chapter), chapter.image(id).number])}"
        else
          "#{I18n.t('image')}#{I18n.t('format_number_without_chapter', [chapter.image(id).number])}"
        end
      if @book.config['chapterlink']
        %Q(<span class="imgref"><a href="./#{chapter.id}#{extname}##{normalize_id(id)}">#{str}</a></span>)
      else
        %Q(<span class="imgref">#{str}</span>)
      end
    rescue KeyError
      error "unknown image: #{id}"
      nofunc_text("[UnknownImage:#{id}]")
    end

    def inline_asis(str, tag)
      %Q(<#{tag}>#{escape_html(str)}</#{tag}>)
    end

    def inline_abbr(str)
      inline_asis(str, 'abbr')
    end

    def inline_acronym(str)
      inline_asis(str, 'acronym')
    end

    def inline_cite(str)
      inline_asis(str, 'cite')
    end

    def inline_dfn(str)
      inline_asis(str, 'dfn')
    end

    def inline_em(str)
      inline_asis(str, 'em')
    end

    def inline_kbd(str)
      inline_asis(str, 'kbd')
    end

    def inline_samp(str)
      inline_asis(str, 'samp')
    end

    def inline_strong(str)
      inline_asis(str, 'strong')
    end

    def inline_var(str)
      inline_asis(str, 'var')
    end

    def inline_big(str)
      inline_asis(str, 'big')
    end

    def inline_small(str)
      inline_asis(str, 'small')
    end

    def inline_sub(str)
      inline_asis(str, 'sub')
    end

    def inline_sup(str)
      inline_asis(str, 'sup')
    end

    def inline_tt(str)
      if @book.htmlversion == 5
        %Q(<code class="tt">#{escape_html(str)}</code>)
      else
        %Q(<tt>#{escape_html(str)}</tt>)
      end
    end

    def inline_del(str)
      inline_asis(str, 'del')
    end

    def inline_ins(str)
      inline_asis(str, 'ins')
    end

    def inline_u(str)
      %Q(<u>#{escape_html(str)}</u>)
    end

    def inline_recipe(str)
      %Q(<span class="recipe">「#{escape_html(str)}」</span>)
    end

    def inline_icon(id)
      begin
        %Q(<img src="#{@chapter.image(id).path.sub(%r{\A\./}, '')}" alt="[#{id}]" />)
      rescue
        warn "image not bound: #{id}"
        %Q(<pre>missing image: #{id}</pre>)
      end
    end

    def inline_uchar(str)
      %Q(&#x#{str};)
    end

    def inline_comment(str)
      if @book.config['draft']
        %Q(<span class="draft-comment">#{escape_html(str)}</span>)
      else
        ''
      end
    end

    def inline_tcy(str)
      # 縦中横用のtcy、uprightのCSSスタイルについては電書協ガイドラインを参照
      style = 'tcy'
      style = 'upright' if str.size == 1 && str.match(/[[:ascii:]]/)
      %Q(<span class="#{style}">#{escape_html(str)}</span>)
    end

    def inline_raw(str)
      super(str)
    end

    def nofunc_text(str)
      escape_html(str)
    end

    def compile_href(url, label)
      if @book.config['externallink']
        %Q(<a href="#{escape_html(url)}" class="link">#{label.nil? ? escape_html(url) : escape_html(label)}</a>)
      else
        label.nil? ? escape_html(url) : I18n.t('external_link', [escape_html(label), escape_html(url)])
      end
    end

    def flushright(lines)
      puts split_paragraph(lines).join("\n").gsub('<p>', %Q(<p class="flushright">))
    end

    def centering(lines)
      puts split_paragraph(lines).join("\n").gsub('<p>', %Q(<p class="center">))
    end

    def image_ext
      'png'
    end

    def olnum(num)
      @ol_num = num.to_i
    end

    def make_math_image(str, path, fontsize = 12)
      fontsize2 = (fontsize * 1.2).round.to_i
      texsrc = <<-EOB
\\documentclass[12pt]{article}
\\usepackage[utf8]{inputenc}
\\usepackage{amsmath}
\\usepackage{amsthm}
\\usepackage{amssymb}
\\usepackage{amsfonts}
\\usepackage{anyfontsize}
\\usepackage{bm}
\\pagestyle{empty}

\\begin{document}
\\fontsize{#{fontsize}}{#{fontsize2}}\\selectfont #{str}
\\end{document}
      EOB
      Dir.mktmpdir do |tmpdir|
        tex_path = File.join(tmpdir, 'tmpmath.tex')
        dvi_path = File.join(tmpdir, 'tmpmath.dvi')
        File.write(tex_path, texsrc)
        system("latex --interaction=nonstopmode --output-directory=#{tmpdir} #{tex_path} && dvipng -T tight -z9 -o #{path} #{dvi_path}")
      end
    end
  end
end # module ReVIEW
