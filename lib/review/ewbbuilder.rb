# $Id: ewbbuilder.rb 2195 2005-11-13 21:52:18Z aamine $

require 'review/builder'
require 'review/textutils'
require 'review/exception'

module ReVIEW

  class EWBBuilder < Builder

    include TextUtils

    def initialize(chap)
      super
      @footnote_buf = []
      @index_buffer = []
    end

    def generate_index
      @index_buffer.each_with_index do |str, n|
        printf "%d\t%s\n", index_number(n + 1), str
      end
    end

    def headline(level, caption)
      puts unless level == 1
      puts "//#{'i' * level} #{caption}"
      puts
    end

    Compiler.defsyntax(:emlist, :block, 0..1) {|args|
      if args[0] and not args[0] == 'noescape'
        raise SyntaxError, "unknown //emlist option: #{args[0]}"
      end
    }

    def emlist(lines, noescape = false)
      firstline = f.lineno
      puts
      puts '//lst1{'
      lines.each do |line|
        if noescape
          puts detab(line)
        else
          puts escape(detab(line))
        end
      end
      puts '//}'
      puts
    end

    Compiler.defsyntax(:cmd, :block, 0..1) {|args|
      if args[0] and not args[0] == 'noescape'
        raise SyntaxError, "unknown //cmd option: #{args[0]}"
      end
    }

    def cmd(lines, noescape = false)
      puts
      puts '//sc1{'
      lines.each do |line|
        if noescape
          puts detab(line)
        elsif /\AC:.*?>(.+)/ =~ line   # DOS prompt hack
          prompt, cmd = *line.split('>', 2)
          puts "#{escape(prompt)}>//command{#{escape(cmd)}}//}"
        else
          puts escape(detab(line))
        end
      end
      puts '//}'
      puts
    end

    Compiler.defsyntax(:list, :block, 0..1) {|args|
      if args[0] and not args[0] == 'noescape'
        raise SyntaxError, "unknown //list option: #{args[0]}"
      end
    }

    def list(lines, noescape = false)
      puts
      puts "//l#{list_number(ident)} " + caption
      puts '//lst2{'
      lines.each do |line|
        puts escape(detab(line))
      end
      puts '//}'
      puts
    end

    def image_header(file, caption)
      if /\.png\z/ =~ file and not FileTest.exist?('images/' + file)
        warn "image file not exist: #{file}"
      end
      id = file.sub(/\.\w+\z/, '')
      puts "//f#{figure_number(id)} #{text(caption)} file=#{file}" if id
    end

    def image_dummy
      puts '//lst1{'
      puts '---- dummy figure ----'
      print dummy
      puts '//}'
      puts
    end

    def table
      # %r<\A//table\[(\w+)\]>
      spec = $1
      buf = []
      while line = f.gets
        break if %r[\A//\}] === line
        buf.push line.strip.split(/\t+/).map {|s| s == '.' ? '' : s }
      end
      table_type = 'tabm'
      output.puts "//#{table_type}[" + spec + ']{'
      buf.each_with_index do |col, idx|
        if /----/ === col[0]
          output.puts '//kb'
        else
          output.puts col.map {|s| text(s) }.join("\t")
        end
      end
      output.puts '//}'
    end

    LI = '¡ü'

    def ul_begin
      puts
      puts '//k1{'
    end

    def ul_item(lines)
      puts "#{LI}//|" + lines.join('')
    end

    def ul_end
      puts '//}'
    end

    def ol_begin
      output.puts
      output.puts '//k2{'
    end

    def ol_item(num, lines)
      print "#{num}//|' + lines.join('')
    end

    def ol_end
      puts '//}'
    end

    def quote(lines)
      puts '//c1{'
      lines.each do |line|
        puts text(line)
      end
      puts '//}'
    end

    def vspace
      print "\n//h"
    end

    def noindent
      @noindent = true
    end

    def refer(f)
      puts
      puts '//refer{'
      cascade f
      puts '//}'
    end

    def point(f)
      puts
      puts '//point{'
      cascade f
      puts '//}'
    end

    def note(f, caption)
      puts
      puts '//note{'
      puts "//cg{#{caption}//}"
      puts '//h'
      cascade f
      puts '//}'
    end

    def cascade(f)
      # FIXME
    end

    Z_SPACE = "\241\241"   # zen-kaku space in EUC-JP

    def paragraph(lines)
      if @noindent
        @noindent = false
      else
        print Z_SPACE
      end
      prev = ''
      lines.each do |line|
        if /[a-zA-Z0-9]\z/ =~ prev and /\A[a-zA-Z0-9]/ =~ line
          print ' '
        end
        print line
      end
      puts
    end

    def figure_filename(key)
      if ext = key.slice(/\.\w+\z/)
        base = key.sub(/\.\w+\z/, '')
      else
        base = key
        ext = '.eps'
      end
      currname = "images/ch_#{chapter_id()}_#{base}#{ext}"
      destname = "images/fig#{figure_number(base)}#{ext}"
      unless File.exist? currname
        # error "image file not exist: #{currname}"
      end
      destname
    end

    def image_label(str)
      "#{chapter_id()}:#{str}"
    end

    def text(str)
      str = str.gsub(/\t/, ' ')
      str.gsub(/([^@^]+)|\^(.*?)\^|@<(\w+)>\{(.*?)\}|@\{(.*?)\}|([@^])/) {
        if normal = $1
          escape(normal)
        elsif tt = $2
          '//tt{' + escape(tt) + '//}'
        elsif inline = $3
          compile_inline(inline, $4)
        elsif index = $5
          error 'index not implemented'
          text(index) + index_command(index)
        elsif char = $6
          escape(char)
        else
          error "unknown inline: #{str.inspect}"
        end
      }
    rescue DocumentError => e
      error e.message
      return 'ERROR'
    end

    def inline_kw(arg)
      word, eng, abbr = arg.split(/,/).map {|s| s.strip }
      if abbr
        add_index(word) + "//g{#{word}//}" +
        add_index(abbr) + "¡Ê#{abbr}, " +
        add_index(eng)  + "#{eng}¡Ë"
      elsif eng
        add_index(word) + "//g{#{word}//}" +
        add_index(eng)  + "¡Ê#{eng}¡Ë"
      else
        add_index(word) + "//g{#{word}//}"
      end
    end

    def inline_keytop(arg)
      "//keytop{#{arg}//}"
    end

    def inline_chap(id)
      chapter_number(arg)
    end

    def inline_chapref(id)
      chapter_number(arg) + chapter_name(arg)
    end

    def inline_chapname(id)
      chapter_name(arg)
    end

    def inline_list(arg)
      '//l' + list_number(arg)
    end

    def inline_img(arg)
      error "wrong image label: #{arg}" if /[^a-zA-Z\d\-]/ =~ arg
      '//f' + figure_number(arg)
    end

    def inline_footnote(id)
      '//ky' + footnote_number(id)
    end

    def inline_ruby(arg)
      error 'wrong number of arg: @<ruby>' unless arg.count(',') == 1
      "//ruby{#{arg}//}"
    end

    NAKAGURO = '¡¦'

    def inline_bou(str)
      "//ruby{#{escape(str)},#{NAKAGURO * char_length(str)}//}"
    end

    def char_length(str)
      str.gsub(/./, '.').length
    end

    def inline_em(str)
      "//g{#{arg}//}"
    end

    def inline_math(arg)
      "//LaTeX{ $#{arg}$ //}"
    end


    def chapter_id
      File.basename(@filename, '.rd')
    end

    def chapter_prefix
      sprintf('%02d', @chapter_table.number(chapter_id()))
    end

    def chapter_number( key )
      curr = @chapter_table.number(chapter_id())
      dest = @chapter_table.number(key)

      case chapter_id()
      when /\.ewb\z/, 'tmp', 'temp'
        return 'Âè' + dest + '¾Ï'
      end
      if dest == curr + 1
        '¼¡¾Ï'
      elsif dest == curr - 1
        'Á°¾Ï'
      else
        "Âè#{dest}¾Ï"
      end
    end

    def chapter_name(key)
      '¡Ø' + text(@chapter_table.title(key)) + '¡Ù'
    end

    def list_number(key)
      sprintf(chapter_prefix() + '%02d0', @list_table.number(key))
    end

    def figure_number(key)
      sprintf(chapter_prefix() + '%02d0', @figure_table.number(key))
    end

    def footnote_number(key)
      sprintf('%02d', @footnote_index.number(key) * 5)
    end

    def add_index(str)
      @index_buffer.push str
      "//in#{index_number(@index_buffer.size)}"
    end

    def index_number(n)
      900000 + @chapter_index.number(chapter_id()) * 1000 + n
    end

    def escape(str)
      str.gsub(%r<//>, '////')
    end

  end

end
