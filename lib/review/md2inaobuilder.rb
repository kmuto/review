# -*- coding: utf-8 -*-
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/markdownbuilder'

module ReVIEW

  class MD2INAOBuilder < MARKDOWNBuilder
    def paragraph(lines)
      ## XXX fix; do not use fullwidth space
      buf = "　" + lines.join << "\n"
      blank_reset
      buf << "\n"
      buf
    end

    def list_header(id, caption, lang)
      lang ||= ""
      buf = "```#{lang}\n"
      buf << %Q[●リスト#{@chapter.list(id).number}::#{compile_inline(caption)}\n\n]
      buf
    end

    def cmd(lines)
      # WEB+DB では使っていないらしいけど
      buf = "!!! cmd\n"
      lines.each do |line|
        buf << detab(line) + "\n"
      end
      buf << "\n"
      buf
    end

    def dl_begin
      "<dl>\n"
    end

    def dt(line)
      "<dt>#{line}</dt>\n"
    end

    def dd(lines)
      "<dd>#{lines.join}</dd>\n"
    end

    def dl_end
      "</dl>\n"
    end

    def comment(lines, comment = nil)
      lines ||= []
      lines.unshift comment unless comment.blank?
      str = lines.join("\n")
      buf = '<span class="red">' + "\n"
      buf << str + "\n"
      buf << '</span>' + "\n"
      buf
    end

    def compile_ruby(base, ruby)
      if base.length == 1
        %Q[<span class='monoruby'>#{escape_html(base)}(#{escape_html(ruby)})</span>]
      else
        %Q[<span class='groupruby'>#{escape_html(base)}(#{escape_html(ruby)})</span>]
      end
    end

  end

end # module ReVIEW
