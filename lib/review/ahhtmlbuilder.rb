# encoding: utf-8
#
# Copyright (c) 2013 Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#
# Alternate XHTML Builder for Antenna House CSS Formatter (experimental)

require 'review/htmlbuilder'

module ReVIEW
  class AHHTMLBuilder < HTMLBuilder

    def raw(str)
      if matched = str.match(/\|(.*?)\|(.*)/)
        builders = matched[1].split(/,/).map{|i| i.gsub(/\s/, '') }
        if builders.include?("ahhtml") || builders.include?("html")
          print matched[2].gsub("\\n", "\n")
        else
          ""
        end
      else
        print str.gsub("\\n", "\n")
      end
    end

    def headline(level, label, caption)
      prefix, anchor = headline_prefix(level)
      puts '' if level > 1
      a_id = ""
      if !anchor.nil? && !anchor.empty?
        if @chapter.on_PREDEF?
          anchor = "pre#{anchor}"
        elsif @chapter.on_POSTDEF?
          anchor = "post#{anchor}"
        end
        a_id = %Q[<a id="h#{anchor}"></a>]
      end
      if caption.empty?
        puts a_id unless label.nil?
      else
        if label.nil?
          puts %Q[<h#{level} class="realheader" title="#{prefix}#{strip_html(compile_inline(caption))}">#{a_id}#{prefix}#{compile_inline(caption)}</h#{level}>]
        else
          puts %Q[<h#{level} id="#{label}" class="realheader" title="#{prefix}#{strip_html(compile_inline(caption))}">#{a_id}#{prefix}#{compile_inline(caption)}</h#{level}>]
        end
      end
    end

    def column_begin(level, label, caption)
      puts %Q[<div class="column">]

      @column += 1
      puts '' if level > 1
      a_id = %Q[<a id="column-#{@chapter.number}-#{@column}"></a>]

      if caption.empty?
        puts a_id unless label.nil?
      else
        if label.nil?
          puts %Q[<h#{level} class="realheader">#{a_id}#{compile_inline(caption)}</h#{level}>]
        else
          puts %Q[<h#{level} id="#{label}" class="realheader">#{a_id}#{compile_inline(caption)}</h#{level}>]
        end
      end
#      headline(level, label, caption)
    end

     def inline_fn(id)
       %Q[<div class="footnote"><p class="footnote">#{compile_inline(@chapter.footnote(id).content.strip)}</p></div>]
     end
     
     def footnote(id, str)
     end

    def list_header(id, caption)
      if get_chap.nil?
        puts %Q[<p class="caption">#{I18n.t("list")}#{I18n.t("format_number_header_without_chapter", [@chapter.list(id).number])}#{I18n.t("caption_prefix")}<span class="splitter" />#{compile_inline(caption)}</p>]
      else
        puts %Q[<p class="caption">#{I18n.t("list")}#{I18n.t("format_number_header", [get_chap, @chapter.list(id).number])}#{I18n.t("caption_prefix")}<span class="splitter" />#{compile_inline(caption)}</p>]
      end
    end

    def image_header(id, caption)
      puts %Q[<p class="caption">]
      if get_chap.nil?
        puts %Q[#{I18n.t("image")}#{I18n.t("format_number_header_without_chapter", [@chapter.image(id).number])}#{I18n.t("caption_prefix")}<span class="splitter" />#{compile_inline(caption)}]
      else
        puts %Q[#{I18n.t("image")}#{I18n.t("format_number_header", [get_chap, @chapter.image(id).number])}#{I18n.t("caption_prefix")}<span class="splitter" />#{compile_inline(caption)}]
      end
      puts %Q[</p>]
    end

    def table_header(id, caption)
      if get_chap.nil?
        puts %Q[<p class="caption">#{I18n.t("table")}#{I18n.t("format_number_header_without_chapter", [@chapter.table(id).number])}#{I18n.t("caption_prefix")}<span class="splitter" />#{compile_inline(caption)}</p>]
      else
        puts %Q[<p class="caption">#{I18n.t("table")}#{I18n.t("format_number_header", [get_chap, @chapter.table(id).number])}#{I18n.t("caption_prefix")}<span class="splitter" />#{compile_inline(caption)}</p>]
      end
    end

    def image_image(id, caption, metric)
      metrics = parse_metric("html", metric)
      puts %Q[<div class="image">]
      puts %Q[<div class="imgbox"><img src="#{@chapter.image(id).path.sub(/\A\.\//, "")}" alt="#{escape_html(compile_inline(caption))}"#{metrics} /></div>]
      image_header id, caption
      puts %Q[</div>]
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
        puts "<thead>"
        sepidx.times do
          tr rows.shift.map {|s| th(s) }
        end
        puts "</thead>"
        puts "<tbody>"
        rows.each do |cols|
          tr cols.map {|s| td(s) }
        end
        puts "</tbody>"
      else
        puts "<tbody>"
        rows.each do |cols|
          h, *cs = *cols
          tr [th(h)] + cs.map {|s| td(s) }
        end
        puts "</tbody>"
      end
      table_end
      puts %Q[</div>]
    end

  end
end
