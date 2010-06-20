# $Id: htmlbuilder.rb 4268 2009-05-27 04:17:08Z kmuto $
#
# Copyright (c) 2002-2007 Minero Aoki
#               2008-2009 Minero Aoki, Kenshi Muto
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

    def extname
      '.html'
    end

    def builder_init(no_error = false)
      @no_error = no_error
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
        messages() + @output.string
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

    def headline(level, label, caption)
      puts '' if level > 1
      if label.nil?
        puts "<h#{level}>#{escape_html(caption)}</h#{level}>"
      else
        puts "<h#{level} id='#{label}'>#{escape_html(caption)}</h#{level}>"
      end
    end

    def column_begin(level, label, caption)
      puts "<div class='column'>"
      headline(level, label, caption)   # FIXME
    end

    def column_end(level)
      puts '</div>'
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
      puts "<p>#{lines.join("")}</p>"
    end

    def parasep()
      puts '<br />'
    end

    def read(lines)
      puts %Q[<p class="lead">\n#{lines.join("\n")}\n</p>]
    end

    def lead(lines)
      read(lines)
    end

    def list_header(id, caption)
      puts %Q[<p class="toplabel">リスト#{@chapter.list(id).number}: #{escape_html(caption)}</p>]
    end

    def list_body(lines)
      puts '<div class="caption-code">'
      puts '<pre class="list">'
      lines.each do |line|
        puts detab(line)
      end
      puts '</pre>'
      puts '</div>'
    end

    def source_header(caption)
      puts %Q[<p class="toplabel">▼#{escape_html(caption)}</p>]
    end

    def source_body(lines)
      puts '<div class="caption-code">'
      puts '<pre class="source">'
      lines.each do |line|
        puts detab(line)
      end
      puts '</pre>'
      puts '</div>'
    end

    def listnum_body(lines)
      puts '<div class="code">'
      puts '<pre class="list">'
      lines.each_with_index do |line, i|
        puts detab((i+1).to_s.rjust(2) + ": " + line)
      end
      puts '</pre>'
      puts '</div>'
     end

    def emlist(lines)
      puts '<div class="code">'
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
      puts %Q[<p class="image">]
      puts %Q[<img src="#{@chapter.image(id).path}" alt="(#{escape_html(caption)})">]
      puts %Q[</p>]
      image_header id, caption
    end

    def image_dummy(id, caption, lines)
      puts %Q[<pre class="dummyimage">]
      lines.each do |line|
        puts detab(line)
      end
      puts %Q[</pre>]
      image_header id, caption
    end

    def image_header(id, caption)
      puts %Q[<p class="botlabel">]
      puts %Q[図#{@chapter.image(id).number}: #{escape_html(caption)}]
      puts %Q[</p>]
    end

    def table_header(id, caption)
      puts %Q[<p class="toplabel">表#{@chapter.table(id).number}: #{escape_html(caption)}</p>]
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
      puts %Q(<p class="comment">[Comment] #{escape_html(str)}</p>)
    end

    def footnote(id, str)
      puts %Q(<p class="comment"><a name="fn-#{id}">#{escape_html(str)}</a></p>)
    end

    def inline_fn(id)
      %Q(<a href="\#fn-#{id}">*#{@chapter.footnote(id).number}</a>)
    end

    def compile_ruby(base, ruby)
      escape_html(base)   # tmp
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

    def inline_i(str)
      %Q(<i>#{escape_html(str)}</i>)
    end

    def inline_b(str)
      %Q(<b>#{escape_html(str)}</b>)
    end

    def inline_ami(str)
      escape_html(str)   # tmp
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

    def inline_bib(id)
      %Q(<a href=".#{@book.bib_file.gsub(/re$/, "html")}\#bib-#{id}">[#{@chapter.bibpaper(id).number}]</a>)
    end

    def inline_raw(str)
      escape_html(str)
    end

    def nofunc_text(str)
      escape_html(str)
    end

  end

end   # module ReVIEW
