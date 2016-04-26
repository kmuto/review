# -*- coding: utf-8 -*-
#
# $Id: tocprinter.rb 4309 2009-07-19 04:15:02Z aamine $
#
# Copyright (c) 2002-2007 Minero Aoki
#               2008-2009 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of LGPL, see the file "COPYING".
#

require 'review/tocprinter'
require 'review/htmlutils'

module ReVIEW

  class TOCPrinter

    def TOCPrinter.default_upper_level
      99 # no one use 99 level nest
    end

    def initialize(print_upper, param, out = $stdout)
      @print_upper = print_upper
      @config = param
      @out = out
    end

    def print_book(book)
      book.each_part do |part|
        print_part(part)
      end
    end

    def print_part(part)
      part.each_chapter do |chap|
        print_chapter(chap)
      end
    end

    def print_chapter(chap)
      chap_node = TOCParser.chapter_node(chap)
      print_node 1, chap_node
      print_children chap_node
    end

    def print?(level)
      level <= @print_upper
    end
  end


  class TextTOCPrinter < TOCPrinter

    private

    def print_children(node)
      return unless print?(node.level + 1)
      node.each_section_with_index do |section, idx|
        unless section.blank?
          print_node idx+1, section
          print_children section
        end
      end
    end

    def print_node(number, node)
      if node.chapter?
        vol = node.volume
        @out.printf "%3s %3dKB %6dC %5dL  %s (%s)\n",
               chapnumstr(node.number),
               vol.kbytes, vol.chars, vol.lines,
               node.label, node.chapter_id
      else ## for section node
        @out.printf "%17s %5dL  %s\n",
               '', node.estimated_lines,
               "  #{'   ' * (node.level - 1)}#{number} #{node.label}"
      end
    end

    def chapnumstr(n)
      n ? sprintf('%2d.', n) : '   '
    end

    def volume_columns(level, volstr)
      cols = ["", "", "", nil]
      cols[level - 1] = volstr
      cols[0, 3] # does not display volume of level-4 section
    end

  end


  class HTMLTOCPrinter < TOCPrinter

    include HTMLUtils

    def print_book(book)
      @out.puts '<ul class="book-toc">'
      book.each_part do |part|
        print_part(part)
      end
      @out.puts '</ul>'
    end

    def print_part(part)
      if part.number
        @out.puts li(part.title)
      end
      super
    end

    def print_chapter(chap)
      chap_node = TOCParser.chapter_node(chap)
      ext = chap.book.config["htmlext"] || "html"
      path = chap.path.sub(/\.re/, "."+ext)
      if chap_node.number && chap.on_CHAPS?
        label = "#{chap.number} #{chap.title}"
      else
        label = chap.title
      end
      @out.puts li(a_name(path, escape_html(label)))
      return unless print?(2)
      if print?(3)
        @out.puts chap_sections_to_s(chap_node)
      else
        @out.puts chapter_to_s(chap_node)
      end
    end

    private

    def chap_sections_to_s(chap)
      return "" if chap.section_size < 1
      res = []
      res << "<ol>"
      chap.each_section do |sec|
        res << li(escape_html(sec.label))
      end
      res << "</ol>"
      return res.join("\n")
    end

    def chapter_to_s(chap)
      res = []
      chap.each_section do |sec|
        res << li(escape_html(sec.label))
        next unless print?(4)
        if sec.section_size > 0
          res << "<ul>"
          sec.each_section do |node|
            res << li(escape_html(node.label))
          end
          res << "</ul>"
        end
      end
      return res.join("\n")
    end

    def li(content)
      "<li>#{content}</li>"
    end

    def a_name(name, label)
      %Q(<a name="#{name}">#{label}</a>)
    end

  end

end
