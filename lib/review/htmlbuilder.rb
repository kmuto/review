# encoding: utf-8
#
# Copyright (c) 2002-2007 Minero Aoki
#               2008-2010 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

require 'review/builder'
require 'review/htmlutils'
require 'review/htmllayout'
require 'review/textutils'

module ReVIEW

  class HTMLBuilder < Builder

    include TextUtils
    include HTMLUtils

    Compiler.defblock(:memo, 0..1)
    Compiler.defblock(:tip, 0..1)
    Compiler.defblock(:info, 0..1)
    Compiler.defblock(:planning, 0..1)
    Compiler.defblock(:best, 0..1)
    Compiler.defblock(:important, 0..1)
    Compiler.defblock(:security, 0..1)
    Compiler.defblock(:caution, 0..1)
    Compiler.defblock(:notice, 0..1)
    Compiler.defblock(:point, 0..1)
    Compiler.defblock(:shoot, 0..1)

    def pre_paragraph
      '<p>'
    end
    def post_paragraph
      '</p>'
    end

    def extname
      ".#{ReVIEW.book.param["htmlext"]}"
    end

    def builder_init(no_error = false)
      @no_error = no_error
      @section = 0
      @subsection = 0
      @subsubsection = 0
      @subsubsubsection = 0
      @noindent = nil
    end
    private :builder_init

    def builder_init_file
      @warns = []
      @errors = []
    end
    private :builder_init_file

    def result
      layout_file = File.join(@book.basedir, "layouts", "layout.erb")
      if File.exists?(layout_file)
        messages() +
          HTMLLayout.new(@output.string, @chapter.title, layout_file).result
      else
        # default XHTML header/footer
        header = <<EOT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:ops="http://www.idpf.org/2007/ops" xml:lang="#{ReVIEW.book.param["language"]}">
<head>
  <meta http-equiv="Content-Type" content="text/html;charset=UTF-8" />
  <meta http-equiv="Content-Style-Type" content="text/css" />
EOT
        unless ReVIEW.book.param["stylesheet"].nil?
          ReVIEW.book.param["stylesheet"].each do |style|
            header += <<EOT
  <link rel="stylesheet" type="text/css" href="#{style}" />
EOT
          end
        end
        header += <<EOT
  <meta name="generator" content="ReVIEW" />
  <title>#{convert_outencoding(@chapter.title)}</title>
</head>
<body>
EOT
        footer = <<EOT
</body>
</html>
EOT
        header + messages() + @output.string + footer
      end
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

    def headline_prefix(level)
      anchor = ""
      case level
      when 1
        @section = 0
        @subsection = 0
        @subsubsection = 0
        @subsubsubsection = 0
        anchor = "#{@chapter.number}"
        if ReVIEW.book.param["secnolevel"] >= 1
          if @chapter.number.to_s =~ /\A\d+\Z/
            prefix = "第#{@chapter.number}章　"
          elsif !@chapter.number.nil? && !@chapter.number.to_s.empty?
            prefix = "#{@chapter.number}　"
          end
        end
      when 2
        @section += 1
        @subsection = 0
        @subsubsection = 0
        @subsubsubsection = 0
        anchor = "#{@chapter.number}-#{@section}"
        if ReVIEW.book.param["secnolevel"] >= 2
          if @chapter.number.to_s =~ /\A\d+\Z/
            prefix = "#{@chapter.number}.#{@section}　"
          elsif !@chapter.number.nil? && !@chapter.number.to_s.empty?
            prefix = "#{@chapter.number}.#{@section}　"
          end
        end
      when 3
        @subsection += 1
        @subsubsection = 0
        @subsubsubsection = 0
        anchor = "#{@chapter.number}-#{@section}-#{@subsection}"
        if ReVIEW.book.param["secnolevel"] >= 3
          if @chapter.number.to_s =~ /\A\d+\Z/
            prefix = "#{@chapter.number}.#{@section}.#{@subsection}　"
          elsif !@chapter.number.nil? && !@chapter.number.to_s.empty?
            prefix = "#{@chapter.number}.#{@section}.#{@subsection}　"
          end
        end
      when 4
        @subsubsection += 1
        @subsubsubsection = 0
        anchor = "#{@chapter.number}-#{@section}-#{@subsection}-#{@subsubsection}"
        if ReVIEW.book.param["secnolevel"] >= 4
          if @chapter.number.to_s =~ /\A\d+\Z/
            prefix = "#{@chapter.number}.#{@section}.#{@subsection}.#{@subsubsection}　"
          elsif !@chapter.number.nil? && !@chapter.number.to_s.empty?
            prefix = "#{@chapter.number}.#{@section}.#{@subsection}.#{@subsubsection}　"
          end
        end
      when 5
        @subsubsubsection += 1
        anchor = "#{@chapter.number}-#{@section}-#{@subsection}-#{@subsubsection}-#{@subsubsubsection}"
        if ReVIEW.book.param["secnolevel"] >= 5
          if @chapter.number.to_s =~ /\A\d+\Z/
            prefix = "#{@chapter.number}.#{@section}.#{@subsection}.#{@subsubsection}.#{@subsubsubsection}　"
          elsif !@chapter.number.nil? && !@chapter.number.to_s.empty?
            prefix = "#{@chapter.number}.#{@section}.#{@subsection}.#{@subsubsection}.#{@subsubsubsection}　"
          end
        end
      end
      [prefix, anchor]
    end
    private :headline_prefix

    def headline(level, label, caption)
      prefix, anchor = headline_prefix(level)
      puts '' if level > 1
      a_id = ""
      unless anchor.nil?
        a_id = %Q[<a id="h#{anchor}" />]
      end
      if caption.empty?
        puts a_id unless label.nil?
      else
        if label.nil?
          puts %Q[<h#{level}>#{a_id}#{prefix}#{compile_inline(caption)}</h#{level}>]
        else
          puts %Q[<h#{level} id="#{label}">#{a_id}#{prefix}#{compile_inline(caption)}</h#{level}>]
        end
      end
    end

    def nonum_begin(level, label, caption)
      puts '' if level > 1
      unless caption.empty?
        if label.nil?
          puts %Q[<h#{level}>#{compile_inline(caption)}</h#{level}>]
        else
          puts %Q[<h#{level} id="#{label}">#{compile_inline(caption)}</h#{level}>]
        end
      end
    end

    def nonum_end(level)
    end

    def column_begin(level, label, caption)
      puts %Q[<div class="column">]
      headline(level, label, caption)
    end

    def column_end(level)
      puts '</div>'
    end

    def xcolumn_begin(level, label, caption)
      puts %Q[<div class="xcolumn">]
      headline(level, label, caption)
    end

    def xcolumn_end(level)
      puts '</div>'
    end

    def ref_begin(level, label, caption)
      print %Q[<div class="reference">]
      headline(level, label, caption)
    end

    def ref_end(level)
      puts '</div>'
    end

    def sup_begin(level, label, caption)
      print %Q[<div class="supplement">]
      headline(level, label, caption)
    end

    def sup_end(level)
      puts '</div>'
    end

    def tsize(str)
      # null
    end

    def captionblock(type, lines, caption)
      puts %Q[<div class="#{type}">]
      unless caption.nil?
        puts %Q[<p class="caption">#{compile_inline(caption)}</p>]
      end
      if ReVIEW.book.param["deprecated-blocklines"].nil?
        blocked_lines = split_paragraph(lines)
        puts blocked_lines.join("\n")
      else
        lines.each {|l| puts "<p>#{l}</p>" }
      end
      puts '</div>'
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

    def notice(lines, caption = nil)
      captionblock("notice", lines, caption)
    end

    def point(lines, caption = nil)
      captionblock("point", lines, caption)
    end

    def shoot(lines, caption = nil)
      captionblock("shoot", lines, caption)
    end

    def box(lines, caption = nil)
      puts %Q[<div class="syntax">]
      puts %Q[<p class="caption">#{compile_inline(caption)}</p>] unless caption.nil?
      print %Q[<pre class="syntax">]
      lines.each {|line| puts detab(line) }
      puts '</pre>'
      puts '</div>'
    end

    def note(lines, caption = nil)
      captionblock("note", lines, caption)
    end

    def ul_begin
      puts '<ul>'
    end

    def ul_item(lines)
      puts "<li>#{lines.join("\n")}</li>"
    end

    def ul_end
      puts '</ul>'
    end

    def ol_begin
      puts '<ol>'
    end

    def ol_item(lines, num)
      puts "<li>#{lines.join("\n")}</li>"
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
      puts "<dd>#{lines.join("\n")}</dd>"
    end

    def dl_end
      puts '</dl>'
    end

    def paragraph(lines)
      if @noindent.nil?
        puts "<p>#{lines.join}</p>"
      else
        puts %Q[<p class="noindent">#{lines.join}</p>]
        @noindent = nil
      end
    end

    def parasep()
      puts '<br />'
    end

    def read(lines)
      if ReVIEW.book.param["deprecated-blocklines"].nil?
        blocked_lines = split_paragraph(lines)
        puts %Q[<div class="lead">\n#{blocked_lines.join("\n")}\n</div>]
      else
        puts %Q[<p class="lead">\n#{lines.join("\n")}\n</p>]
      end
    end

    alias :lead read

    def list(lines, id, caption)
      puts %Q[<div class="caption-code">]
      begin
        list_header id, caption
      rescue KeyError
        error "no such list: #{id}"
      end
      list_body lines
      puts '</div>'
    end

    def list_header(id, caption)
      puts %Q[<p class="caption">リスト#{getChap}#{@chapter.list(id).number}: #{compile_inline(caption)}</p>]
    end

    def list_body(lines)
      print %Q[<pre class="list">]
      lines.each do |line|
        puts detab(line)
      end
      puts '</pre>'
    end

    def source(lines, caption)
      puts %Q[<div class="source-code">]
      source_header caption
      source_body lines
      puts '</div>'
    end

    def source_header(caption)
      puts %Q[<p class="caption">#{compile_inline(caption)}</p>]
    end

    def source_body(lines)
      print %Q[<pre class="source">]
      lines.each do |line|
        puts detab(line)
      end
      puts '</pre>'
    end

    def listnum(lines, id, caption)
      puts %Q[<div class="code">]
      begin
        list_header id, caption
      rescue KeyError
        error "no such list: #{id}"
      end
      listnum_body lines
      puts '</div>'
    end

    def listnum_body(lines)
      print %Q[<pre class="list">]
      lines.each_with_index do |line, i|
        puts detab((i+1).to_s.rjust(2) + ": " + line)
      end
      puts '</pre>'
     end

    def emlist(lines, caption = nil)
      puts %Q[<div class="emlist-code">]
      puts %Q(<p class="caption">#{caption}</p>) unless caption.nil?
      print %Q[<pre class="emlist">]
      lines.each do |line|
        puts detab(line)
      end
      puts '</pre>'
      puts '</div>'
    end

    def emlistnum(lines)
      puts %Q[<div class="emlistnum-code">]
      print %Q[<pre class="emlist">]
      lines.each_with_index do |line, i|
        puts detab((i+1).to_s.rjust(2) + ": " + line)
      end
      puts '</pre>'
      puts '</div>'
    end

    def cmd(lines)
      puts %Q[<div class="cmd-code">]
      print %Q[<pre class="cmd">]
      lines.each do |line|
        puts detab(line)
      end
      puts '</pre>'
      puts '</div>'
    end

    def quotedlist(lines, css_class)
      print %Q[<blockquote><pre class="#{css_class}">]
      lines.each do |line|
        puts detab(line)
      end
      puts '</pre></blockquote>'
    end
    private :quotedlist

    def quote(lines)
      if ReVIEW.book.param["deprecated-blocklines"].nil?
        blocked_lines = split_paragraph(lines)
        puts "<blockquote>#{blocked_lines.join("\n")}</blockquote>"
      else
        puts "<blockquote><pre>#{lines.join("\n")}</pre></blockquote>"
      end
    end

    def doorquote(lines, ref)
      if ReVIEW.book.param["deprecated-blocklines"].nil?
        blocked_lines = split_paragraph(lines)
        puts %Q[<blockquote style="text-align:right;">]
        puts "#{blocked_lines.join("\n")}"
        puts %Q[<p>#{ref}より</p>]
        puts %Q[</blockquote>]
      else
        puts <<-QUOTE
<blockquote style="text-align:right;">
  <pre>#{lines.join("\n")}

#{ref}より</pre>
</blockquote>
QUOTE
      end
    end

    def talk(lines)
      puts %Q[<div class="talk">]
      if ReVIEW.book.param["deprecated-blocklines"].nil?
        blocked_lines = split_paragraph(lines)
        puts "#{blocked_lines.join("\n")}"
      else
        print '<pre>'
        puts "#{lines.join("\n")}"
        puts '</pre>'
      end
      puts '</div>'
    end

    def texequation(lines)
      puts %Q[<div class="equation">]
      if ReVIEW.book.param["mathml"]
        p = MathML::LaTeX::Parser.new
        puts p.parse(unescape_html(lines.join("\n")), true)
      else
        print '<pre>'
        puts "#{lines.join("\n")}"
        puts '</pre>'
      end
      puts '</div>'
    end

    def image_image(id, caption, metric)
      # FIXME: should respect metric?
      puts %Q[<div class="image">]
      puts %Q[<img src="#{@chapter.image(id).path.sub(/\A\.\//, "")}" alt="#{escape_html(compile_inline(caption))}" />]
      image_header id, caption
      puts %Q[</div>]
    end

    def image_dummy(id, caption, lines)
      puts %Q[<div class="image">]
      puts %Q[<pre class="dummyimage">]
      lines.each do |line|
        puts detab(line)
      end
      puts %Q[</pre>]
      image_header id, caption
      puts %Q[</div>]
    end

    def image_header(id, caption)
      puts %Q[<p class="caption">]
      puts %Q[図#{getChap}#{@chapter.image(id).number}: #{compile_inline(caption)}]
      puts %Q[</p>]
    end

    def table(lines, id = nil, caption = nil)
      rows = []
      sepidx = nil
      lines.each_with_index do |line, idx|
        if /\A[\=\-]{12}/ =~ line
          # just ignore
          #error "too many table separator" if sepidx
          sepidx ||= idx
          next
        end
        rows.push line.strip.split(/\t+/).map {|s| s.sub(/\A\./, '') }
      end
      rows = adjust_n_cols(rows)

      puts %Q[<div class="table">]
      begin
        table_header id, caption unless caption.nil?
      rescue KeyError => err
        error "no such table: #{id}"
      end
      table_begin rows.first.size
      return if rows.empty?
      if sepidx
        sepidx.times do
          tr rows.shift.map {|s| th(s) }
        end
        rows.each do |cols|
          tr cols.map {|s| td(s) }
        end
      else
        rows.each do |cols|
          h, *cs = *cols
          tr [th(h)] + cs.map {|s| td(s) }
        end
      end
      table_end
      puts %Q[</div>]
    end

    def table_header(id, caption)
      puts %Q[<p class="caption">表#{getChap}#{@chapter.table(id).number}: #{compile_inline(caption)}</p>]
    end

    def table_begin(ncols)
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

    def comment(str)
      puts %Q(<!-- #{escape_html(str)} -->)
    end

    def footnote(id, str)
      puts %Q(<div class="footnote"><p class="footnote"><a id="fn-#{id}">[*#{@chapter.footnote(id).number}] #{compile_inline(str)}</a></p></div>)
    end

    def indepimage(id, caption="", metric=nil)
      caption = "" if caption.nil?
      puts %Q[<div class="image">]
      begin
        puts %Q[<img src="#{@chapter.image(id).path.sub(/\A\.\//, "")}" alt="#{caption}" />]
      rescue
        puts %Q[<pre>missing image: #{id}</pre>]
      end

      unless caption.empty?
        puts %Q[<p class="caption">]
        puts %Q[図: #{compile_inline(caption)}]
        puts %Q[</p>]
      end
      puts %Q[</div>]
    end

    alias :numberlessimage indepimage

    def hr
      puts "<hr />"
    end

    def label(id)
      puts %Q(<a id="#{id}" />)
    end

    def linebreak
      puts "<br />"
    end

    def pagebreak
      puts %Q(<br class="pagebreak" />)
    end

    def bpo(lines)
      puts "<bpo>"
      lines.each do |line|
        puts detab(line)
      end
      puts "</bpo>"
    end

    def noindent
      @noindent = true
    end

    def inline_fn(id)
      %Q(<a href="#fn-#{id}">*#{@chapter.footnote(id).number}</a>)
    end

    def compile_ruby(base, ruby)
      %Q[<ruby><rb>{escape_html(base)}</rb><rp>(</rp><rt>#{ruby}</rt><rp>)</rp></ruby>]
    end

    def compile_kw(word, alt)
      %Q[<b class="kw">] +
        if alt
        then escape_html(word + " (#{alt.strip})")
        else escape_html(word)
        end +
        "</b><!-- IDX:#{escape_html(word)} -->"
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

    def inline_tti(str)
      %Q(<tt><i>#{escape_html(str)}</i></tt>)
    end

    def inline_ttb(str)
      %Q(<tt><b>#{escape_html(str)}</b></tt>)
    end

    def inline_dtp(str)
      "<?dtp #{str} ?>"
    end

    def inline_code(str)
      %Q(<tt class="inline-code">#{str}</tt>)
    end

    def inline_idx(str)
      %Q(#{escape_html(str)}<!-- IDX:#{escape_html(str)} -->)
    end

    def inline_hidx(str)
      %Q(<!-- IDX:#{escape_html(str)} -->)
    end

    def inline_br(str)
      %Q(<br />)
    end

    def inline_m(str)
      if ReVIEW.book.param["mathml"]
        p = MathML::LaTeX::Parser.new
        %Q[<span class="equation">#{p.parse(str, nil)}</span>]
      else
        %Q[<span class="equation">#{escape_html(str)}</span>]
      end
    end

    def text(str)
      str
    end

    def bibpaper(lines, id, caption)
      puts "<div>"
      bibpaper_header id, caption
      unless lines.empty?
        bibpaper_bibpaper id, caption, lines
      end
      puts "</div>"
    end

    def bibpaper_header(id, caption)
      puts %Q(<a name="bib-#{id}">)
      puts "[#{@chapter.bibpaper(id).number}] #{compile_inline(caption)}"
      puts %Q(</a>)
    end

    def bibpaper_bibpaper(id, caption, lines)
      puts %Q(<p>)
      lines.each do |line|
        puts detab(line)
      end
      puts %Q(</p>)
    end

    def inline_bib(id)
      %Q(<a href=".#{@book.bib_file.gsub(/re\Z/, "html")}#bib-#{id}">[#{@chapter.bibpaper(id).number}]</a>)
    end

    def inline_hd_chap(chap, id)
      "「#{chap.headline_index.number(id)} #{chap.headline(id).caption}」"
    end

    def inline_list(id)
      chapter, id = extract_chapter_id(id)
      "リスト#{getChap(chapter)}#{chapter.list(id).number}"
    rescue KeyError
      error "unknown list: #{id}"
      nofunc_text("[UnknownList:#{id}]")
    end

    def inline_table(id)
      chapter, id = extract_chapter_id(id)
      "表#{getChap(chapter)}#{chapter.table(id).number}"
    rescue KeyError
      error "unknown table: #{id}"
      nofunc_text("[UnknownTable:#{id}]")
    end

    def inline_img(id)
      chapter, id = extract_chapter_id(id)
      "図#{getChap(chapter)}#{chapter.image(id).number}"
    rescue KeyError
      error "unknown image: #{id}"
      nofunc_text("[UnknownImage:#{id}]")
    end

    def inline_asis(str, tag)
      %Q(<#{tag}>#{escape_html(str)}</#{tag}>)
    end

    def inline_abbr(str)
      inline_asis(str, "abbr")
    end

    def inline_acronym(str)
      inline_asis(str, "acronym")
    end

    def inline_cite(str)
      inline_asis(str, "cite")
    end

    def inline_dfn(str)
      inline_asis(str, "dfn")
    end

    def inline_em(str)
      inline_asis(str, "em")
    end

    def inline_kbd(str)
      inline_asis(str, "kbd")
    end

    def inline_samp(str)
      inline_asis(str, "samp")
    end

    def inline_strong(str)
      inline_asis(str, "strong")
    end

    def inline_var(str)
      inline_asis(str, "var")
    end

    def inline_big(str)
      inline_asis(str, "big")
    end

    def inline_small(str)
      inline_asis(str, "small")
    end

    def inline_sub(str)
      inline_asis(str, "sub")
    end

    def inline_sup(str)
      inline_asis(str, "sup")
    end

    def inline_tt(str)
      inline_asis(str, "tt")
    end

    def inline_del(str)
      inline_asis(str, "del")
    end

    def inline_ins(str)
      inline_asis(str, "ins")
    end

    def inline_u(str)
      %Q(<u>#{escape_html(str)}</u>)
    end

   def inline_recipe(str)
      %Q(<span class="recipe">「#{escape_html(str)}」</span>)
    end

    def inline_icon(id)
      %Q[<img src=".#{@book.image_dir}#{find_pathes(id)[0].sub(/\A\.\//, "/")}" alt="[#{id}]" />]
    end

    def inline_uchar(str)
      %Q(&#x#{str};)
    end

    def inline_raw(str)
      escape_html(str)
    end

    def nofunc_text(str)
      escape_html(str)
    end

    def compile_href(url, label)
      %Q(<a href="#{escape_html(url)}" class="link">#{label.nil? ? escape_html(url) : escape_html(label)}</a>)
    end

    def flushright(lines)
      if ReVIEW.book.param["deprecated-blocklines"].nil?
        puts split_paragraph(lines).join("\n").gsub("<p>", "<p class=\"flushright\">")
      else
        puts %Q[<div style="text-align:right;">]
        print %Q[<pre class="flushright">]
        lines.each {|line| puts detab(line) }
        puts '</pre>'
        puts '</div>'
      end
    end
  end

end   # module ReVIEW
