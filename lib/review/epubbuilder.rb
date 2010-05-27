# epubbuilder.rb
#   derived from htmlbuider.rb
#
# Copyright (c) 2010 Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

require 'review/builder'
require 'review/htmlutils'
require 'review/htmllayout'
require 'review/textutils'
require 'review/htmlbuilder'

module ReVIEW

  class EPUBBuilder < HTMLBuilder

    [:u, :tti].each {|e|
      Compiler.definline(e)
    }

    Compiler.defsingle(:indepimage, 1)
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

    def builder_init(no_error = false)
      @no_error = no_error
      @section = 0
      @subsection = 0
      @subsubsection = 0
      @subsubsubsection = 0
    end
    private :builder_init

    def extname
      '.html'
    end

    def raw_result
      @output.string
    end

    def result
      layout_file = File.join(@book.basedir, "layouts", "layout.erb")
      if File.exists?(layout_file)
        messages() +
          HTMLLayout.new(@output.string, @chapter.title, layout_file).result
      else
        # FIXME
        header = <<EOT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:ops=" http://www.idpf.org/2007/ops" xml:lang="ja" lang="ja">
<head>
  <meta http-equiv="Content-Type" content="text/html;charset=UTF-8"/>
  <meta http-equiv="Content-Style-Type" content="text/css"/>
EOT
        unless @param["stylesheet"].nil?
          header += <<EOT
  <link rel="stylesheet" type="text/css" href="#{@param["stylesheet"]}"/>
EOT
        end
        header += <<EOT
  <meta name="generator" content="ReVIEW EPUB Maker"/>
  <title>#{@chapter.title}</title>
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

    def headline_prefix(level)
      anchor = ""
      case level
      when 1
        @section = 0
        @subsection = 0
        @subsubsection = 0
        @subsubsubsection = 0
        anchor = "#{@chapter.number}"
        if @param["secnolevel"] >= 1
          if @chapter.number.to_s =~ /\A\d+$/
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
        if @param["secnolevel"] >= 2
          if @chapter.number.to_s =~ /\A\d+$/
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
        if @param["secnolevel"] >= 3
          if @chapter.number.to_s =~ /\A\d+$/
            prefix = "#{@chapter.number}.#{@section}.#{@subsection}　"
          elsif !@chapter.number.nil? && !@chapter.number.to_s.empty?
            prefix = "#{@chapter.number}.#{@section}.#{@subsection}　"
          end
        end
      when 4
        @subsubsection += 1
        @subsubsubsection = 0
        anchor = "#{@chapter.number}-#{@section}-#{@subsection}-#{@subsubsection}"
        if @param["secnolevel"] >= 4
          if @chapter.number.to_s =~ /\A\d+$/
            prefix = "#{@chapter.number}.#{@section}.#{@subsection}.#{@subsubsection}　"
          elsif !@chapter.number.nil? && !@chapter.number.to_s.empty?
            prefix = "#{@chapter.number}.#{@section}.#{@subsection}.#{@subsubsection}　"
          end
        end
      when 5
        @subsubsubsection += 1
        anchor = "#{@chapter.number}-#{@section}-#{@subsection}-#{@subsubsection}-#{@subsubsubsection}"
        if @param["secnolevel"] >= 5
          if @chapter.number.to_s =~ /\A\d+$/
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
      print "<a name=\"h#{anchor}\" />" unless anchor.empty?
      if label.nil?
        puts "<h#{level}>#{prefix}#{escape_html(caption)}</h#{level}>"
      else
        puts "<h#{level} id='#{label}'>#{prefix}#{escape_html(caption)}</h#{level}>"
      end
    end

    def column_begin(level, label, caption)
      puts "<div class='column'>"
      headline(level, label, caption)   # FIXME
    end

    def column_end(level)
      puts '</div>'
    end

    def tsize(str)
      # null
    end

    def captionblock(type, lines, caption)
      puts "<div class=\"#{type}\">"
      unless caption.nil?
        puts "<p class=\"#{type}-title\">#{escape_html(caption)}</p>"
      end
      lines.each {|l|
        puts "<p>#{l}</p>"
      }
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

    def shot(lines, caption = nil)
      captionblock("shoot", lines, caption)
    end

    def list(lines, id, caption)
      puts '<div class="caption-code">'
      begin
        list_header id, caption
      rescue KeyError
        error "no such list: #{id}"
      end
      list_body lines
      puts '</div>'
    end

    def list_header(id, caption)
      puts %Q[<p class="listcaption">リスト#{getChap}#{@chapter.list(id).number}: #{escape_html(caption)}</p>]
    end

    def list_body(lines)
      puts '<pre class="list">'
      lines.each do |line|
        puts detab(line)
      end
      puts '</pre>'
    end

    def source(lines, caption)
      puts '<div class="caption-code">'
      source_header caption
      source_body lines
      puts '</div>'
    end

    def source_header(caption)
      puts %Q[<p class="sourcecaption">#{escape_html(caption)}</p>]
    end

    def source_body(lines)
      puts '<pre class="source">'
      lines.each do |line|
        puts detab(line)
      end
      puts '</pre>'
    end

    def listnum(lines, id, caption)
      puts '<div class="code">'
      begin
        list_header id, caption
      rescue KeyError
        error "no such list: #{id}"
      end
      listnum_body lines
      puts '</div>'
    end

    def listnum_body(lines)
      puts '<pre class="list">'
      lines.each_with_index do |line, i|
        puts detab((i+1).to_s.rjust(2) + ": " + line)
      end
      puts '</pre>'
     end

    def emlist(lines, caption = nil)
      puts '<div class="code">'
      puts %Q(<p class="emlistcaption">#{caption}</p>) unless caption.nil?
      puts '<pre class="emlist">'
      lines.each do |line|
        puts detab(line)
      end
      puts '</pre>'
      puts '</div>'
    end

    def emlistnum(lines)
      puts '<div class="code">'
      puts '<pre class="emlist">'
      lines.each_with_index do |line, i|
        puts detab((i+1).to_s.rjust(2) + ": " + line)
      end
      puts '</pre>'
      puts '</div>'
    end

    def cmd(lines)
      puts '<div class="code">'
      puts '<pre class="cmd">'
      lines.each do |line|
        puts detab(line)
      end
      puts '</pre>'
      puts '</div>'
    end

    def quotedlist(lines, css_class)
      puts %Q[<blockquote><pre class="#{css_class}">]
      lines.each do |line|
        puts detab(line)
      end
      puts '</pre></blockquote>'
    end
    private :quotedlist

    def quote(lines)
      puts "<blockquote>#{lines.join("\n")}</blockquote>"
    end

    def image_image(id, metric, caption)
      puts %Q[<div class="image">]
      puts %Q[<img src="#{@chapter.image(id).path.sub(/^\.\//, "")}" alt="(#{escape_html(caption)})" />]
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
      puts %Q[<p class="imagecaption">]
      puts %Q[図#{getChap}#{@chapter.image(id).number}: #{escape_html(caption)}]
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

      begin
        table_header id, caption unless caption.nil?
      rescue KeyError => err
        error "no such table: #{id}"
      end
      table_begin rows.first.size
      return if rows.empty?
      if sepidx
        sepidx.times do
          tr rows.shift.map {|s| th(compile_inline(s)) }
        end
        rows.each do |cols|
          tr cols.map {|s| td(compile_inline(s)) }
        end
      else
        rows.each do |cols|
          h, *cs = *cols
          tr [th(compile_inline(h))] + cs.map {|s| td(compile_inline(s)) }
        end
      end
      table_end
    end

    def table_header(id, caption)
      puts %Q[<p class="tablecaption">表#{getChap}#{@chapter.table(id).number}: #{escape_html(caption)}</p>]
    end

    def table_begin(ncols)
      puts '<table>'
    end

    def tr(rows)
      puts "<tr>#{rows.join('')}</tr>"
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
      puts %Q(<div class="footnote"><p class="footnote"><a name="fn-#{id}">[*#{@chapter.footnote(id).number}] #{escape_html(str)}</a></p></div>)
    end

    def hr
      puts "<hr/>"
    end

    def label(id)
      puts %Q(<a name="#{id}" />)
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

    def flushright(lines)
      puts "<p align='right'>#{lines.join("\n")}</p>"
    end

    def note(lines, caption = nil)
      puts '<div class="note">'
      puts "<p class='notecaption'>#{escape_html(caption)}</p>" unless caption.nil?
      puts "#{lines.join("\n")}</div>"
    end

    def inline_fn(id)
      %Q(<a href="\#fn-#{id}">*#{@chapter.footnote(id).number}</a>)
    end

    def compile_ruby(base, ruby)
      %Q[<ruby><rb>{escape_html(base)}</rb><rp>(</rp><rt>#{ruby}</rt><rp>)</rp></ruby>]
    end

    def compile_kw(word, alt)
      '<span class="kw">' +
        if alt
        #then escape_html(word + sprintf(@locale[:parens], alt.strip))
        then escape_html(word + " (#{alt.strip})")
        else escape_html(word)
        end +
      '</span>'
    end

    def compile_href(url, label)
      %Q(<a href="#{url}" class="link">#{label.nil? ? url : label}</a>)
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

    def inline_dtp(arg)
      # ignore all
      ''
    end

    def inline_code(str)
      %Q(<span class="inline-code">#{str}</span>)
    end

    def text(str)
      str
    end

    def bibpaper_header(id, caption)
      puts %Q(<a name="bib-#{id}">)
      puts "[#{@chapter.bibpaper(id).number}] #{caption}"
      puts %Q(</a>)
    end

    def bibpaper_bibpaper(id, caption, lines)
      puts %Q(<p>)
      lines.each do |line|
        puts detab(line)
      end
      puts %Q(</p>)
    end

    def noindent
      # dummy
    end

    def inline_bib(id)
      %Q(<a href=".#{@book.bib_file.gsub(/re$/, "html")}\#bib-#{id}">[#{@chapter.bibpaper(id).number}]</a>)
    end

    def nofunc_text(str)
      escape_html(str)
    end

    def inline_list(id)
      "リスト#{getChap}#{@chapter.list(id).number}"
    rescue KeyError
      error "unknown list: #{id}"
      nofunc_text("[UnknownList:#{id}]")
    end

    def inline_img(id)
      "図#{getChap}#{@chapter.image(id).number}"
    rescue KeyError
      error "unknown image: #{id}"
      nofunc_text("[UnknownImage:#{id}]")
    end

    def inline_table(id)
      "表#{getChap}#{@chapter.table(id).number}"
    rescue KeyError
      error "unknown table: #{id}"
      nofunc_text("[UnknownTable:#{id}]")
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
      %Q(<span class="u">#{escape_html(str)}</span>)
    end

    def getChap
      if @param["secnolevel"] > 0 && !@chapter.number.nil? && !@chapter.number.to_s.empty?
        return "#{@chapter.number}."
      end
      return ""
    end
  end

end   # module ReVIEW
