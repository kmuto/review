# frozen_string_literal: true

# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/markdownbuilder'

module ReVIEW
  class MD2INAOBuilder < MARKDOWNBuilder
    def paragraph(lines)
      puts '　' + join_lines_to_paragraph(lines)
      puts "\n"
    end

    def list_header(id, caption, _lang)
      print %Q(●リスト#{@chapter.list(id).number}::#{compile_inline(caption)}\n\n)
    end

    def cmd(lines)
      # WEB+DB では使っていないらしいけど
      puts '!!! cmd'
      lines.each do |line|
        puts detab(line)
      end
      puts ''
    end

    def dl_begin
      puts '<dl>'
    end

    def dt(line)
      puts "<dt>#{line}</dt>"
    end

    def dd(lines)
      puts "<dd>#{join_lines_to_paragraph(lines)}</dd>"
    end

    def dl_end
      puts '</dl>'
    end

    def compile_ruby(base, ruby)
      if base.length == 1
        %Q[<span class='monoruby'>#{escape(base)}(#{escape(ruby)})</span>]
      else
        %Q[<span class='groupruby'>#{escape(base)}(#{escape(ruby)})</span>]
      end
    end
  end
end # module ReVIEW
