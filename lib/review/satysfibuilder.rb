# satysfibuilder.rb
#
# Copyright (c) 2018 Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

require 'review/builder'

module ReVIEW
  class SATYSFIBuilder < Builder
    HEADLINE = {
      1 => 'chapter',
      2 => 'section',
      3 => 'subsection'
    }.freeze

    def pre_paragraph
      '+p{'
    end

    def post_paragraph
      '}'
    end

    def extname
      '.saty'
    end

    def builder_init_file
      @section = 0
      @subsection = 0

      @indent = '  '
    end
    private :builder_init_file

    def escape(str)
      str.gsub('\\', '\\\\\\').
        gsub(';', '\\;').
        gsub('<', '\\<').
        gsub('>', '\\>').
        gsub('{', '\\{').
        gsub('}', '\\}')
    end

    def unescape(str)
      str.gsub('\\;', ';').
        gsub('\\<', '<').
        gsub('\\>', '>').
        gsub('\\{', '{').
        gsub('\\}', '}').
        gsub('\\\\\\', '\\')
    end

    def headline(level, _label, caption)
      case level
      when 2
        puts '      >' if @subsection > 0
        puts '    >' if @section > 0
        @section += 1
        @subsection = 0
      when 3
        puts '      >' if @subsection > 0
        @subsection += 1
      end

      headline_name = HEADLINE[level]
      @indent = level
      puts %Q(#{indents}+#{headline_name}{#{compile_inline(caption)}}<)
      @indent += 1
    end

    def result
      s = ''
      if @subsection > 0
        @indent -= 1
        s += "#{indents}>\n"
      end
      if @section > 0
        @indent -= 1
        s += "#{indents}>\n"
      end
      @indent -= 1
      s += "#{indents}>\n" # chapter
      @output.string + s
    end

    def paragraph(lines)
      puts "#{indents}#{pre_paragraph}"
      @indent += 1
      lines.each do |line|
        puts "#{indents}#{line}"
      end
      @indent -= 1
      puts "#{indents}#{post_paragraph}"
    end

    def inline_b(s)
      "\\emph{#{escape(s)}}"
    end

    def inline_tt(s)
      # needs local.satyh
      "\\file{#{escape(s)}}"
    end
    alias_method :inline_code, :inline_tt

    def footnote(_id, _str)
      # handle by inline_fn
    end

    def inline_fn(id)
      %Q(\\footnote{#{compile_inline(@chapter.footnote(id).content.strip)}})
    end

    def inline_img(id)
      _chapter, id = extract_chapter_id(id)
      %Q(\\ref(\`fig:#{escape(id)}\`);)
    end

    def image_image(id, caption, metric)
      puts <<EOT
#{indents}+p{
#{indents}  \\figure ?:(`fig:#{escape(id)}`){#{compile_inline(caption)}}<
#{indents}    +image-frame{\\insert-image(#{metric})(`#{@chapter.image(id).path}`);}
#{indents}  >
#{indents}}
EOT
    end

    def indents
      '  ' * @indent
    end

    def nofunc_text(str)
      escape(str)
    end
  end
end
