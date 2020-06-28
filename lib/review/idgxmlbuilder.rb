# Copyright (c) 2008-2020 Minero Aoki, Kenshi Muto
#               2002-2007 Minero Aoki
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

require 'review/builder'
require 'review/htmlutils'
require 'review/textutils'
require 'nkf'

module ReVIEW
  class IDGXMLBuilder < Builder
    include TextUtils
    include HTMLUtils

    %i[ttbold hint maru keytop labelref ref strong em].each do |e|
      Compiler.definline(e)
    end
    Compiler.defsingle(:dtp, 1)

    Compiler.defblock(:insn, 0..1)
    Compiler.defblock(:planning, 0..1)
    Compiler.defblock(:best, 0..1)
    Compiler.defblock(:security, 0..1)
    Compiler.defblock(:point, 0..1)
    Compiler.defblock(:shoot, 0..1)
    Compiler.defblock(:reference, 0)
    Compiler.defblock(:term, 0)
    Compiler.defblock(:link, 0..1)
    Compiler.defblock(:practice, 0)
    Compiler.defblock(:expert, 0)
    Compiler.defblock(:rawblock, 0)

    def pre_paragraph
      '<p>'
    end

    def post_paragraph
      '</p>'
    end

    def extname
      '.xml'
    end

    def builder_init
    end
    private :builder_init

    def builder_init_file
      @warns = []
      @errors = []
      @section = 0
      @subsection = 0
      @subsubsection = 0
      @subsubsubsection = 0
      @sec_counter = SecCounter.new(5, @chapter)
      @column = 0
      @noindent = nil
      @ol_num = nil
      @first_line_num = nil
      @rootelement = 'doc'
      @tsize = nil
      @texblockequation = 0
      @texinlineequation = 0
      print %Q(<?xml version="1.0" encoding="UTF-8"?>\n)
      print %Q(<#{@rootelement} xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/">)
      @secttags = @book.config['structuredxml']
    end
    private :builder_init_file

    def puts(arg)
      if @book.config['nolf'].present?
        print arg
      else
        super
      end
    end

    def result
      s = ''
      if @secttags
        s += '</sect4>' if @subsubsubsection > 0
        s += '</sect3>' if @subsubsection > 0
        s += '</sect2>' if @subsection > 0
        s += '</sect>' if @section > 0
        s += '</chapter>' if @chapter.number > 0
      end
      @output.string + s + "</#{@rootelement}>\n"
    end

    def headline(level, label, caption)
      case level
      when 1
        if @secttags
          print '</sect4>' if @subsubsubsection > 0
          print '</sect3>' if @subsubsection > 0
          print '</sect2>' if @subsection > 0
          print '</sect>' if @section > 0
        end

        print %Q(<chapter id="chap:#{@chapter.number}">) if @secttags

        @section = 0
        @subsection = 0
        @subsubsection = 0
        @subsubsubsection = 0
      when 2
        if @secttags
          print '</sect4>' if @subsubsubsection > 0
          print '</sect3>' if @subsubsection > 0
          print '</sect2>' if @subsection > 0
          print '</sect>' if @section > 0
        end
        @section += 1
        print %Q(<sect id="sect:#{@chapter.number}.#{@section}">) if @secttags

        @subsection = 0
        @subsubsection = 0
        @subsubsubsection = 0
      when 3
        if @secttags
          print '</sect4>' if @subsubsubsection > 0
          print '</sect3>' if @subsubsection > 0
          print '</sect2>' if @subsection > 0
        end

        @subsection += 1
        print %Q(<sect2 id="sect:#{@chapter.number}.#{@section}.#{@subsection}">) if @secttags

        @subsubsection = 0
        @subsubsubsection = 0
      when 4
        if @secttags
          print '</sect4>' if @subsubsubsection > 0
          print '</sect3>' if @subsubsection > 0
        end

        @subsubsection += 1
        print %Q(<sect3 id="sect:#{@chapter.number}.#{@section}.#{@subsection}.#{@subsubsection}">) if @secttags

        @subsubsubsection = 0
      when 5
        print '</sect4>' if @secttags && @subsubsubsection > 0

        @subsubsubsection += 1
        print %Q(<sect4 id="sect:#{@chapter.number}.#{@section}.#{@subsection}.#{@subsubsection}.#{@subsubsubsection}">) if @secttags
      when 6 # rubocop:disable Lint/EmptyWhen
      else
        raise "caption level too deep or unsupported: #{level}"
      end

      prefix, _anchor = headline_prefix(level)

      label = label.nil? ? '' : %Q( id="#{label}")
      toccaption = escape(compile_inline(caption.gsub(/@<fn>\{.+?\}/, '')).gsub(/<[^>]+>/, ''))
      puts %Q(<title#{label} aid:pstyle="h#{level}">#{prefix}#{compile_inline(caption)}</title><?dtp level="#{level}" section="#{prefix}#{toccaption}"?>)
    end

    def ul_begin
      level = block_given? ? yield : ''
      level = nil if level == 1
      puts "<ul#{level == 1 ? nil : level}>"
    end

    def ul_item_begin(lines)
      print %Q(<li aid:pstyle="ul-item">#{join_lines_to_paragraph(lines).chomp})
    end

    def ul_item_end
      puts '</li>'
    end

    def choice_single_begin
      puts %Q(<choice type='single'>)
    end

    def choice_multi_begin
      puts %Q(<choice type='multi'>)
    end

    def choice_single_end
      puts '</choice>'
    end

    def choice_multi_end
      puts '</choice>'
    end

    def ul_end
      level = block_given? ? yield : ''
      level = nil if level == 1
      puts "</ul#{level}>"
    end

    def ol_begin
      puts '<ol>'
      @ol_num ||= 1
    end

    def ol_item(lines, num)
      puts %Q(<li aid:pstyle="ol-item" olnum="#{@ol_num}" num="#{num}">#{join_lines_to_paragraph(lines).chomp}</li>)
      @ol_num += 1
    end

    def ol_end
      puts '</ol>'
      @ol_num = nil
    end

    def olnum(num)
      @ol_num = num.to_i
    end

    def dl_begin
      puts '<dl>'
    end

    def dt(line)
      puts "<dt>#{line}</dt>"
    end

    def dd(lines)
      puts "<dd>#{join_lines_to_paragraph(lines).chomp}</dd>"
    end

    def dl_end
      puts '</dl>'
    end

    def paragraph(lines)
      if @noindent.nil?
        if lines[0] =~ /\A(\t+)/
          puts %Q(<p inlist="#{$1.size}">#{join_lines_to_paragraph(lines).sub(/\A\t+/, '')}</p>)
        else
          puts "<p>#{join_lines_to_paragraph(lines)}</p>"
        end
      else
        puts %Q(<p aid:pstyle="noindent" noindent='1'>#{join_lines_to_paragraph(lines)}</p>)
        @noindent = nil
      end
    end

    def read(lines)
      puts %Q(<lead>#{split_paragraph(lines).join}</lead>)
    end

    alias_method :lead, :read

    def column_label(id, chapter = @chapter)
      num = chapter.column(id).number
      "column-#{num}"
    end
    private :column_label

    def inline_column_chap(chapter, id)
      if @book.config['chapterlink']
        %Q(<link href="#{column_label(id, chapter)}">#{I18n.t('column', compile_inline(chapter.column(id).caption))}</link>)
      else
        I18n.t('column', compile_inline(chapter.column(id).caption))
      end
    rescue KeyError
      error "unknown column: #{id}"
    end

    def inline_list(id)
      "<span type='list'>#{super(id)}</span>"
    end

    def list_header(id, caption, _lang)
      return true unless caption.present?
      if get_chap.nil?
        puts %Q(<caption>#{I18n.t('list')}#{I18n.t('format_number_without_chapter', [@chapter.list(id).number])}#{I18n.t('caption_prefix_idgxml')}#{compile_inline(caption)}</caption>)
      else
        puts %Q(<caption>#{I18n.t('list')}#{I18n.t('format_number', [get_chap, @chapter.list(id).number])}#{I18n.t('caption_prefix_idgxml')}#{compile_inline(caption)}</caption>)
      end
    end

    def codelines_body(lines)
      no = 1
      lines.each do |line|
        if @book.config['listinfo']
          print %Q(<listinfo line="#{no}")
          print %Q( begin="1") if no == 1
          print %Q( end="#{no}") if no == lines.size
          print '>'
        end
        print detab(line)
        print "\n"
        print '</listinfo>' if @book.config['listinfo']
        no += 1
      end
    end

    def list(lines, id, caption, lang = nil)
      puts '<codelist>'
      super(lines, id, caption, lang)
      puts '</codelist>'
    end

    def list_body(_id, lines, _lang)
      print '<pre>'
      codelines_body(lines)
      print '</pre>'
    end

    def emlist(lines, caption = nil, _lang = nil)
      quotedlist(lines, 'emlist', caption)
    end

    def emlistnum(lines, caption = nil, _lang = nil)
      lines2 = []
      first_line_num = line_num
      lines.each_with_index do |line, i|
        lines2 << detab(%Q(<span type='lineno'>) + (i + first_line_num).to_s.rjust(2) + ': </span>' + line)
      end
      quotedlist(lines2, 'emlistnum', caption)
    end

    def listnum(lines, id, caption, lang = nil)
      puts '<codelist>'
      super(lines, id, caption, lang)
      puts '</codelist>'
    end

    def listnum_body(lines, _lang)
      print '<pre>'
      no = 1
      first_line_num = line_num
      lines.each_with_index do |line, i|
        if @book.config['listinfo']
          print %Q(<listinfo line="#{no}")
          print %Q( begin="1") if no == 1
          print %Q( end="#{no}") if no == lines.size
          print '>'
        end
        print detab(%Q(<span type='lineno'>) + (i + first_line_num).to_s.rjust(2) + ': </span>' + line)
        print "\n"
        print '</listinfo>' if @book.config['listinfo']
        no += 1
      end
      print '</pre>'
    end

    def cmd(lines, caption = nil)
      quotedlist(lines, 'cmd', caption)
    end

    def quotedlist(lines, css_class, caption)
      print %Q(<list type='#{css_class}'>)
      if caption_top?('list') && caption.present?
        puts "<caption aid:pstyle='#{css_class}-title'>#{compile_inline(caption)}</caption>"
      end
      print '<pre>'
      no = 1
      lines.each do |line|
        if @book.config['listinfo']
          print %Q(<listinfo line="#{no}")
          print %Q( begin="1") if no == 1
          print %Q( end="#{no}") if no == lines.size
          print '>'
        end
        print detab(line)
        print "\n"
        print '</listinfo>' if @book.config['listinfo']
        no += 1
      end
      puts '</pre>'
      if !caption_top?('list') && caption.present?
        puts "<caption aid:pstyle='#{css_class}-title'>#{compile_inline(caption)}</caption>"
      end
      puts '</list>'
    end
    private :quotedlist

    def quote(lines)
      blocked_lines = split_paragraph(lines)
      puts "<quote>#{blocked_lines.join}</quote>"
    end

    def inline_table(id)
      "<span type='table'>#{super(id)}</span>"
    end

    def inline_img(id)
      "<span type='image'>#{super(id)}</span>"
    end

    def inline_eq(id)
      "<span type='eq'>#{super(id)}</span>"
    end

    def inline_imgref(id)
      chapter, id = extract_chapter_id(id)
      if chapter.image(id).caption.blank?
        inline_img(id)
      elsif get_chap(chapter).nil?
        "<span type='image'>#{I18n.t('image')}#{I18n.t('format_number_without_chapter', [chapter.image(id).number])}#{I18n.t('image_quote', chapter.image(id).caption)}</span>"
      else
        "<span type='image'>#{I18n.t('image')}#{I18n.t('format_number', [get_chap(chapter), chapter.image(id).number])}#{I18n.t('image_quote', chapter.image(id).caption)}</span>"
      end
    end

    def handle_metric(str)
      k, v = str.split('=', 2)
      %Q(#{k}="#{v.sub(/\A["']/, '').sub(/["']\Z/, '')}")
    end

    def result_metric(array)
      " #{array.join(' ')}"
    end

    def image_image(id, caption, metric = nil)
      metrics = parse_metric('idgxml', metric)
      puts '<img>'
      image_header(id, caption) if caption_top?('image')
      puts %Q(<Image href="file://#{@chapter.image(id).path.sub(%r{\A./}, '')}"#{metrics} />)
      image_header(id, caption) unless caption_top?('image')
      puts '</img>'
    end

    def image_dummy(id, caption, lines)
      puts '<img>'
      image_header(id, caption) if caption_top?('image')
      print %Q(<pre aid:pstyle="dummyimage">)
      lines.each do |line|
        print detab(line)
        print "\n"
      end
      print '</pre>'
      image_header(id, caption) unless caption_top?('image')
      puts '</img>'
      warn "image not bound: #{id}"
    end

    def image_header(id, caption)
      return true unless caption.present?
      if get_chap.nil?
        puts %Q(<caption>#{I18n.t('image')}#{I18n.t('format_number_without_chapter', [@chapter.image(id).number])}#{I18n.t('caption_prefix_idgxml')}#{compile_inline(caption)}</caption>)
      else
        puts %Q(<caption>#{I18n.t('image')}#{I18n.t('format_number', [get_chap, @chapter.image(id).number])}#{I18n.t('caption_prefix_idgxml')}#{compile_inline(caption)}</caption>)
      end
    end

    def texequation(lines, id = nil, caption = '')
      @texblockequation += 1
      caption_str = nil
      if id
        puts '<equationblock>'
        if get_chap.nil?
          caption_str = %Q(<caption>#{I18n.t('equation')}#{I18n.t('format_number_without_chapter', [@chapter.equation(id).number])}#{I18n.t('caption_prefix_idgxml')}#{compile_inline(caption)}</caption>)
        else
          caption_str = %Q(<caption>#{I18n.t('equation')}#{I18n.t('format_number', [get_chap, @chapter.equation(id).number])}#{I18n.t('caption_prefix_idgxml')}#{compile_inline(caption)}</caption>)
        end
        puts caption_str if caption_top?('equation')
      end

      puts %Q(<replace idref="texblock-#{@texblockequation}">)
      puts '<pre>'
      print lines.join("\n")
      puts '</pre>'
      puts '</replace>'

      if id
        puts caption_str unless caption_top?('equation')
        puts '</equationblock>'
      end
    end

    def table(lines, id = nil, caption = nil)
      @tablewidth = nil
      if @book.config['tableopt']
        @tablewidth = @book.config['tableopt'].split(',')[0].to_f / @book.config['pt_to_mm_unit'].to_f
      end
      @col = 0

      sepidx, rows = parse_table_rows(lines)
      puts '<table>'

      begin
        if caption_top?('table') && caption.present?
          table_header(id, caption)
        end

        if @tablewidth.nil?
          print '<tbody>'
        else
          print %Q(<tbody xmlns:aid5="http://ns.adobe.com/AdobeInDesign/5.0/" aid:table="table" aid:trows="#{rows.length}" aid:tcols="#{@col}">)
        end
        @table_id = id
        table_rows(sepidx, rows)
        puts '</tbody>'

        if !caption_top?('table') && caption.present?
          table_header(id, caption)
        end
      rescue KeyError
        error "no such table: #{id}"
      end
      puts '</table>'
      @tsize = nil
    end

    def parse_table_rows(lines)
      sepidx = nil
      rows = []
      lines.each_with_index do |line, idx|
        if /\A[=\-]{12}/ =~ line
          sepidx ||= idx
          next
        end
        if @tablewidth
          rows.push(line.gsub(/\t\.\t/, "\tDUMMYCELLSPLITTER\t").gsub(/\t\.\.\t/, "\t.\t").gsub(/\t\.\Z/, "\tDUMMYCELLSPLITTER").gsub(/\t\.\.\Z/, "\t.").gsub(/\A\./, ''))
        else
          rows.push(line.gsub(/\t\.\t/, "\t\t").gsub(/\t\.\.\t/, "\t.\t").gsub(/\t\.\Z/, "\t").gsub(/\t\.\.\Z/, "\t.").gsub(/\A\./, ''))
        end
        col2 = rows[rows.length - 1].split(table_row_separator_regexp).length
        @col = col2 if col2 > @col
      end
      error 'no rows in the table' if rows.empty?
      [sepidx, rows]
    end

    def table_rows(sepidx, rows)
      cellwidth = []
      if @tablewidth
        if @tsize.nil?
          @col.times { |n| cellwidth[n] = @tablewidth / @col }
        else
          cellwidth = @tsize.split(/\s*,\s*/)
          totallength = 0
          cellwidth.size.times do |n|
            cellwidth[n] = cellwidth[n].to_f / @book.config['pt_to_mm_unit'].to_f
            totallength += cellwidth[n]
            warn "total length exceeds limit for table: #{@table_id}" if totallength > @tablewidth
          end
          if cellwidth.size < @col
            cw = (@tablewidth - totallength) / (@col - cellwidth.size)
            warn "auto cell sizing exceeds limit for table: #{@table_id}" if cw <= 0
            (cellwidth.size..(@col - 1)).each { |i| cellwidth[i] = cw }
          end
        end
      end

      if sepidx
        sepidx.times do |y|
          if @tablewidth.nil?
            puts %Q(<tr type="header">#{rows.shift}</tr>)
          else
            i = 0
            rows.shift.split(table_row_separator_regexp).each_with_index do |cell, x|
              print %Q(<td xyh="#{x + 1},#{y + 1},#{sepidx}" aid:table="cell" aid:theader="1" aid:crows="1" aid:ccols="1" aid:ccolwidth="#{sprintf('%.3f', cellwidth[i])}">#{cell.sub('DUMMYCELLSPLITTER', '')}</td>)
              i += 1
            end
          end
        end
      end
      trputs(@tablewidth, rows, cellwidth, sepidx)
    end

    def trputs(tablewidth, rows, cellwidth, sepidx)
      sepidx = 0 if sepidx.nil?
      if tablewidth
        rows.each_with_index do |row, y|
          i = 0
          row.split(table_row_separator_regexp).each_with_index do |cell, x|
            print %Q(<td xyh="#{x + 1},#{y + 1 + sepidx},#{sepidx}" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="#{sprintf('%.3f', cellwidth[i])}">#{cell.sub('DUMMYCELLSPLITTER', '')}</td>)
            i += 1
          end
        end
      else
        lastline = rows.pop
        rows.each { |row| puts "<tr>#{row}</tr>" }
        puts %Q(<tr type="lastline">#{lastline}</tr>) if lastline
      end
    end

    def table_header(id, caption)
      if id.nil?
        puts %Q(<caption>#{compile_inline(caption)}</caption>)
      elsif get_chap
        puts %Q(<caption>#{I18n.t('table')}#{I18n.t('format_number', [get_chap, @chapter.table(id).number])}#{I18n.t('caption_prefix_idgxml')}#{compile_inline(caption)}</caption>)
      else
        puts %Q(<caption>#{I18n.t('table')}#{I18n.t('format_number_without_chapter', [@chapter.table(id).number])}#{I18n.t('caption_prefix_idgxml')}#{compile_inline(caption)}</caption>)
      end
    end

    def table_begin(ncols)
    end

    def tr(rows)
      puts %Q(<tr>#{rows.join("\t")}</tr>)
    end

    def th(str)
      %Q(<?dtp tablerow header?>#{str})
    end

    def td(str)
      str
    end

    def table_end
    end

    def emtable(lines, caption = nil)
      table(lines, nil, caption)
    end

    def imgtable(lines, id, caption = nil, metric = nil)
      if @chapter.image_bound?(id)
        metrics = parse_metric('idgxml', metric)
        puts '<table>'
        if caption_top?('table') && caption.present?
          table_header(id, caption)
        end
        puts %Q(<imgtable><Image href="file://#{@chapter.image(id).path.sub(%r{\A./}, '')}"#{metrics} /></imgtable>)
        if !caption_top?('table') && caption.present?
          table_header(id, caption)
        end
        puts '</table>'
      else
        warn "image not bound: #{id}" if @strict
        image_dummy(id, caption, lines)
      end
    end

    def comment(lines, comment = nil)
      return unless @book.config['draft']
      lines ||= []
      lines.unshift(escape(comment)) unless comment.blank?
      str = lines.join("\n")
      print "<msg>#{str}</msg>"
    end

    def inline_comment(str)
      if @book.config['draft']
        %Q(<msg>#{escape(str)}</msg>)
      else
        ''
      end
    end

    def footnote(id, str)
      # see inline_fn
    end

    def inline_fn(id)
      %Q(<footnote>#{compile_inline(@chapter.footnote(id).content.strip)}</footnote>)
    rescue KeyError
      error "unknown footnote: #{id}"
    end

    def compile_ruby(base, ruby)
      %Q(<GroupRuby><aid:ruby xmlns:aid="http://ns.adobe.com/AdobeInDesign/3.0/"><aid:rb>#{escape(base.strip)}</aid:rb><aid:rt>#{escape(ruby.strip)}</aid:rt></aid:ruby></GroupRuby>)
    end

    def compile_kw(word, alt)
      '<keyword>' +
        if alt
        then escape("#{word}（#{alt.strip}）")
        else escape(word)
        end +
      '</keyword>' +
        %Q(<index value="#{escape(word)}" />) +
        if alt
          alt.split(/\s*,\s*/).collect! { |e| %Q(<index value="#{escape(e.strip)}" />) }.join
        else
          ''
        end
    end

    def compile_href(url, label)
      %Q(<a linkurl='#{escape(url)}'>#{label.nil? ? escape(url) : escape(label)}</a>)
    end

    def inline_sup(str)
      %Q(<sup>#{escape(str)}</sup>)
    end

    def inline_sub(str)
      %Q(<sub>#{escape(str)}</sub>)
    end

    def inline_raw(str)
      super(str).gsub('\\n', "\n")
    end

    def inline_hint(str)
      if @book.config['nolf']
        %Q(<hint>#{escape(str)}</hint>)
      else
        %Q(\n<hint>#{escape(str)}</hint>)
      end
    end

    def inline_maru(str)
      if str =~ /\A\d+\Z/
        sprintf('&#x%x;', 9311 + str.to_i)
      elsif str =~ /\A[A-Z]\Z/
        begin
          sprintf('&#x%x;', 9398 + str.codepoints.to_a[0] - 65)
        rescue NoMethodError
          sprintf('&#x%x;', 9398 + str[0] - 65)
        end
      elsif str =~ /\A[a-z]\Z/
        begin
          sprintf('&#x%x;', 9392 + str.codepoints.to_a[0] - 65)
        rescue NoMethodError
          sprintf('&#x%x;', 9392 + str[0] - 65)
        end
      else
        error "can't parse maru: #{str}"
      end
    end

    def inline_idx(str)
      %Q(#{escape(str)}<index value="#{escape(str)}" />)
    end

    def inline_hidx(str)
      %Q(<index value="#{escape(str)}" />)
    end

    def inline_ami(str)
      %Q(<ami>#{escape(str)}</ami>)
    end

    def inline_i(str)
      %Q(<i>#{escape(str)}</i>)
    end

    def inline_b(str)
      %Q(<b>#{escape(str)}</b>)
    end

    def inline_em(str)
      %Q(<em>#{escape(str)}</em>)
    end

    def inline_strong(str)
      %Q(<strong>#{escape(str)}</strong>)
    end

    def inline_tt(str)
      %Q(<tt>#{escape(str)}</tt>)
    end

    def inline_ttb(str)
      %Q(<tt style='bold'>#{escape(str)}</tt>)
    end

    alias_method :inline_ttbold, :inline_ttb

    def inline_tti(str)
      %Q(<tt style='italic'>#{escape(str)}</tt>)
    end

    def inline_u(str)
      %Q(<underline>#{escape(str)}</underline>)
    end

    def inline_icon(id)
      begin
        %Q(<Image href="file://#{@chapter.image(id).path.sub(%r{\A\./}, '')}" type="inline" />)
      rescue
        warn "image not bound: #{id}"
        ''
      end
    end

    def inline_bou(str)
      %Q(<bou>#{escape(str)}</bou>)
    end

    def inline_keytop(str)
      %Q(<keytop>#{escape(str)}</keytop>)
    end

    def inline_labelref(idref)
      %Q(<ref idref='#{escape(idref)}'>「#{I18n.t('label_marker')}#{escape(idref)}」</ref>) # FIXME: 節名とタイトルも込みで要出力
    end

    alias_method :inline_ref, :inline_labelref

    def inline_pageref(idref)
      %Q(<pageref idref='#{escape(idref)}'>●●</pageref>) # ページ番号を参照
    end

    def inline_balloon(str)
      %Q(<balloon>#{escape(str).gsub(/@maru\[(\d+)\]/) { inline_maru($1) }}</balloon>)
    end

    def inline_uchar(str)
      %Q(&#x#{str};)
    end

    def inline_m(str)
      @texinlineequation += 1
      %Q(<replace idref="texinline-#{@texinlineequation}"><pre>#{escape(str)}</pre></replace>)
    end

    def noindent
      @noindent = true
    end

    def blankline
      puts '<p/>'
    end

    def pagebreak
      puts '<pagebreak />'
    end

    def nonum_begin(level, _label, caption)
      puts %Q(<title aid:pstyle="h#{level}">#{compile_inline(caption)}</title><?dtp level="#{level}" section="#{escape(compile_inline(caption))}"?>)
    end

    def nonum_end(level)
    end

    def notoc_begin(level, _label, caption)
      puts %Q(<title aid:pstyle="h#{level}">#{compile_inline(caption)}</title>)
    end

    def notoc_end(level)
    end

    def nodisp_begin(level, label, caption)
    end

    def nodisp_end(level)
    end

    def circle_begin(_level, _label, caption)
      puts %Q(<title aid:pstyle="smallcircle">&#x2022;#{compile_inline(caption)}</title>)
    end

    def circle_end(level)
    end

    def common_column_begin(type, caption)
      @column += 1
      a_id = %Q(id="column-#{@column}")
      print "<#{type}column #{a_id}>"
      puts %Q(<title aid:pstyle="#{type}column-title">#{compile_inline(caption)}</title><?dtp level="9" section="#{escape(compile_inline(caption))}"?>)
    end

    def common_column_end(type)
      puts "</#{type}column>"
    end

    def column_begin(_level, _label, caption)
      common_column_begin('', caption)
    end

    def column_end(_level)
      common_column_end('')
    end

    def xcolumn_begin(_level, _label, caption)
      common_column_begin('x', caption)
    end

    def xcolumn_end(_level)
      common_column_end('x')
    end

    def world_begin(_level, _label, caption)
      common_column_begin('world', caption)
    end

    def world_end(_level)
      common_column_end('world')
    end

    def hood_begin(_level, _label, caption)
      common_column_begin('hood', caption)
    end

    def hood_end(_level)
      common_column_end('hood')
    end

    def edition_begin(_level, _label, caption)
      common_column_begin('edition', caption)
    end

    def edition_end(_level)
      common_column_end('edition')
    end

    def insideout_begin(_level, _label, caption)
      common_column_begin('insideout', caption)
    end

    def insideout_end(_level)
      common_column_end('insideout')
    end

    def ref_begin(_level, label, _caption)
      if label
        puts "<reference id='#{label}'>"
      else
        puts '<reference>'
      end
    end

    def ref_end(_level)
      puts '</reference>'
    end

    def sup_begin(_level, label, _caption)
      if label
        puts "<supplement id='#{label}'>"
      else
        puts '<supplement>'
      end
    end

    def sup_end(_level)
      puts '</supplement>'
    end

    def flushright(lines)
      puts split_paragraph(lines).join.gsub('<p>', %Q(<p align='right'>))
    end

    def centering(lines)
      puts split_paragraph(lines).join.gsub('<p>', %Q(<p align='center'>))
    end

    def captionblock(type, lines, caption, specialstyle = nil)
      print "<#{type}>"
      style = specialstyle.nil? ? "#{type}-title" : specialstyle
      puts "<title aid:pstyle='#{style}'>#{compile_inline(caption)}</title>" if caption.present?
      blocked_lines = split_paragraph(lines)
      puts "#{blocked_lines.join}</#{type}>"
    end

    def note(lines, caption = nil)
      check_nested_minicolumn
      captionblock('note', lines, caption)
    end

    def memo(lines, caption = nil)
      check_nested_minicolumn
      captionblock('memo', lines, caption)
    end

    def tip(lines, caption = nil)
      check_nested_minicolumn
      captionblock('tip', lines, caption)
    end

    def info(lines, caption = nil)
      check_nested_minicolumn
      captionblock('info', lines, caption)
    end

    def planning(lines, caption = nil)
      captionblock('planning', lines, caption)
    end

    def best(lines, caption = nil)
      captionblock('best', lines, caption)
    end

    def important(lines, caption = nil)
      check_nested_minicolumn
      captionblock('important', lines, caption)
    end

    def security(lines, caption = nil)
      captionblock('security', lines, caption)
    end

    def caution(lines, caption = nil)
      check_nested_minicolumn
      captionblock('caution', lines, caption)
    end

    def warning(lines, caption = nil)
      check_nested_minicolumn
      captionblock('warning', lines, caption)
    end

    def term(lines)
      captionblock('term', lines, nil)
    end

    def link(lines, caption = nil)
      captionblock('link', lines, caption)
    end

    def notice(lines, caption = nil)
      check_nested_minicolumn
      if caption
        captionblock('notice-t', lines, caption, 'notice-title')
      else
        captionblock('notice', lines, nil)
      end
    end

    def point(lines, caption = nil)
      if caption
        captionblock('point-t', lines, caption, 'point-title')
      else
        captionblock('point', lines, nil)
      end
    end

    def shoot(lines, caption = nil)
      if caption
        captionblock('shoot-t', lines, caption, 'shoot-title')
      else
        captionblock('shoot', lines, nil)
      end
    end

    def reference(lines)
      captionblock('reference', lines, nil)
    end

    def practice(lines)
      captionblock('practice', lines, nil)
    end

    def expert(lines)
      captionblock('expert', lines, nil)
    end

    %w[note memo tip info warning important caution notice].each do |name|
      class_eval %Q(
        def #{name}_begin(caption = nil)
          check_nested_minicolumn
          if '#{name}' == 'notice' && caption.present?
            @doc_status[:minicolumn] = '#{name}-t'
            print "<#{name}-t>"
          else
            @doc_status[:minicolumn] = '#{name}'
            print "<#{name}>"
          end
          if caption.present?
            puts %Q(<title aid:pstyle='#{name}-title'>\#{compile_inline(caption)}</title>)
          end
        end

        def #{name}_end
          if '#{name}' == 'notice' && @doc_status[:minicolumn] == 'notice-t'
            print "</#{name}-t>"
          else
            print "</#{name}>"
          end
          @doc_status[:minicolumn] = nil
        end
      )
    end

    def syntaxblock(type, lines, caption)
      captionstr = nil
      if caption.present?
        titleopentag = %Q(caption aid:pstyle="#{type}-title")
        titleclosetag = 'caption'
        if type == 'insn'
          titleopentag = %Q(floattitle type="insn")
          titleclosetag = 'floattitle'
        end
        captionstr = %Q(<#{titleopentag}>#{compile_inline(caption)}</#{titleclosetag}>)
      end
      print "<#{type}>"
      if caption_top?('list')
        puts captionstr
      else
        puts ''
      end

      no = 1
      lines.each do |line|
        if @book.config['listinfo']
          print %Q(<listinfo line="#{no}")
          print %Q( begin="1") if no == 1
          print %Q( end="#{no}") if no == lines.size
          print '>'
        end
        print detab(line)
        print "\n"
        print '</listinfo>' if @book.config['listinfo']
        no += 1
      end
      unless caption_top?('list')
        print captionstr
      end
      puts "</#{type}>"
    end

    def insn(lines, caption = nil)
      syntaxblock('insn', lines, caption)
    end

    def box(lines, caption = nil)
      syntaxblock('box', lines, caption)
    end

    def indepimage(_lines, id, caption = nil, metric = nil)
      metrics = parse_metric('idgxml', metric)
      puts '<img>'
      if caption_top?('image')
        puts %Q(<caption>#{compile_inline(caption)}</caption>) if caption.present?
      end
      begin
        puts %Q(<Image href="file://#{@chapter.image(id).path.sub(%r{\A\./}, '')}"#{metrics} />)
      rescue
        warn %Q(image not bound: #{id})
      end
      unless caption_top?('image')
        puts %Q(<caption>#{compile_inline(caption)}</caption>) if caption.present?
      end
      puts '</img>'
    end

    alias_method :numberlessimage, :indepimage

    def label(id)
      # FIXME
      print "<label id='#{id}' />"
    end

    def dtp(str)
      print %Q(<?dtp #{str} ?>)
    end

    def hr
      print '<hr />'
    end

    def bpo(lines)
      puts %Q(<bpo>#{lines.join("\n")}</bpo>)
    end

    def inline_dtp(str)
      "<?dtp #{str} ?>"
    end

    def inline_code(str)
      %Q(<tt type='inline-code'>#{escape(str)}</tt>)
    end

    def inline_br(_str)
      "\n"
    end

    def rawblock(lines)
      no = 1
      lines.each do |l|
        print l.gsub('&lt;', '<').gsub('&gt;', '>').gsub('&quot;', '"').gsub('&amp;', '&')
        print "\n" unless lines.length == no
        no += 1
      end
    end

    def text(str)
      str
    end

    def inline_chapref(id)
      if @book.config.check_version('2', exception: false)
        # backward compatibility
        chs = ['', '「', '」']
        if @book.config['chapref']
          chs2 = @book.config['chapref'].split(',')
          if chs2.size != 3
            error '--chapsplitter must have exactly 3 parameters with comma.'
          else
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
        title = super
        if @book.config['chapterlink']
          %Q(<link href="#{id}">#{title}</link>)
        else
          title
        end
      end
    rescue KeyError
      error "unknown chapter: #{id}"
    end

    def inline_chap(id)
      if @book.config['chapterlink']
        %Q(<link href="#{id}">#{@book.chapter_index.number(id)}</link>)
      else
        @book.chapter_index.number(id)
      end
    rescue KeyError
      error "unknown chapter: #{id}"
    end

    def inline_title(id)
      title = super
      if @book.config['chapterlink']
        %Q(<link href="#{id}">#{title}</link>)
      else
        title
      end
    rescue KeyError
      error "unknown chapter: #{id}"
    end

    def source(lines, caption = nil, lang = nil)
      puts '<source>'
      if caption_top?('list')
        source_header(caption)
      end
      source_body(lines, lang)
      unless caption_top?('list')
        source_header(caption)
      end
      puts '</source>'
    end

    def source_header(caption)
      puts %Q(<caption>#{compile_inline(caption)}</caption>) if caption.present?
    end

    def source_body(lines, _lang)
      puts '<pre>'
      codelines_body(lines)
      print '</pre>'
    end

    def bibpaper(lines, id, caption)
      puts %Q(<bibitem id="bib-#{id}">)
      bibpaper_header(id, caption)
      bibpaper_bibpaper(id, caption, lines) unless lines.empty?
      puts '</bibitem>'
    end

    def bibpaper_header(id, caption)
      puts "<caption><span type='bibno'>[#{@chapter.bibpaper(id).number}] </span>#{compile_inline(caption)}</caption>" if caption.present?
    end

    def bibpaper_bibpaper(_id, _caption, lines)
      print split_paragraph(lines).join
    end

    def inline_bib(id)
      %Q(<span type='bibref' idref='#{id}'>[#{@chapter.bibpaper(id).number}]</span>)
    rescue KeyError
      error "unknown bib: #{id}"
    end

    def inline_hd_chap(chap, id)
      n = chap.headline_index.number(id)
      if n.present? && chap.number && over_secnolevel?(n)
        I18n.t('hd_quote', [n, compile_inline(chap.headline(id).caption)])
      else
        I18n.t('hd_quote_without_number', compile_inline(chap.headline(id).caption))
      end
    rescue KeyError
      error "unknown headline: #{id}"
    end

    def inline_recipe(id)
      # FIXME
      %Q(<recipe idref="#{escape(id)}">[XXX]「#{escape(id)}」　p.XX</recipe>)
    end

    def nofunc_text(str)
      escape(str)
    end

    def image_ext
      'eps'
    end
  end
end # module ReVIEW
