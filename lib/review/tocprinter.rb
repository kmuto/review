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
require 'nkf'

module ReVIEW

  class TOCPrinter

    def TOCPrinter.default_upper_level
      99   # no one use 99 level nest
    end

    def initialize(print_upper, param)
      @print_upper = print_upper
      @param = param
    end

    def print?(level)
      level <= @print_upper
    end

    def nkffilter(line)
      inc = ""
      outc = "-w"
      if @param["inencoding"] =~ /^EUC$/
        inc = "-E"
      elsif @param["inencoding"] =~ /^SJIS$/
        inc = "-S"
      elsif @param["inencoding"]  =~ /^JIS$/
        inc = "-J"
      end
      
      if @param["outencoding"] =~ /^EUC$/
        outc = "-e"
      elsif @param["outencoding"] =~ /^SJIS$/
        outc = "-s"
      elsif @param["outencoding"]  =~ /^JIS$/
        outc = "-j"
      end
      
      NKF.nkf("#{inc} #{outc}", line)
    end
  end


  class TextTOCPrinter < TOCPrinter
    def print_book(book)
      print_children book
    end

    private

    def print_children(node)
      return unless print?(node.level + 1)
      node.each_section_with_index do |section, idx|
        print_node idx+1, section
        print_children section
      end
    end

    def print_node(number, node)
      if node.chapter?
        vol = node.volume
        printf "%3s %3dKB %6dC %5dL  %s (%s)\n",
               chapnumstr(node.number),
               vol.kbytes, vol.chars, vol.lines,
               nkffilter(node.label), node.chapter_id
      else
        printf "%17s %5dL  %s\n",
               '', node.estimated_lines,
               nkffilter("  #{'   ' * (node.level - 1)}#{number} #{node.label}")
      end
    end

    def chapnumstr(n)
      n ? sprintf('%2d.', n) : '   '
    end

    def volume_columns(level, volstr)
      cols = ["", "", "", nil]
      cols[level - 1] = volstr
      cols[0, 3]   # does not display volume of level-4 section
    end

  end


  class HTMLTOCPrinter < TOCPrinter

    include HTMLUtils

    def print_book(book)
      return unless print?(1)
      html = ""
      book.each_part do |part|
        html << h1(part.name) if part.name
        part.each_section do |chap|
          if chap.number
            name = "chap#{chap.number}"
            label = "第#{chap.number}章 #{chap.label}"
            html << h2(a_name(escape_html(name), escape_html(label)))
          else
            label = "#{chap.label}"
            html << h2(escape_html(label))
          end
          return unless print?(2)
          if print?(3)
            html << chap_sections_to_s(chap)
          else
            html << chapter_to_s(chap)
          end
        end
      end
      puts HTMLLayout.new(html, "目次", File.join(book.basedir, "layouts", "layout.erb")).result
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

    def print_chapter_to_s(chap)
      res = []
      chap.each_section do |sec|
        res << h3(escape_html(sec.label))
        next unless print?(4)
        next if sec.n_sections == 0
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
    def print_book(book)
      puts %Q(<?xml version="1.0" encoding="UTF-8"?>)
      puts nkffilter(%Q(<doc xmlns:aid='http://ns.adobe.com/AdobeInDesign/4.0/'><title aid:pstyle="h0">1　パート1</title><?dtp level="0" section="第1部　パート1"?>)) # FIXME: 部タイトルを取るには？ & 部ごとに結果を分けるには？
      puts %Q(<ul aid:pstyle='ul-partblock'>)
      print_children book
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

    LABEL_LEN = 54

    def print_node(seq, node)
      if node.chapter?
        vol = node.volume
        printf "<li aid:pstyle='ul-part'>%s</li>\n",
               nkffilter("#{chapnumstr(node.number)}#{node.label}")
      else
        printf "<li>%-#{LABEL_LEN}s\n",
               nkffilter("  #{'   ' * (node.level - 1)}#{seq}　#{node.label}</li>")
      end
    end

    def chapnumstr(n)
      n ? nkffilter(sprintf('第%d章　', n)) : ''
    end

    def volume_columns(level, volstr)
      cols = ["", "", "", nil]
      cols[level - 1] = volstr
      cols[0, 3]
    end
  end
end
