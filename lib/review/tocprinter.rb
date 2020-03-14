# Copyright (c) 2008-2017 Minero Aoki, Kenshi Muto
#               2002-2007 Minero Aoki
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of LGPL, see the file "COPYING".
#

require 'review/htmlutils'
require 'review/tocparser'

module ReVIEW
  class TOCPrinter
    def self.default_upper_level
      99 # no one use 99 level nest
    end

    def initialize(print_upper, param, out = $stdout)
      @print_upper = print_upper
      @config = param
      @out = out
    end

    def print_book(book)
      book.each_part { |part| print_part(part) }
    end

    def print_part(part)
      part.each_chapter { |chap| print_chapter(chap) }
    end

    def print_chapter(chap)
      chap_node = TOCParser.chapter_node(chap)
      print_node(1, chap_node)
      print_children(chap_node)
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
          print_node(idx + 1, section)
          print_children(section)
        end
      end
    end

    def print_node(number, node)
      if node.chapter?
        vol = node.volume
        @out.printf("%3s %3dKB %6dC %5dL  %s (%s)\n",
                    chapnumstr(node.number),
                    vol.kbytes, vol.chars, vol.lines,
                    node.label, node.chapter_id)
      else ## for section node
        @out.printf("%17s %5dL  %s\n",
                    '', node.estimated_lines,
                    "  #{'   ' * (node.level - 1)}#{number} #{node.label}")
      end
    end

    def chapnumstr(n)
      n ? sprintf('%2d.', n) : '   '
    end

    def volume_columns(level, volstr)
      cols = ['', '', '', nil]
      cols[level - 1] = volstr
      cols[0, 3] # does not display volume of level-4 section
    end
  end
end
