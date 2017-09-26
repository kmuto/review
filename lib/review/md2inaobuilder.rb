# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/markdownbuilder'

module ReVIEW
  class MD2INAOBuilder < MARKDOWNBuilder
    def paragraph(lines)
      puts '　' + lines.join
      puts "\n"
    end

    def list_header(id, caption, lang)
      lang ||= ''
      puts "```#{lang}"
      print %Q(●リスト#{@chapter.list(id).number}::#{compile_inline(caption)}\n\n)
    end

    def cmd(lines)
      # WEB+DB では使っていないらしいけど
      puts '!!! cmd'
      lines.each { |line| puts detab(line) }
      puts ''
    end

    def dl_begin
      puts '<dl>'
    end

    def dt(line)
      puts "<dt>#{line}</dt>"
    end

    def dd(lines)
      puts "<dd>#{lines.join}</dd>"
    end

    def dl_end
      puts '</dl>'
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
