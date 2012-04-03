# encoding: utf-8
#
# Copyright (c) 2002-2007 Minero Aoki
#               2008-2009 Minero Aoki, Kenshi Muto
#               2010  Minero Aoki, Kenshi Muto, TAKAHASHI Masayoshi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
#

require 'review/builder'
require 'review/latexutils'
require 'review/textutils'

module ReVIEW

  class LATEXBuilder < Builder

    include LaTeXUtils
    include TextUtils

    [:dtp, :hd_chap].each {|e|
      Compiler.definline(e)
    }

    Compiler.defblock(:memo, 0..1)
    Compiler.defsingle(:latextsize, 1)

    def extname
      '.tex'
    end

    def builder_init_file
      #@index = indexes[:latex_index]
      @blank_needed = false
      @latex_tsize = nil
      @tsize = nil
      @table_caption = nil
    end
    private :builder_init_file

    def blank
      @blank_needed = true
    end
    private :blank

    def print(*s)
      if @blank_needed
        @output.puts
        @blank_needed = false
      end
      super
    end
    private :print

    def puts(*s)
      if @blank_needed
        @output.puts
        @blank_needed = false
      end
      super
    end
    private :puts

    HEADLINE = {
      1 => 'chapter',
      2 => 'section',
      3 => 'subsection',
      4 => 'subsubsection',
      5 => 'paragraph',
      6 => 'subparagraph'
    }

    def headline(level, label, caption)
      prefix = ""
      if level > ReVIEW.book.param["secnolevel"] || (@chapter.number.to_s.empty? && level > 1)
        prefix = "*"
      end
      blank unless @output.pos == 0
      puts macro(HEADLINE[level]+prefix, compile_inline(caption))
      if prefix == "*" && level <= ReVIEW.book.param["toclevel"].to_i
        puts "\\addcontentsline{toc}{#{HEADLINE[level]}}{#{compile_inline(caption)}}"
      end
      if level == 1
        puts macro('label', chapter_label)
      end
    rescue
      error "unknown level: #{level}"
    end

    def nonum_begin(level, label, caption)
      blank unless @output.pos == 0
      puts macro(HEADLINE[level]+"*", compile_inline(caption))
    end

    def nonum_end(level)
    end

    def column_begin(level, label, caption)
      blank
      ## puts '\vspace{2zw}'
##      puts '\begin{center}'
##      puts '\begin{minipage}{1.0\linewidth}'
##      puts '\begin{framed}'
##      puts '\setlength{\FrameSep}{1zw}'

##      nonum_begin(3, label, caption)   # FIXME

      puts "\\begin{reviewcolumn}\n"
      puts macro('reviewcolumnhead', nil, compile_inline(caption))

    end

    def column_end(level)
##      puts '\end{framed}'
##      puts '\end{minipage}'
##      puts '\end{center}'
##      ## puts '\vspace{2zw}'
      puts "\\end{reviewcolumn}\n"
      blank
    end

    def captionblock(type, lines, caption)
      puts "\\begin{reviewminicolumn}\n"
      unless caption.nil?
        puts "\\reviewminicolumntitle{#{compile_inline(caption)}}\n"
      end

      if ReVIEW.book.param["deprecated-blocklines"].nil?
        blocked_lines = split_paragraph(lines)
        puts blocked_lines.join("\n\n")
      else
        lines.each do |line|
          puts line
        end
      end

      puts "\\end{reviewminicolumn}\n"
    end

    def ul_begin
      blank
      puts '\begin{itemize}'
    end

    def ul_item(lines)
      str = lines.join
      str.sub!(/\A(\[)/){'\lbrack{}'}
      puts '\item ' + str
    end

    def ul_end
      puts '\end{itemize}'
      blank
    end

    def ol_begin
      blank
      puts '\begin{enumerate}'
    end

    def ol_item(lines, num)
      str = lines.join
      str.sub!(/\A(\[)/){'\lbrack{}'}
      puts '\item ' + str
    end

    def ol_end
      puts '\end{enumerate}'
      blank
    end

    def dl_begin
      blank
      puts '\begin{description}'
    end

    def dt(str)
      str.sub!(/\[/){'\lbrack{}'}
      str.sub!(/\]/){'\rbrack{}'}
      puts '\item[' + str + '] \mbox{} \\\\'
    end

    def dd(lines)
      puts lines.join
    end

    def dl_end
      puts '\end{description}'
      blank
    end

    def paragraph(lines)
      blank
      lines.each do |line|
        puts line
      end
      blank
    end

    def parasep()
      puts '\\parasep'
    end

    def read(lines)
      latex_block 'quotation', lines
    end

    alias lead read

    def emlist(lines, caption = nil)
      blank
      if caption
        puts macro('reviewemlistcaption', "#{compile_inline(caption)}")
      end
      puts '\begin{reviewemlist}'
      puts '\begin{alltt}'
      lines.each do |line|
        puts detab(line)
      end
      puts '\end{alltt}'
      puts '\end{reviewemlist}'
      blank
    end

    def emlistnum(lines, caption = nil)
      blank
      if caption
        puts macro('reviewemlistcaption', "#{compile_inline(caption)}")
      end
      puts '\begin{reviewemlist}'
      puts '\begin{alltt}'
      lines.each_with_index do |line, i|
        puts detab((i+1).to_s.rjust(2) + ": " + line)
      end
      puts '\end{alltt}'
      puts '\end{reviewemlist}'
      blank
    end

    def listnum_body(lines)
      puts '\begin{reviewlist}'
      puts '\begin{alltt}'
      lines.each_with_index do |line, i|
        puts detab((i+1).to_s.rjust(2) + ": " + line)
      end
      puts '\end{alltt}'
      puts '\end{reviewlist}'
      blank

     end

    def cmd(lines, caption = nil)
      blank
      if caption
        puts macro('reviewcmdcaption', "#{compile_inline(caption)}")
      end
      puts '\begin{reviewcmd}'
      puts '\begin{alltt}'
      lines.each do |line|
        puts detab(line)
      end
      puts '\end{alltt}'
      puts '\end{reviewcmd}'
      blank
    end

    def list_header(id, caption)
      puts macro('reviewlistcaption', "#{I18n.t("list")}#{I18n.t("format_number_header", [@chapter.number, @chapter.list(id).number])}#{I18n.t("caption_prefix")}#{compile_inline(caption)}")
    end

    def list_body(lines)
      puts '\begin{reviewlist}'
      puts '\begin{alltt}'
      lines.each do |line|
        puts detab(line)
      end
      puts '\end{alltt}'
      puts '\end{reviewlist}'
      puts ""
    end

    def source(lines, caption)
      puts '\begin{reviewlist}'
      source_header caption
      source_body lines
      puts '\end{reviewlist}'
      puts ""
    end

    def source_header(caption)
      puts macro('reviewlistcaption', compile_inline(caption))
    end

    def source_body(lines)
      puts '\begin{alltt}'
      lines.each do |line|
        puts detab(line)
      end
      puts '\end{alltt}'
    end


    def image_header(id, caption)
    end

    def result_metric(array)
      "#{array.join(',')}"
    end

    def image_image(id, caption, metric)
      metrics = parse_metric("latex", metric)
      # image is always bound here
      puts '\begin{reviewimage}'
      if !metrics.empty?
        puts "\\includegraphics[#{metrics}]{#{@chapter.image(id).path}}"
      else
        puts "\\includegraphics[width=\\maxwidth]{#{@chapter.image(id).path}}"
      end
      puts macro('label', image_label(id))
      if !caption.empty?
        puts macro('caption', compile_inline(caption))
      end
      puts '\end{reviewimage}'
    end

    def image_dummy(id, caption, lines)
      puts '\begin{reviewdummyimage}'
      puts '\begin{alltt}'
      path = @chapter.image(id).path
      puts "--[[path = #{path} (#{existence(id)})]]--"
      lines.each do |line|
        puts detab(line.rstrip)
      end
      puts '\end{alltt}'
      puts macro('label', image_label(id))
      puts compile_inline(caption)
      puts '\end{reviewdummyimage}'
    end

    def existence(id)
      @chapter.image(id).bound? ? 'exist' : 'not exist'
    end
    private :existence

    def image_label(id)
      "image:#{@chapter.id}:#{id}"
    end
    private :image_label

    def chapter_label()
      "chap:#{@chapter.id}"
    end
    private :chapter_label

    def indepimage(id, caption=nil, metric=nil)
      metrics = parse_metric("latex", metric)
      puts '\begin{reviewimage}'
      if !metrics.empty?
        puts "\\includegraphics[#{metrics}]{#{@chapter.image(id).path}}"
      else
        puts "\\includegraphics[width=\\maxwidth]{#{@chapter.image(id).path}}"
      end
      if !caption.nil? && !caption.empty?
        puts macro('caption', compile_inline(caption))
      end
      puts '\end{reviewimage}'
    end

    alias :numberlessimage indepimage

    def table_header(id, caption)
      if caption && !caption.empty?
        @table_caption = true
        puts '\begin{table}[h]'
##      puts macro('reviewtablecaption', "表#{@chapter.number}.#{@chapter.table(id).number} #{compile_inline(caption)}")
        puts macro('reviewtablecaption', compile_inline(caption))
      end
    end

    def table_begin(ncols)
      if @latex_tsize
        puts macro('begin', 'reviewtable', @latex_tsize)
      elsif @tsize
        cellwidth = @tsize.split(/\s*,\s*/)
        puts macro('begin', 'reviewtable', '|'+(cellwidth.collect{|i| "p{#{i}mm}"}.join('|'))+'|')
      else
        puts macro('begin', 'reviewtable', (['|'] * (ncols + 1)).join('l'))
      end
      puts '\hline'
      @tsize = nil
      @latex_tsize = nil
    end

    def table_separator
      #puts '\hline'
    end

    def th(s)
      ## use shortstack for @<br>
      if  /\\\\/i =~ s
        macro('textgt', macro('shortstack[l]', s))
      else
        macro('textgt', s)
      end
    end

    def td(s)
      ## use shortstack for @<br>
      if  /\\\\/ =~ s
        macro('shortstack[l]', s)
      else
        s
      end
    end

    def tr(rows)
      print rows.join(' & ')
      puts ' \\\\  \hline'
    end

    def table_end
      puts macro('end', 'reviewtable')
      if @table_caption
        puts '\end{table}'
      end
      @table_caption = nil
      blank
    end

    def quote(lines)
      latex_block 'quote', lines
    end

    def center(lines)
      latex_block 'center', lines
    end

    def flushright(lines)
      latex_block 'flushright', lines
    end

    def texequation(lines)
      blank
      puts macro('begin','equation*')
      lines.each do |line|
        puts unescape_latex(line)
      end
      puts macro('end', 'equation*')
      blank
    end

    def latex_block(type, lines)
      blank
      puts macro('begin', type)
      if ReVIEW.book.param["deprecated-blocklines"].nil?
        blocked_lines = split_paragraph(lines)
        puts blocked_lines.join("\n\n")
      else
        lines.each do |line|
          puts line
        end
      end
      puts macro('end', type)
      blank
    end
    private :latex_block

    def direct(lines, fmt)
      return unless fmt == 'latex'
      lines.each do |line|
        puts line
      end
    end

    def comment(str)
      if ReVIEW.book.param["draft"]
        puts macro('pdfcomment', escape(str))
      end
    end

    def label(id)
      puts macro('label', id)
    end

    def pagebreak
      puts '\pagebreak'
    end

    def linebreak
      puts '\\\\'
    end

    def noindent
      print '\noindent'
    end

    def inline_chapref(id)
      if ReVIEW.book.param["chapterlink"]
        "\\hyperref[chap:#{id}]{#{@chapter.env.chapter_index.display_string(id)}}"
      else
        @chapter.env.chapter_index.display_string(id)
      end
    rescue KeyError
      error "unknown chapter: #{id}"
      nofunc_text("[UnknownChapter:#{id}]")
    end

    def inline_chap(id)
      if ReVIEW.book.param["chapterlink"]
        "\\hyperref[chap:#{id}]{#{@chapter.env.chapter_index.number(id)}}"
      else
        @chapter.env.chapter_index.number(id)
      end
    rescue KeyError
      error "unknown chapter: #{id}"
      nofunc_text("[UnknownChapter:#{id}]")
    end

    def inline_title(id)
      if ReVIEW.book.param["chapterlink"]
        "\\hyperref[chap:#{id}]{#{@chapter.env.chapter_index.title(id)}}"
      else
        @chapter.env.chapter_index.title(id)
      end
    rescue KeyError
      error "unknown chapter: #{id}"
      nofunc_text("[UnknownChapter:#{id}]")
    end


    # FIXME: use TeX native label/ref.
    def inline_list(id)
      chapter, id = extract_chapter_id(id)
      macro('reviewlistref', "#{chapter.number}.#{chapter.list(id).number}")
    end

    def inline_table(id)
      chapter, id = extract_chapter_id(id)
      macro('reviewtableref', "#{chapter.number}.#{chapter.table(id).number}")
    end

    def inline_img(id)
      chapter, id = extract_chapter_id(id)
      macro('reviewimageref', "#{chapter.number}.#{chapter.image(id).number}")
    end

    def footnote(id, content)
      if ReVIEW.book.param["footnotetext"]
        puts macro("footnotetext[#{@chapter.footnote(id).number}]",
                   compile_inline(content.strip))
      end
    end

    def inline_fn(id)
      if ReVIEW.book.param["footnotetext"]
        macro("footnotemark[#{@chapter.footnote(id).number}]", "")
      else
        macro('footnote', compile_inline(@chapter.footnote(id).content.strip))
      end
    end

    BOUTEN = "・"

    def inline_bou(str)
      str.split(//).map {|c| macro('ruby', escape(c), macro('textgt', BOUTEN)) }.join('\allowbreak')
    end

    def inline_ruby(str)
      base, ruby = *str.split(/,/)
      macro('ruby', base, ruby)
    end

    # math
    def inline_m(str)
      " $#{str}$ "
    end

    # hidden index
    def inline_hi(str)
      index(str)
    end

    # index -> italic
    def inline_i(str)
      macro('textit', escape(str))
    end

    # index
    def inline_idx(str)
      text(str) + index(str)
    end

    # hidden index??
    def inline_hidx(str)
      index(str)
    end

    # bold
    def inline_b(str)
      macro('textbf', escape(str))
    end

    # line break
    def inline_br(str)
      "\\\\\n"
    end

    def inline_dtp(str)
      # ignore
      ""
    end

    ## @<code> is same as @<tt>
    def inline_code(str)
      macro('texttt', escape(str))
    end

    def nofunc_text(str)
      escape(str)
    end

    def inline_tt(str)
      str_escaped = escape(str).gsub(/\-\-/, "{-}{-}")
      macro('texttt', str_escaped)
    end

    def inline_tti(str)
      macro('texttt', macro('textit', escape(str)))
    end

    def inline_ttb(str)
      macro('texttt', macro('textbf', escape(str)))
    end

    def inline_bib(id)
      "[#{@chapter.bibpaper(id).number}]"
    end

    def inline_hd_chap(chap, id)
      "「#{chap.headline_index.number(id)} #{compile_inline(chap.headline(id).caption)}」"
    end

    def inline_raw(str)
      super(str)
    end

    def inline_sub(str)
      macro('textsubscript', escape(str))
    end

    def inline_sup(str)
      macro('textsuperscript', escape(str))
    end

    def inline_em(str)
      macro('textbf', escape(str))
    end

    def inline_strong(str)
      macro('textbf', escape(str))
    end

    def inline_u(str)
      macro('Underline', escape(str))
    end

    def inline_ami(str)
      macro('reviewami', escape(str))
    end

    def inline_icon(id)
      macro('includegraphics', @chapter.image(id).path)
    end

    def inline_uchar(str)
      # with otf package
      macro('UTF', escape(str))
    end

    def inline_comment(str)
      if ReVIEW.book.param["draft"]
        macro('pdfcomment', escape(str))
      end
    end

    def bibpaper_header(id, caption)
      puts "[#{@chapter.bibpaper(id).number}] #{compile_inline(caption)}"
    end

    def bibpaper_bibpaper(id, caption, lines)
      lines.each do |line|
        puts detab(line)
      end
    end

    def index(str)
      str.sub!(/\(\)/, '')
      decl = ''
      if /@\z/ =~ str
        str.chop!
        decl = '|IndexDecl'
      end
      unless /[^ -~]/ =~ str
        if /\^/ =~ str
          macro('index', escape_index(str.gsub(/\^/, '')) + '@' + escape_index(text(str)) + decl)
        else
          '\index{' + escape_index(text(str)) + decl + '}'
        end
      else
        '\index{' + escape_index(@index_db[str]) + '@' + escape_index(text(str)) + '}'
      end
    end

    def compile_kw(word, alt)
      if alt
        macro('reviewkw', escape(word)) + "（#{escape(alt.strip)}）"
      else
        macro('reviewkw', escape(word))
      end
    end

    def compile_href(url, label)
      if /\A[a-z]+:/ =~ url
        if label
          macro("href", escape_url(url), escape(label))
        else
          macro("url", escape_url(url))
        end
      else
        macro("ref", url)
      end
    end

    def tsize(str)
      @tsize = str
    end

    def latextsize(str)
      @latex_tsize = str
    end

    def image_ext
      "svg"
    end

  end

end
