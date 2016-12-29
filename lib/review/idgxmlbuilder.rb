# encoding: utf-8
#
# Copyright (c) 2002-2007 Minero Aoki
#               2008-2016 Minero Aoki, Kenshi Muto
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

    [:ttbold, :hint, :maru, :keytop, :labelref, :ref, :pageref, :balloon].each {|e| Compiler.definline(e) }
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

    def builder_init(no_error = false)
      @no_error = no_error
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
      @rootelement = "doc"
      @secttags = nil
      @tsize = nil
      @texblockequation = 0
      @texinlineequation = 0
      print %Q(<?xml version="1.0" encoding="UTF-8"?>\n)
      print %Q(<#{@rootelement} xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/">)
      @secttags = true unless @book.config["structuredxml"].nil?
    end
    private :builder_init_file

    def puts(arg)
      if @book.config["nolf"].present?
        print arg
      else
        super
      end
    end

    def result
      s = ""
      unless @secttags.nil?
        s += "</sect4>" if @subsubsubsection > 0
        s += "</sect3>" if @subsubsection > 0
        s += "</sect2>" if @subsection > 0
        s += "</sect>" if @section > 0
        s += "</chapter>" if @chapter.number > 0
      end
      messages() + @output.string + s + "</#{@rootelement}>\n"
    end

    def warn(msg)
      if @no_error
        @warns.push [@location.filename, @location.lineno, msg]
        puts "----WARNING: #{escape_html(msg)}----"
      else
        $stderr.puts "#{@location}: warning: #{msg}"
      end
    end

    def error(msg)
      if @no_error
        @errors.push [@location.filename, @location.lineno, msg]
        puts "----ERROR: #{escape_html(msg)}----"
      else
        $stderr.puts "#{@location}: error: #{msg}"
      end
    end

    def messages
      error_messages() + warning_messages()
    end

    def error_messages
      return '' if @errors.empty?
      "<h2>Syntax Errors</h2>\n" +
      "<ul>\n" +
      @errors.map {|file, line, msg|
        "<li>#{escape_html(file)}:#{line}: #{escape_html(msg.to_s)}</li>\n"
      }.join('') +
      "</ul>\n"
    end

    def warning_messages
      return '' if @warns.empty?
      "<h2>Warnings</h2>\n" +
      "<ul>\n" +
      @warns.map {|file, line, msg|
        "<li>#{escape_html(file)}:#{line}: #{escape_html(msg)}</li>\n"
      }.join('') +
      "</ul>\n"
    end

    def headline(level, label, caption)
      case level
      when 1
        unless @secttags.nil?
          print "</sect4>" if @subsubsubsection > 0
          print "</sect3>" if @subsubsection > 0
          print "</sect2>" if @subsection > 0
          print "</sect>" if @section > 0
        end

        print %Q(<chapter id="chap:#{@chapter.number}">) unless @secttags.nil?

        @section = 0
        @subsection = 0
        @subsubsection = 0
        @subsubsubsection = 0
      when 2
        unless @secttags.nil?
          print "</sect4>" if @subsubsubsection > 0
          print "</sect3>" if @subsubsection > 0
          print "</sect2>" if @subsection > 0
          print "</sect>" if @section > 0
        end
        @section += 1
        print %Q(<sect id="sect:#{@chapter.number}.#{@section}">) unless @secttags.nil?
      
        @subsection = 0
        @subsubsection = 0
        @subsubsubsection = 0
      when 3
        unless @secttags.nil?
          print "</sect4>" if @subsubsubsection > 0
          print "</sect3>" if @subsubsection > 0
          print "</sect2>" if @subsection > 0
        end

        @subsection += 1
        print %Q(<sect2 id="sect:#{@chapter.number}.#{@section}.#{@subsection}">) unless @secttags.nil?

        @subsubsection = 0
        @subsubsubsection = 0
      when 4
        unless @secttags.nil?
          print "</sect4>" if @subsubsubsection > 0
          print "</sect3>" if @subsubsection > 0
        end

        @subsubsection += 1
        print %Q(<sect3 id="sect:#{@chapter.number}.#{@section}.#{@subsection}.#{@subsubsection}">) unless @secttags.nil?

        @subsubsubsection = 0
      when 5
        unless @secttags.nil?
          print "</sect4>" if @subsubsubsection > 0
        end

        @subsubsubsection += 1
        print %Q(<sect4 id="sect:#{@chapter.number}.#{@section}.#{@subsection}.#{@subsubsection}.#{@subsubsubsection}">) unless @secttags.nil?
      else
        raise "caption level too deep or unsupported: #{level}"
      end

      prefix, anchor = headline_prefix(level)

      label = label.nil? ? "" : " id=\"#{label}\""
      toccaption = escape_html(compile_inline(caption.gsub(/@<fn>\{.+?\}/, '')).gsub(/<[^>]+>/, ''))
      puts %Q(<title#{label} aid:pstyle="h#{level}">#{prefix}#{compile_inline(caption)}</title><?dtp level="#{level}" section="#{prefix}#{toccaption}"?>)
    end

    def ul_begin
      level = block_given? ? yield : ""
      level = nil if level == 1
      puts "<ul#{level == 1 ? nil : level}>"
    end

    def ul_item(lines)
      puts %Q(<li aid:pstyle="ul-item">#{lines.join.chomp}</li>)
    end

    def ul_item_begin(lines)
      print %Q(<li aid:pstyle="ul-item">#{lines.join.chomp})
    end

    def ul_item_end
      puts "</li>"
    end

    def choice_single_begin
      puts "<choice type='single'>"
    end

    def choice_multi_begin
      puts "<choice type='multi'>"
    end

    def choice_single_end
      puts "</choice>"
    end

    def choice_multi_end
      puts "</choice>"
    end

    def ul_end
      level = block_given? ? yield : ""
      level = nil if level == 1
      puts "</ul#{level}>"
    end

    def ol_begin
      puts '<ol>'
      if !@ol_num
        @ol_num = 1
      end
    end

    def ol_item(lines, num)
      puts %Q(<li aid:pstyle="ol-item" olnum="#{@ol_num}" num="#{num}">#{lines.join.chomp}</li>)
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
      puts "<dd>#{lines.join.chomp}</dd>"
    end

    def dl_end
      puts '</dl>'
    end

    def paragraph(lines)
      if @noindent.nil?
        if lines[0] =~ /\A(\t+)/
          puts %Q(<p inlist="#{$1.size}">#{lines.join('').sub(/\A\t+/, "")}</p>)
        else
          puts "<p>#{lines.join}</p>"
        end
      else
        puts %Q(<p aid:pstyle="noindent" noindent='1'>#{lines.join}</p>)
        @noindent = nil
      end
    end

    def read(lines)
      puts %Q[<lead>#{split_paragraph(lines).join}</lead>]
    end

    alias_method :lead, :read

    def column_label(id)
      num = @chapter.column(id).number
      "column-#{num}"
    end
    private :column_label

    def inline_column_chap(chapter, id)
      if @book.config["chapterlink"]
        %Q(<link href="#{column_label(id)}">#{I18n.t("column", compile_inline(chapter.column(id).caption))}</link>)
      else
        I18n.t("column", compile_inline(chapter.column(id).caption))
      end
    end

    def inline_list(id)
      chapter, id = extract_chapter_id(id)
      if get_chap(chapter).nil?
        "<span type='list'>#{I18n.t("list")}#{I18n.t("format_number_without_chapter", [chapter.list(id).number])}</span>"
      else
        "<span type='list'>#{I18n.t("list")}#{I18n.t("format_number", [get_chap(chapter), chapter.list(id).number])}</span>"
      end
    end

    def list_header(id, caption, lang)
      puts %Q[<codelist>]
      if get_chap.nil?
        puts %Q[<caption>#{I18n.t("list")}#{I18n.t("format_number_without_chapter", [@chapter.list(id).number])}#{I18n.t("caption_prefix_idgxml")}#{compile_inline(caption)}</caption>]
      else
        puts %Q[<caption>#{I18n.t("list")}#{I18n.t("format_number", [get_chap, @chapter.list(id).number])}#{I18n.t("caption_prefix_idgxml")}#{compile_inline(caption)}</caption>]
      end
    end

    def codelines_body(lines)
      no = 1
      lines.each do |line|
        unless @book.config["listinfo"].nil?
          print "<listinfo line=\"#{no}\""
          print " begin=\"1\"" if no == 1
          print " end=\"#{no}\"" if no == lines.size
          print ">"
        end
        print detab(line)
        print "\n"
        print "</listinfo>" unless @book.config["listinfo"].nil?
        no += 1
      end
    end

    def list_body(id, lines, lang)
      print %Q(<pre>)
      codelines_body(lines)
      puts "</pre></codelist>"
    end

    def emlist(lines, caption = nil, lang = nil)
      quotedlist lines, 'emlist', caption
    end

    def emlistnum(lines, caption = nil, lang = nil)
      _lines = []
      first_line_num = get_line_num
      lines.each_with_index do |line, i|
        _lines << detab("<span type='lineno'>" + (i + first_line_num).to_s.rjust(2) + ": </span>" + line)
      end
      quotedlist _lines, 'emlistnum', caption
    end

    def listnum_body(lines, lang)
      print %Q(<pre>)
      no = 1
      first_line_num = get_line_num
      lines.each_with_index do |line, i|
        unless @book.config["listinfo"].nil?
          print "<listinfo line=\"#{no}\""
          print " begin=\"1\"" if no == 1
          print " end=\"#{no}\"" if no == lines.size
          print ">"
        end
        print detab("<span type='lineno'>" + (i + first_line_num).to_s.rjust(2) + ": </span>" + line)
        print "\n"
        print "</listinfo>" unless @book.config["listinfo"].nil?
        no += 1
      end
      puts "</pre></codelist>"
    end

    def cmd(lines, caption = nil)
      quotedlist lines, 'cmd', caption
    end

    def quotedlist(lines, css_class, caption)
      print %Q[<list type='#{css_class}'>]
      puts "<caption aid:pstyle='#{css_class}-title'>#{compile_inline(caption)}</caption>" if caption.present?
      print %Q[<pre>]
      no = 1
      lines.each do |line|
        unless @book.config["listinfo"].nil?
          print "<listinfo line=\"#{no}\""
          print " begin=\"1\"" if no == 1
          print " end=\"#{no}\"" if no == lines.size
          print ">"
        end
        print detab(line)
        print "\n"
        print "</listinfo>" unless @book.config["listinfo"].nil?
        no += 1
      end
      puts '</pre></list>'
    end
    private :quotedlist

    def quote(lines)
      blocked_lines = split_paragraph(lines)
      puts "<quote>#{blocked_lines.join("")}</quote>"
    end

    def inline_table(id)
      chapter, id = extract_chapter_id(id)
      if get_chap(chapter).nil?
        "<span type='table'>#{I18n.t("table")}#{I18n.t("format_number_without_chapter", [chapter.table(id).number])}</span>"
      else
        "<span type='table'>#{I18n.t("table")}#{I18n.t("format_number", [get_chap(chapter), chapter.table(id).number])}</span>"
      end
    end

    def inline_img(id)
      chapter, id = extract_chapter_id(id)
      if get_chap(chapter).nil?
        "<span type='image'>#{I18n.t("image")}#{I18n.t("format_number_without_chapter", [chapter.image(id).number])}</span>"
      else
        "<span type='image'>#{I18n.t("image")}#{I18n.t("format_number", [get_chap(chapter), chapter.image(id).number])}</span>"
      end
    end

    def inline_imgref(id)
      chapter, id = extract_chapter_id(id)
      if chapter.image(id).caption.blank?
        inline_img(id)
      else
        if get_chap(chapter).nil?
          "<span type='image'>#{I18n.t("image")}#{I18n.t("format_number_without_chapter", [chapter.image(id).number])}#{I18n.t('image_quote', chapter.image(id).caption)}</span>"
        else
          "<span type='image'>#{I18n.t("image")}#{I18n.t("format_number", [get_chap(chapter), chapter.image(id).number])}#{I18n.t('image_quote', chapter.image(id).caption)}</span>"
        end
      end
    end

    def handle_metric(str)
      k, v = str.split('=', 2)
      return %Q|#{k}=\"#{v.sub(/\A["']/, '').sub(/["']\Z/, '')}\"|
    end

    def result_metric(array)
      " #{array.join(' ')}"
    end

    def image_image(id, caption, metric=nil)
      metrics = parse_metric("idgxml", metric)
      puts "<img>"
      puts %Q[<Image href="file://#{@chapter.image(id).path.sub(/\A.\//, "")}"#{metrics} />]
      image_header id, caption
      puts "</img>"
    end

    def image_dummy(id, caption, lines)
      puts "<img>"
      print %Q[<pre aid:pstyle="dummyimage">]
      lines.each do |line|
        print detab(line)
        print "\n"
      end
      print %Q[</pre>]
      image_header id, caption
      puts "</img>"
      warn "no such image: #{id}"
    end

    def image_header(id, caption)
      if get_chap.nil?
        puts %Q[<caption>#{I18n.t("image")}#{I18n.t("format_number_without_chapter", [@chapter.image(id).number])}#{I18n.t("caption_prefix_idgxml")}#{compile_inline(caption)}</caption>]
      else
        puts %Q[<caption>#{I18n.t("image")}#{I18n.t("format_number", [get_chap, @chapter.image(id).number])}#{I18n.t("caption_prefix_idgxml")}#{compile_inline(caption)}</caption>]
      end
    end

    def texequation(lines)
      @texblockequation += 1
      puts %Q[<replace idref="texblock-#{@texblockequation}">]
      puts '<pre>'
      puts "#{lines.join("\n")}"
      puts '</pre>'
      puts '</replace>'
    end

    def table(lines, id = nil, caption = nil)
      tablewidth = nil
      col = 0
      if @book.config["tableopt"]
        tablewidth = @book.config["tableopt"].split(",")[0].to_f / @book.config["pt_to_mm_unit"].to_f
      end
      puts "<table>"
      rows = []
      sepidx = nil
      lines.each_with_index do |line, idx|
        if /\A[\=\-]{12}/ =~ line
          sepidx ||= idx
          next
        end
        if tablewidth.nil?
          rows.push(line.gsub(/\t\.\t/, "\t\t").gsub(/\t\.\.\t/, "\t.\t").gsub(/\t\.\Z/, "\t").gsub(/\t\.\.\Z/, "\t.").gsub(/\A\./, ""))
        else
          rows.push(line.gsub(/\t\.\t/, "\tDUMMYCELLSPLITTER\t").gsub(/\t\.\.\t/, "\t.\t").gsub(/\t\.\Z/, "\tDUMMYCELLSPLITTER").gsub(/\t\.\.\Z/, "\t.").gsub(/\A\./, ""))
        end
        _col = rows[rows.length - 1].split(/\t/).length
        col = _col if _col > col
      end

      cellwidth = []
      unless tablewidth.nil?
        if @tsize.nil?
          col.times {|n| cellwidth[n] = tablewidth / col }
        else
          cellwidth = @tsize.split(/\s*,\s*/)
          totallength = 0
          cellwidth.size.times do |n|
            cellwidth[n] = cellwidth[n].to_f / @book.config["pt_to_mm_unit"].to_f
            totallength += cellwidth[n]
            warn "total length exceeds limit for table: #{id}" if totallength > tablewidth
          end
          if cellwidth.size < col
            cw = (tablewidth - totallength) / (col - cellwidth.size)
            warn "auto cell sizing exceeds limit for table: #{id}" if cw <= 0
            for i in cellwidth.size..(col - 1)
              cellwidth[i] = cw
            end
          end
        end
      end

      begin
        table_header id, caption unless caption.nil?
      rescue KeyError
        error "no such table: #{id}"
      end
      return if rows.empty?

      if tablewidth.nil?
        print "<tbody>"
      else
        print %Q[<tbody xmlns:aid5="http://ns.adobe.com/AdobeInDesign/5.0/" aid:table="table" aid:trows="#{rows.length}" aid:tcols="#{col}">]
      end

      if sepidx
        sepidx.times do |y|
          if tablewidth.nil?
            puts %Q[<tr type="header">#{rows.shift}</tr>]
          else
            i = 0
            rows.shift.split(/\t/).each_with_index do |cell, x|
              print %Q[<td xyh="#{x + 1},#{y + 1},#{sepidx}" aid:table="cell" aid:theader="1" aid:crows="1" aid:ccols="1" aid:ccolwidth="#{sprintf("%.3f", cellwidth[i])}">#{cell.sub("DUMMYCELLSPLITTER", "")}</td>]
              i += 1
            end
          end
        end
      end
      trputs(tablewidth, rows, cellwidth, sepidx)
      puts "</tbody></table>"
      @tsize = nil
    end

    def trputs(tablewidth, rows, cellwidth, sepidx)
      sepidx = 0 if sepidx.nil?
      if tablewidth.nil?
        lastline = rows.pop
        rows.each {|row| puts %Q[<tr>#{row}</tr>] }
        puts %Q[<tr type="lastline">#{lastline}</tr>] unless lastline.nil?
      else
        rows.each_with_index do |row, y|
          i = 0
          row.split(/\t/).each_with_index do |cell, x|
            print %Q[<td xyh="#{x + 1},#{y + 1 + sepidx},#{sepidx}" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="#{sprintf("%.3f", cellwidth[i])}">#{cell.sub("DUMMYCELLSPLITTER", "")}</td>]
            i += 1
          end
        end
      end
    end

    def table_header(id, caption)
      if get_chap.nil?
      puts %Q[<caption>#{I18n.t("table")}#{I18n.t("format_number_without_chapter", [@chapter.table(id).number])}#{I18n.t("caption_prefix_idgxml")}#{compile_inline(caption)}</caption>]
      else
        puts %Q[<caption>#{I18n.t("table")}#{I18n.t("format_number", [get_chap, @chapter.table(id).number])}#{I18n.t("caption_prefix_idgxml")}#{compile_inline(caption)}</caption>]
      end
    end

    def table_begin(ncols)
    end

    def tr(rows)
      puts %Q[<tr>#{rows.join("\t")}</tr>]
    end

    def th(str)
      %Q[<?dtp tablerow header?>#{str}]
    end

    def td(str)
      str
    end

    def table_end
      print "<?dtp tablerow last?>"
    end

    def imgtable(lines, id, caption = nil, metric = nil)
      if @chapter.image(id).bound?
        metrics = parse_metric("idgxml", metric)
        puts "<table>"
        table_header id, caption
        puts %Q[<imgtable><Image href="file://#{@chapter.image(id).path.sub(/\A.\//, "")}"#{metrics} /></imgtable>]
        puts "</table>"
      else
        warn "image not bound: #{id}" if @strict
        image_dummy id, caption, lines
      end
    end

    def comment(str)
      print %Q(<!-- [Comment] #{escape_html(str)} -->)
    end

    def footnote(id, str)
      # see inline_fn
    end

    def inline_fn(id)
      %Q[<footnote>#{compile_inline(@chapter.footnote(id).content.strip)}</footnote>]
    end

    def compile_ruby(base, ruby)
      %Q[<GroupRuby><aid:ruby xmlns:aid="http://ns.adobe.com/AdobeInDesign/3.0/"><aid:rb>#{escape_html(base.sub(/\A\s+/, "").sub(/\s+$/, ""))}</aid:rb><aid:rt>#{escape_html(ruby.sub(/\A\s+/, "").sub(/\s+$/, ""))}</aid:rt></aid:ruby></GroupRuby>]
    end

    def compile_kw(word, alt)
      '<keyword>' +
        if alt
        then escape_html("#{word}（#{alt.strip}）")
        else escape_html(word)
        end +
      '</keyword>' +
        %Q[<index value="#{escape_html(word)}" />] +
        if alt
          alt.split(/\s*,\s*/).collect! {|e| %Q[<index value="#{escape_html(e.strip)}" />] }.join
        else
          ""
        end
    end

    def compile_href(url, label)
      %Q[<a linkurl='#{escape_html(url)}'>#{label.nil? ? escape_html(url) : escape_html(label)}</a>]
    end

    def inline_sup(str)
      %Q[<sup>#{escape_html(str)}</sup>]
    end

    def inline_sub(str)
      %Q[<sub>#{escape_html(str)}</sub>]
    end

    def inline_raw(str)
      %Q[#{super(str).gsub("\\n", "\n")}]
    end

    def inline_hint(str)
      if @book.config["nolf"].nil?
        %Q[\n<hint>#{escape_html(str)}</hint>]
      else
        %Q[<hint>#{escape_html(str)}</hint>]
      end
    end

    def inline_maru(str)
      if str =~ /\A\d+\Z/
        sprintf("&#x%x;", 9311 + str.to_i)
      elsif str =~ /\A[A-Z]\Z/
        begin
          sprintf("&#x%x;", 9398 + str.codepoints.to_a[0] - 65)
        rescue NoMethodError
          sprintf("&#x%x;", 9398 + str[0] - 65)
        end
      elsif str =~ /\A[a-z]\Z/
        begin
          sprintf("&#x%x;", 9392 + str.codepoints.to_a[0] - 65)
        rescue NoMethodError
          sprintf("&#x%x;", 9392 + str[0] - 65)
        end
      else
        raise "can't parse maru: #{str}"
      end
    end

    def inline_idx(str)
      %Q(#{escape_html(str)}<index value="#{escape_html(str)}" />)
    end

    def inline_hidx(str)
      %Q(<index value="#{escape_html(str)}" />)
    end

    def inline_ami(str)
      %Q(<ami>#{escape_html(str)}</ami>)
    end

    def inline_i(str)
      %Q(<i>#{escape_html(str)}</i>)
    end

    def inline_b(str)
      %Q(<b>#{escape_html(str)}</b>)
    end

    def inline_tt(str)
      %Q(<tt>#{escape_html(str)}</tt>)
    end

    def inline_ttb(str)
      %Q(<tt style='bold'>#{escape_html(str)}</tt>)
    end

    alias_method :inline_ttbold, :inline_ttb

    def inline_tti(str)
      %Q(<tt style='italic'>#{escape_html(str)}</tt>)
    end

    def inline_u(str)
      %Q(<underline>#{escape_html(str)}</underline>)
    end

    def inline_icon(id)
      begin
        %Q[<Image href="file://#{@chapter.image(id).path.sub(/\A\.\//, "")}" type="inline" />]
      rescue
        warn "no such icon image: #{id}"
        ""
      end
    end

    def inline_bou(str)
      %Q[<bou>#{escape_html(str)}</bou>]
    end

    def inline_keytop(str)
      %Q[<keytop>#{escape_html(str)}</keytop>]
    end

    def inline_labelref(idref)
      %Q[<ref idref='#{escape_html(idref)}'>「#{I18n.t("label_marker")}#{escape_html(idref)}」</ref>] # FIXME:節名とタイトルも込みで要出力
    end

    alias_method :inline_ref, :inline_labelref

    def inline_pageref(idref)
      %Q[<pageref idref='#{escape_html(idref)}'>●●</pageref>] # ページ番号を参照
    end

    def inline_balloon(str)
      %Q[<balloon>#{escape_html(str).gsub(/@maru\[(\d+)\]/) {|m| inline_maru($1)}}</balloon>]
    end

    def inline_uchar(str)
      %Q[&#x#{str};]
    end

    def inline_m(str)
      @texinlineequation += 1
      %Q[<replace idref="texinline-#{@texinlineequation}"><pre>#{escape_html(str)}</pre></replace>]
    end

    def noindent
      @noindent = true
    end

    def linebreak
      # FIXME:pが閉じちゃってるので一度戻らないといけないが、難しい…。
      puts "<br />"
    end

    def pagebreak
      puts "<pagebreak />"
    end

    def nonum_begin(level, label, caption)
      puts %Q[<title aid:pstyle="h#{level}">#{compile_inline(caption)}</title><?dtp level="#{level}" section="#{escape_html(compile_inline(caption))}"?>]
    end

    def nonum_end(level)
    end

    def circle_begin(level, label, caption)
      puts %Q[<title aid:pstyle="smallcircle">&#x2022;#{compile_inline(caption)}</title>]
    end

    def circle_end(level)
    end

    def common_column_begin(type, caption)
      @column += 1
      a_id = %Q[id="column-#{@column}"]
      print "<#{type}column #{a_id}>"
      puts %Q[<title aid:pstyle="#{type}column-title">#{compile_inline(caption)}</title><?dtp level="9" section="#{escape_html(compile_inline(caption))}"?>]
    end

    def common_column_end(type)
      puts "</#{type}column>"
    end

    def column_begin(level, label, caption)
      common_column_begin("", caption)
    end

    def column_end(level)
      common_column_end("")
    end

    def xcolumn_begin(level, label, caption)
      common_column_begin("x", caption)
    end

    def xcolumn_end(level)
      common_column_end("x")
    end

    def world_begin(level, label, caption)
      common_column_begin("world", caption)
    end

    def world_end(level)
      common_column_end("world")
    end

    def hood_begin(level, label, caption)
      common_column_begin("hood", caption)
    end

    def hood_end(level)
      common_column_end("hood")
    end

    def edition_begin(level, label, caption)
      common_column_begin("edition", caption)
    end

    def edition_end(level)
      common_column_end("edition")
    end

    def insideout_begin(level, label, caption)
      common_column_begin("insideout", caption)
    end

    def insideout_end(level)
      common_column_end("insideout")
    end

    def ref_begin(level, label, caption)
      if !label.nil?
        puts "<reference id='#{label}'>"
      else
        puts "<reference>"
      end
    end

    def ref_end(level)
      puts "</reference>"
    end

    def sup_begin(level, label, caption)
      if !label.nil?
        puts "<supplement id='#{label}'>"
      else
        puts "<supplement>"
      end
    end

    def sup_end(level)
      puts "</supplement>"
    end

    def flushright(lines)
      puts split_paragraph(lines).join.gsub("<p>", "<p align='right'>")
    end

    def centering(lines)
      puts split_paragraph(lines).join.gsub("<p>", "<p align='center'>")
    end

    def captionblock(type, lines, caption, specialstyle = nil)
      print "<#{type}>"
      style = specialstyle.nil? ? "#{type}-title" : specialstyle
      puts "<title aid:pstyle='#{style}'>#{compile_inline(caption)}</title>" unless caption.nil?
      blocked_lines = split_paragraph(lines)
      puts "#{blocked_lines.join}</#{type}>"
    end

    def note(lines, caption = nil)
      captionblock("note", lines, caption)
    end

    def memo(lines, caption = nil)
      captionblock("memo", lines, caption)
    end

    def tip(lines, caption = nil)
      captionblock("tip", lines, caption)
    end

    def info(lines, caption = nil)
      captionblock("info", lines, caption)
    end

    def planning(lines, caption = nil)
      captionblock("planning", lines, caption)
    end

    def best(lines, caption = nil)
      captionblock("best", lines, caption)
    end

    def important(lines, caption = nil)
      captionblock("important", lines, caption)
    end

    def security(lines, caption = nil)
      captionblock("security", lines, caption)
    end

    def caution(lines, caption = nil)
      captionblock("caution", lines, caption)
    end

    def warning(lines, caption = nil)
      captionblock("warning", lines, caption)
    end

    def term(lines)
      captionblock("term", lines, nil)
    end

    def link(lines, caption = nil)
      captionblock("link", lines, caption)
    end

    def notice(lines, caption = nil)
      if caption.nil?
        captionblock("notice", lines, nil)
      else
        captionblock("notice-t", lines, caption, "notice-title")
      end
    end

    def point(lines, caption = nil)
      if caption.nil?
        captionblock("point", lines, nil)
      else
        captionblock("point-t", lines, caption, "point-title")
      end
    end

    def shoot(lines, caption = nil)
      if caption.nil?
        captionblock("shoot", lines, nil)
      else
        captionblock("shoot-t", lines, caption, "shoot-title")
      end
    end

    def reference(lines)
      captionblock("reference", lines, nil)
    end

    def practice(lines)
      captionblock("practice", lines, nil)
    end

    def expert(lines)
      captionblock("expert", lines, nil)
    end

    def syntaxblock(type, lines, caption)
      if caption.nil?
        puts %Q[<#{type}>]
      else
        titleopentag = %Q[caption aid:pstyle="#{type}-title"]
        titleclosetag = "caption"
        if type == "insn"
          titleopentag = %Q[floattitle type="insn"]
          titleclosetag = "floattitle"
        end
        puts %Q[<#{type}><#{titleopentag}>#{compile_inline(caption)}</#{titleclosetag}>]
      end
      no = 1
      lines.each do |line|
        unless @book.config["listinfo"].nil?
          print %Q[<listinfo line="#{no}"]
          print %Q[ begin="1"] if no == 1
          print %Q[ end="#{no}"] if no == lines.size
          print %Q[>]
        end
        print detab(line)
        print "\n"
        print "</listinfo>" unless @book.config["listinfo"].nil?
        no += 1
      end
      puts "</#{type}>"
    end

    def insn(lines, caption = nil)
      syntaxblock("insn", lines, caption)
    end

    def box(lines, caption = nil)
      syntaxblock("box", lines, caption)
    end

    def indepimage(id, caption=nil, metric=nil)
      metrics = parse_metric("idgxml", metric)
      puts "<img>"
      begin
        puts %Q[<Image href="file://#{@chapter.image(id).path.sub(/\A\.\//, "")}"#{metrics} />]
      rescue
        warn %Q[no such image: #{id}]
      end
      puts %Q[<caption>#{compile_inline(caption)}</caption>] if caption.present?
      puts "</img>"
    end

    alias_method :numberlessimage, :indepimage

    def label(id)
      # FIXME
      print "<label id='#{id}' />"
    end

    def tsize(str)
      @tsize = str
    end

    def dtp(str)
      print %Q(<?dtp #{str} ?>)
    end

    def hr
      print "<hr />"
    end

    def bpo(lines)
      puts %Q[<bpo>#{lines.join("\n")}</bpo>]
    end

    def inline_dtp(str)
      "<?dtp #{str} ?>"
    end

    def inline_code(str)
      %Q[<tt type='inline-code'>#{escape_html(str)}</tt>]
    end

    def inline_br(str)
      "\n"
    end

    def rawblock(lines)
      no = 1
      lines.each do |l|
        print l.gsub("&lt;", "<").gsub("&gt;", ">").gsub("&quot;", "\"").gsub("&amp;", "&")
        print "\n" unless lines.length == no
        no += 1
      end
    end

    def text(str)
      str
    end

    def inline_chapref(id)
      chs = ["", "「", "」"]
      unless @book.config["chapref"].nil?
        _chs = @book.config["chapref"].split(",")
        if _chs.size != 3
          error "--chapsplitter must have exactly 3 parameters with comma."
        else
          chs = _chs
        end
      else
      end
      s = "#{chs[0]}#{@book.chapter_index.number(id)}#{chs[1]}#{@book.chapter_index.title(id)}#{chs[2]}"
      if @book.config["chapterlink"]
        %Q(<link href="#{id}">#{s}</link>)
      else
        s
      end
    rescue KeyError
      error "unknown chapter: #{id}"
      nofunc_text("[UnknownChapter:#{id}]")
    end

    def inline_chap(id)
      if @book.config["chapterlink"]
        %Q(<link href="#{id}">#{@book.chapter_index.number(id)}</link>)
      else
        @book.chapter_index.number(id)
      end
    rescue KeyError
      error "unknown chapter: #{id}"
      nofunc_text("[UnknownChapter:#{id}]")
    end

    def inline_title(id)
      title = super
      if @book.config["chapterlink"]
        %Q(<link href="#{id}">#{title}</link>)
      else
        title
      end
    rescue KeyError
      error "unknown chapter: #{id}"
      nofunc_text("[UnknownChapter:#{id}]")
    end

    def source_header(caption)
      puts %Q[<source>]
      puts %Q[<caption>#{compile_inline(caption)}</caption>]
    end

    def source_body(lines, lang)
      puts %Q[<pre>]
      codelines_body(lines)
      puts %Q[</pre></source>]
    end

    def bibpaper(lines, id, caption)
      bibpaper_header id, caption
      unless lines.empty?
        bibpaper_bibpaper id, caption, lines
      end
      puts %Q(</bibitem>)
    end

    def bibpaper_header(id, caption)
      puts %Q(<bibitem id="bib-#{id}">)
      puts "<caption><span type='bibno'>[#{@chapter.bibpaper(id).number}] </span>#{compile_inline(caption)}</caption>"
    end

    def bibpaper_bibpaper(id, caption, lines)
        print split_paragraph(lines).join("")
    end

    def inline_bib(id)
      %Q(<span type='bibref' idref='#{id}'>[#{@chapter.bibpaper(id).number}]</span>)
    end

    def inline_hd_chap(chap, id)
      if chap.number
        n = chap.headline_index.number(id)
        if @book.config["secnolevel"] >= n.split('.').size
          return I18n.t("chapter_quote", "#{n}　#{compile_inline(chap.headline(id).caption)}")
        end
      end
      I18n.t("chapter_quote", compile_inline(chap.headline(id).caption))
    end

    def inline_recipe(id)
      # FIXME
      %Q(<recipe idref="#{escape_html(id)}">[XXX]「#{escape_html(id)}」　p.XX</recipe>)
    end

    def nofunc_text(str)
      escape_html(str)
    end

    def image_ext
      "eps"
    end

  end

end # module ReVIEW
