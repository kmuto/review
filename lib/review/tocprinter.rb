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

require 'review/htmlutils'
require 'review/htmllayout'

module ReVIEW

  class TOCPrinter

    def TOCPrinter.default_upper_level
      99 # no one use 99 level nest
    end

    def initialize(print_upper, param)
      @print_upper = print_upper
      @config = param
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
        printf "%3s %3dKB %6dC %5dL  %s (%s)\n",
               chapnumstr(node.number),
               vol.kbytes, vol.chars, vol.lines,
               node.label, node.chapter_id
      else ## for section node
        printf "%17s %5dL  %s\n",
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

    def print_part(part)
      puts h1(part.name) if part.name
      super
    end

    def print_chapter(chap)
      chap_node = TOCParser.chapter_node(chap)
      if chap_node.number
        name = "chap#{chap_node.number}"
        label = "第#{chap_node.number}章 #{chap_node.label}"
        puts h2(a_name(escape_html(name), escape_html(label)))
      else
        label = "#{chap_node.label}"
        puts h2(escape_html(label))
      end
      return unless print?(2)
      if print?(3)
        puts chap_sections_to_s(chap_node)
      else
        puts chapter_to_s(chap_node)
      end
    end

    private

    def chap_sections_to_s(chap)
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
        res << h3(escape_html(sec.label))
        next unless print?(4)
        next if sec.section_size == 0
        res << "<ul>"
        sec.each_section do |node|
          res << li(escape_html(node.label))
        end
        res << "</ul>"
      end
      return res.join("\n")
    end

    def h1(label)
      "<h1>#{label}</h1>"
    end

    def h2(label)
      "<h2>#{label}</h2>"
    end

    def h3(label)
      "<h3>#{label}</h3>"
    end

    def li(content)
      "<li>#{content}</li>"
    end

    def a_name(name, label)
      %Q(<a name="#{name}">#{label}</a>)
    end

  end

  class IDGTOCPrinter < TOCPrinter

    LABEL_LEN = 54

    def print_book(book)
      puts %Q(<?xml version="1.0" encoding="UTF-8"?>)
      puts %Q(<doc xmlns:aid='http://ns.adobe.com/AdobeInDesign/4.0/'>)
      puts %Q(<title aid:pstyle="h0">1　パート1</title><?dtp level="0" section="第1部　パート1"?>) # FIXME: 部タイトルを取るには？ & 部ごとに結果を分けるには？
      puts %Q(<ul aid:pstyle='ul-partblock'>)
      super
      puts %Q(</ul></doc>)
    end

    private

    def print_children(node)
      return unless print?(node.level + 1)
      node.each_section_with_index do |sec, idx|
        print_node idx+1, sec
        print_children sec
      end
    end

    def print_node(seq, node)
      if node.chapter?
        printf "<li aid:pstyle='ul-part'>%s</li>\n",
               "#{chapnumstr(node.number)}#{node.label}"
      else
        printf "<li>%-#{LABEL_LEN}s\n",
               "  #{'   ' * (node.level - 1)}#{seq}　#{node.label}</li>"
      end
    end

    def chapnumstr(n)
      n ? sprintf('第%d章　', n) : ''
    end

    def volume_columns(level, volstr)
      cols = ["", "", "", nil]
      cols[level - 1] = volstr
      cols[0, 3]
    end
  end
end
