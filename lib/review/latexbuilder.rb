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
      @blank_needed = false
      @latex_tsize = nil
      @tsize = nil
      @table_caption = nil
      @ol_num = nil
      @sec_counter = SecCounter.new(5, @chapter)
    end
    private :builder_init_file

    def blank
      @blank_needed = true
    end
    private :blank

    def blank_reset
      @blank_needed = false
    end
    private :blank_reset

    HEADLINE = {
      1 => 'chapter',
      2 => 'section',
      3 => 'subsection',
      4 => 'subsubsection',
      5 => 'paragraph',
      6 => 'subparagraph'
    }

    def headline(level, label, caption)
      buf = ""
      _, anchor = headline_prefix(level)
      headline_name = HEADLINE[level]
      if @chapter.kind_of? ReVIEW::Book::Part
        headline_name = "part"
      end
      prefix = ""
      if level > @book.config["secnolevel"] || (@chapter.number.to_s.empty? && level > 1)
        prefix = "*"
      end
      buf << macro(headline_name+prefix, caption) << "\n"
      if prefix == "*" && level <= @book.config["toclevel"].to_i
        buf << "\\addcontentsline{toc}{#{headline_name}}{#{caption}}\n"
      end
      if level == 1
        buf << macro('label', chapter_label) << "\n"
      else
        buf << macro('label', sec_label(anchor)) << "\n"
      end
      buf
    rescue
      error "unknown level: #{level}"
    end

    def nonum_begin(level, label, caption)
      "\n" + macro(HEADLINE[level]+"*", caption) + "\n"
    end

    def nonum_end(level)
    end

    def column_begin(level, label, caption)
      buf = ""
      blank
      if @blank_needed
        buf << "\n"
        blank_reset
      end
      buf << "\\begin{reviewcolumn}\n"
      if label
        buf << "\\hypertarget{#{column_label(label)}}{}\n"
      else
        buf << "\\hypertarget{#{column_label(caption)}}{}\n"
      end
      buf << macro('reviewcolumnhead', nil, caption) << "\n"
      if level <= @book.config["toclevel"].to_i
        buf << "\\addcontentsline{toc}{#{HEADLINE[level]}}{#{caption}}" << "\n"
      end
      buf
    end

    def column_end(level)
      buf = ""
      buf << "\\end{reviewcolumn}\n"
      blank
      buf
    end

    def captionblock(type, lines, caption)
      buf = ""
      buf << "\\begin{reviewminicolumn}\n"
      unless caption.nil?
        buf << "\\reviewminicolumntitle{#{caption}}"
      end

      if @book.config["deprecated-blocklines"].nil?
        buf << lines.join("")
      else
        error "deprecated-blocklines is obsoleted."
      end

      buf << "\\end{reviewminicolumn}\n"
      buf
    end

    def box(lines, caption = nil)
      buf = "\n"
      if caption
        buf << macro('reviewboxcaption', "#{caption}") << "\n"
      end
      buf << '\begin{reviewbox}' << "\n"
      lines.each do |line|
        buf << detab(line) << "\n"
      end<
      buf << '\end{reviewbox}' << "\n"
    end

    def ul_begin
      buf = "\n"
      buf << '\begin{itemize}' << "\n"
      buf
    end

    def ul_item(lines)
      str = lines.join
      str.sub!(/\A(\[)/){'\lbrack{}'}
      '\item ' + str + "\n"
    end

    def ul_end
      '\end{itemize}' + "\n"
    end

    def ol_begin
      buf = "\n"
      buf << '\begin{enumerate}' << "\n"
      if @ol_num
        buf << "\\setcounter{enumi}{#{@ol_num - 1}}\n"
        @ol_num = nil
      end
      buf
    end

    def ol_item(lines, num)
      str = lines.join
      str.sub!(/\A(\[)/){'\lbrack{}'}
      '\item ' + str + "\n"
    end

    def ol_end
      '\end{enumerate}' + "\n"
    end

    def dl_begin
      "\n" + '\begin{description}' + "\n"
    end

    def dt(str)
      str.sub!(/\[/){'\lbrack{}'}
      str.sub!(/\]/){'\rbrack{}'}
      '\item[' + str + '] \mbox{} \\\\' + "\n"
    end

    def dd(lines)
      lines.join + "\n"
    end

    def dl_end
      '\end{description}' + "\n"
    end

    def paragraph(lines)
      buf = "\n"
      lines.each do |line|
        buf << line
      end
      buf << "\n"
      buf
    end

    def parasep
      '\\parasep' + "\n"
    end

    def read(lines)
      latex_block 'quotation', lines
    end

    alias_method :lead, :read

    def highlight_listings?
      @book.config["highlight"] && @book.config["highlight"]["latex"] == "listings"
    end
    private :highlight_listings?

    def emlist(lines, caption = nil, lang = nil)
      buf = "\n"
      if highlight_listings?
        buf << common_code_block_lst(nil, lines, 'reviewemlistlst', 'title', caption, lang)
      else
        buf << common_code_block(nil, lines, 'reviewemlist', caption, lang) do |line, idx|
          detab(line) + "\n"
        end
      end
      buf
    end

    def emlistnum(lines, caption = nil, lang = nil)
      buf = "\n"
      if highlight_listings?
        buf << common_code_block_lst(nil, lines, 'reviewemlistnumlst', 'title', caption, lang)
      else
        buf << common_code_block(nil, lines, 'reviewemlist', caption, lang) do |line, idx|
          detab((idx+1).to_s.rjust(2)+": " + line) + "\n"
        end
      end
      buf
    end

    ## override Builder#list
    def list(lines, id, caption = nil, lang = nil)
      buf = ""
      if highlight_listings?
        buf << common_code_block_lst(id, lines, 'reviewlistlst', 'caption', caption, lang)
      else
        buf << common_code_block(id, lines, 'reviewlist', caption, lang) do |line, idx|
          detab(line) + "\n"
        end
      end
      buf
    end


    ## override Builder#listnum
    def listnum(lines, id, caption = nil, lang = nil)
      buf = ""
      if highlight_listings?
        buf << common_code_block_lst(id, lines, 'reviewlistnumlst', 'caption', caption, lang)
      else
        buf << common_code_block(id, lines, 'reviewlist', caption, lang) do |line, idx|
          detab((idx+1).to_s.rjust(2)+": " + line) + "\n"
        end
      end
      buf
    end

    def cmd(lines, caption = nil, lang = nil)
      buf = ""
      if highlight_listings?
        buf << common_code_block_lst(nil, lines, 'reviewcmdlst', 'title', caption, lang)
      else
        buf << "\n"
        buf << common_code_block(nil, lines, 'reviewcmd', caption, lang) do |line, idx|
          detab(line) + "\n"
        end
      end
      buf
    end

    def common_code_block(id, lines, command, caption, lang)
      buf = ""
      if caption
        if command =~ /emlist/ || command =~ /cmd/
          buf << macro(command + 'caption', "#{caption}") + "\n"
        else
          begin
            buf << "\n"
            buf << macro('reviewlistcaption', "#{I18n.t("list")}#{I18n.t("format_number_header", [@chapter.number, @chapter.list(id).number])}#{I18n.t("caption_prefix")}#{caption}") + "\n"
          rescue KeyError
            error "no such list: #{id}"
          end
        end
      end
      body = ""
      lines.each_with_index do |line, idx|
        body.concat(yield(line, idx))
      end
      buf << macro('begin' ,command) + "\n"
      buf << body
      buf << macro('end' ,command) + "\n"
      buf
    end

    def common_code_block_lst(id, lines, command, title, caption, lang)
      buf = ""
      caption_str = (caption || "")
      if title == "title" && caption_str == ""
        caption_str = "\\relax" ## dummy charactor to remove lstname
        buf << "\\vspace{-1.5em}"
      end
      if @book.config["highlight"] && @book.config["highlight"]["lang"]
        lexer = @book.config["highlight"]["lang"] # default setting
      else
        lexer = ""
      end
      lexer = lang if lang.present?
      body = lines.inject(''){|i, j| i + detab(unescape_latex(j)) + "\n"}
      buf << "\\begin{"+command+"}["+title+"={"+caption_str+"},language={"+ lexer+"}]" + "\n"
      buf << body
      buf << "\\end{"+ command + "}" + "\n"
      buf
    end

    def source(lines, caption = nil, lang = nil)
      if highlight_listings?
        common_code_block_lst(nil, lines, 'reviewlistlst', 'title', caption, lang)
      else
      buf = "\n"
      buf << '\begin{reviewlist}' << "\n"
      buf << source_header(caption)
      buf << source_body(lines)
      buf << '\end{reviewlist}' << "\n"
      buf << "\n"
      buf
      end
    end

    def source_header(caption)
      macro('reviewlistcaption', caption) + "\n"
    end

    def source_body(lines)
      buf = ""
      lines.each do |line|
        buf << detab(line) << "\n"
      end
      buf
    end


    def image_header(id, caption)
    end

    def result_metric(array)
      "#{array.join(',')}"
    end

    def image_image(id, caption, metric)
      buf = ""
      metrics = parse_metric("latex", metric)
      # image is always bound here
      buf << '\begin{reviewimage}' << "\n"
      if metrics.present?
        buf << "\\includegraphics[#{metrics}]{#{@chapter.image(id).path}}\n"
      else
        buf << "\\includegraphics[width=\\maxwidth]{#{@chapter.image(id).path}}\n"
      end
      if caption.present?
        buf << macro('caption', caption) << "\n"
      end
      buf << macro('label', image_label(id)) << "\n"
      buf << '\end{reviewimage}' << "\n"
      buf
    end

    def image_dummy(id, caption, lines)
      buf << '\begin{reviewdummyimage}' << "\n"
      path = @chapter.image(id).path
      buf << "--[[path = #{path} (#{existence(id)})]]--\n"
      lines.each do |line|
        buf << detab(line.rstrip) << "\n"
      end
      buf << macro('label', image_label(id)) << "\n"
      buf << caption << "\n"
      buf << '\end{reviewdummyimage}' << "\n"
      buf
    end

    def existence(id)
      @chapter.image(id).bound? ? 'exist' : 'not exist'
    end
    private :existence

    def image_label(id, chapter=nil)
      chapter ||= @chapter
      "image:#{chapter.id}:#{id}"
    end
    private :image_label

    def chapter_label
      "chap:#{@chapter.id}"
    end
    private :chapter_label

    def sec_label(sec_anchor)
      "sec:#{sec_anchor}"
    end
    private :sec_label

    def table_label(id, chapter=nil)
      chapter ||= @chapter
      "table:#{chapter.id}:#{id}"
    end
    private :table_label

    def bib_label(id)
      "bib:#{id}"
    end
    private :bib_label

    def column_label(id)
      filename = @chapter.id
      num = @chapter.column(id).number
      "column:#{filename}:#{num}"
    end
    private :column_label

    def indepimage(id, caption=nil, metric=nil)
      buf = ""
      metrics = parse_metric("latex", metric)
      buf << '\begin{reviewimage}' << "\n"
      if metrics.present?
        buf << "\\includegraphics[#{metrics}]{#{@chapter.image(id).path}}\n"
      else
        buf << "\\includegraphics[width=\\maxwidth]{#{@chapter.image(id).path}}\n"
      end
      if caption.present?
        buf << macro('reviewindepimagecaption',
                   %Q[#{I18n.t("numberless_image")}#{I18n.t("caption_prefix")}#{caption}]) << "\n"
      end
      buf << '\end{reviewimage}' << "\n"
      buf
    end

    alias_method :numberlessimage, :indepimage

    def node_table(node)
      id = node.args[0].to_raw
      caption = node.args[1].to_doc
      lines = []
      node.content.each do |line|
        lines << line.to_doc
      end
      buf = ""
      rows = []
      sepidx = nil
      lines.each_with_index do |line, idx|
        if /\A[\=\{\-\}]{12}/ =~ line
          # just ignore
          #error "too many table separator" if sepidx
          sepidx ||= idx
          next
        end
        rows.push line.strip.split(/\t+/).map {|s| s.sub(/\A\./, '') }
      end
      rows = adjust_n_cols(rows)

      begin
        buf << table_header(id, caption) unless caption.nil?
      rescue KeyError
        error "no such table: #{id}"
      end
      return buf if rows.empty?
      buf << table_begin(rows.first.size)
      if sepidx
        sepidx.times do
          buf << tr(rows.shift.map {|s| th(s) })
        end
        rows.each do |cols|
          buf << tr(cols.map {|s| td(s) })
        end
      else
        rows.each do |cols|
          h, *cs = *cols
          buf << tr([th(h)] + cs.map {|s| td(s) })
        end
      end
      buf << table_end
      buf
    end

    def table_header(id, caption)
      buf = ""
      if caption.present?
        @table_caption = true
        buf << '\begin{table}[h]' << "\n"
        buf << macro('reviewtablecaption', caption) << "\n"
      end
      buf << macro('label', table_label(id)) << "\n"
      buf
    end

    def table_begin(ncols)
      buf = ""
      if @latex_tsize
        buf << macro('begin', 'reviewtable', @latex_tsize) << "\n"
      elsif @tsize
        cellwidth = @tsize.split(/\s*,\s*/)
        buf << macro('begin', 'reviewtable', '|'+(cellwidth.collect{|i| "p{#{i}mm}"}.join('|'))+'|') << "\n"
      else
        buf << macro('begin', 'reviewtable', (['|'] * (ncols + 1)).join('l')) << "\n"
      end
      buf << '\hline' << "\n"
      @tsize = nil
      @latex_tsize = nil
      buf
    end

    def table_separator
      #puts '\hline'
    end

    def th(s)
      ## use shortstack for @<br>
      if /\\\\/i =~ s
        macro('reviewth', macro('shortstack[l]', s))
      else
        macro('reviewth', s)
      end
    end

    def td(s)
      ## use shortstack for @<br>
      if /\\\\/ =~ s
        macro('shortstack[l]', s)
      else
        s
      end
    end

    def tr(rows)
      buf = ""
      buf << rows.join(' & ')
      buf << ' \\\\  \hline' << "\n"
      buf
    end

    def table_end
      buf = ""
      buf << macro('end', 'reviewtable') << "\n"
      if @table_caption
        buf << '\end{table}' << "\n"
      end
      @table_caption = nil
      buf << "\n"
      buf
    end

    def quote(lines)
      latex_block 'quote', lines
    end

    def center(lines)
      latex_block 'center', lines
    end

    alias_method :centering, :center

    def flushright(lines)
      latex_block 'flushright', lines
    end

    def texequation(lines)
      buf = "\n"
      buf << macro('begin','equation*') << "\n"
      lines.each do |line|
        buf << unescape_latex(line) << "\n"
      end
      buf << macro('end', 'equation*') << "\n"
      buf << "\n"
      buf
    end

    def latex_block(type, lines)
      buf = "\n"
      buf << macro('begin', type)
      if @book.config["deprecated-blocklines"].nil?
        buf << lines.join("")
      else
        error "deprecated-blocklines is obsoleted."
      end
      buf << macro('end', type) << "\n"
      buf
    end
    private :latex_block

    def direct(lines, fmt)
      buf = ""
      return buf unless fmt == 'latex'
      lines.each do |line|
        buf << line << "\n"
      end
      buf
    end

    def comment(lines, comment = nil)
      buf = ""
      lines ||= []
      lines.unshift comment unless comment.blank?
      if @book.config["draft"]
        str = lines.join("")
        buf << macro('pdfcomment', str) << "\n"
      end
      buf
    end

    def hr
      '\hrule' + "\n"
    end

    def label(id)
      macro('label', id) + "\n"
    end

    def node_label(node)
      id = node.args[0].to_raw
      macro('label', id) + "\n"
    end

    def pagebreak
      '\pagebreak' + "\n"
    end

    def linebreak
      '\\\\' + "\n"
    end

    def noindent
      '\noindent'
    end

    def node_inline_chapref(node)
      id = node[0].to_raw
      title = @book.chapter_index.display_string(id)
      if @book.config["chapterlink"]
        "\\hyperref[chap:#{id}]{#{title}}"
      else
        title
      end
    rescue KeyError
      error "unknown chapter: #{id}"
      nofunc_text("[UnknownChapter:#{id}]")
    end

    def node_inline_chap(node)
      id = node[0].to_raw
      if @book.config["chapterlink"]
        "\\hyperref[chap:#{id}]{#{@book.chapter_index.number(id)}}"
      else
        @book.chapter_index.number(id)
      end
    rescue KeyError
      error "unknown chapter: #{id}"
      nofunc_text("[UnknownChapter:#{id}]")
    end

    def node_inline_title(node)
      id = node[0].to_raw
      title = @book.chapter_index.title(id)
      if @book.config["chapterlink"]
        "\\hyperref[chap:#{id}]{#{title}}"
      else
        title
      end
    rescue KeyError
      error "unknown chapter: #{id}"
      nofunc_text("[UnknownChapter:#{id}]")
    end


    # FIXME: use TeX native label/ref.
    def node_inline_list(node)
      id = node[0].to_raw
      chapter, id = extract_chapter_id(id)
      macro('reviewlistref', "#{chapter.number}.#{chapter.list(id).number}")
    end

    def node_inline_table(node)
      id = node[0].to_raw
      chapter, id = extract_chapter_id(id)
      macro('reviewtableref', "#{chapter.number}.#{chapter.table(id).number}", table_label(id, chapter))
    end

    def node_inline_img(node)
      id = node[0].to_raw
      chapter, id = extract_chapter_id(id)
      macro('reviewimageref', "#{chapter.number}.#{chapter.image(id).number}", image_label(id, chapter))
    end

    def footnote(id, content)
      if @book.config["footnotetext"]
        macro("footnotetext[#{@chapter.footnote(id).number}]",
                   content.strip) + "\n"
      end
    end

    def node_inline_fn(node)
      id = node[0].to_raw
      if @book.config["footnotetext"]
        macro("footnotemark[#{@chapter.footnote(id).number}]", "")
      else
        macro('footnote', escape(@chapter.footnote(id).content.strip))
      end
    end

    BOUTEN = "・"

    def inline_bou(str)
      str.split(//).map {|c| macro('ruby', escape(c), macro('textgt', BOUTEN)) }.join('\allowbreak')
    end

    def compile_ruby(base, ruby)
      macro('ruby', base, ruby)
    end

    # math
#    def inline_m(str)
#      " $#{str}$ "
#    end

    def node_inline_m(node)
      " $#{node[0].to_raw}$ "
    end

    # hidden index
    def inline_hi(str)
      index(str)
    end

    # index -> italic
    def inline_i(str)
      macro('textit', str)
    end

    # index
    def inline_idx(str)
      escape(str) + index(str)
    end

    def node_inline_idx(nodelist)
      content = nodelist[0].to_raw
      escape(content) + index(content)
    end

    # hidden index??
    def inline_hidx(str)
      index(str)
    end

    def node_inline_hidx(nodelist)
      content = nodelist[0].to_raw
      index(content)
    end

    # bold
    def inline_b(str)
      macro('textbf', str)
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
      macro('texttt', str)
    end

    def nofunc_text(str)
      escape(str)
    end

    def inline_tt(str)
      macro('texttt', str)
    end

    def inline_del(str)
      macro('reviewstrike', str)
    end

    def inline_tti(str)
      macro('texttt', macro('textit', str))
    end

    def inline_ttb(str)
      macro('texttt', macro('textbf', str))
    end

    def node_inline_bib(node)
      id = node[0].to_raw
      macro('reviewbibref', "[#{@chapter.bibpaper(id).number}]", bib_label(id))
    end

    def inline_hd_chap(chap, id)
      n = chap.headline_index.number(id)
      if chap.number and @book.config["secnolevel"] >= n.split('.').size
        str = I18n.t("chapter_quote", "#{chap.headline_index.number(id)} #{chap.headline(id).caption}")
      else
        str = I18n.t("chapter_quote", chap.headline(id).caption)
      end
      if @book.config["chapterlink"]
        anchor = n.gsub(/\./, "-")
        macro('reviewsecref', escape(str), sec_label(anchor))
      else
        escape(str)
      end
    end

    def node_inline_column(node)
      id = node[0].to_raw
      macro('reviewcolumnref', "#{@chapter.column(id).caption}", column_label(id))
    end

    def inline_raw(str)
      super(str)
    end

    def inline_sub(str)
      macro('textsubscript', str)
    end

    def inline_sup(str)
      macro('textsuperscript', str)
    end

    def inline_em(str)
      macro('reviewem', str)
    end

    def inline_strong(str)
      macro('reviewstrong', str)
    end

    def inline_u(str)
      macro('Underline', str)
    end

    def inline_ami(str)
      macro('reviewami', str)
    end

    def node_inline_icon(node)
      id = node[0].to_raw
      macro('includegraphics', @chapter.image(id).path)
    end

    def inline_uchar(str)
      # with otf package
      macro('UTF', str)
    end

    def inline_comment(str)
      if @book.config["draft"]
        macro('pdfcomment', escape(str))
      else
        ""
      end
    end

    def bibpaper(lines, id, caption)
      buf = ""
      buf << bibpaper_header(id, caption)
      if lines.empty?
        buf << "\n"
      else
        buf << "\n"
        buf << bibpaper_bibpaper(id, caption, lines)
      end
      buf << "\n"
      buf
    end

    def bibpaper_header(id, caption)
      "[#{@chapter.bibpaper(id).number}] #{caption}\n" +
        macro('label', bib_label(id))
    end

    def bibpaper_bibpaper(id, caption, lines)
      lines.join("")
    end

    def index(str)
     "\\index{" + str + "}"
    end

    def compile_kw(word, alt)
      if alt
        macro('reviewkw', word) + "（#{alt.strip}）"
      else
        macro('reviewkw', word)
      end
    end

    def compile_href(url, label)
      if /\A[a-z]+:/ =~ url
        if label
          macro("href", escape_url(url), label)
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
      "pdf"
    end

    def olnum(num)
      @ol_num = num.to_i
    end

  end

end
