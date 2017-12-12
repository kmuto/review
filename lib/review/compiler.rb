# Copyright (c) 2009-2017 Minero Aoki, Kenshi Muto
# Copyright (c) 2002-2007 Minero Aoki
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

require 'review/extentions'
require 'review/preprocessor'
require 'review/exception'
require 'strscan'

module ReVIEW
  class Location
    def initialize(filename, f)
      @filename = filename
      @f = f
    end

    attr_reader :filename

    def lineno
      @f.lineno
    end

    def string
      begin
        "#{@filename}:#{@f.lineno}"
      rescue
        "#{@filename}:nil"
      end
    end

    alias_method :to_s, :string
  end

  class Compiler
    def initialize(strategy)
      @strategy = strategy
    end

    attr_reader :strategy

    def compile(chap)
      @chapter = chap
      do_compile
      @strategy.result
    end

    class SyntaxElement
      def initialize(name, type, argc, &block)
        @name = name
        @type = type
        @argc_spec = argc
        @checker = block
      end

      attr_reader :name

      def check_args(args)
        raise CompileError, "wrong # of parameters (block command //#{@name}, expect #{@argc_spec} but #{args.size})" unless @argc_spec === args.size
        @checker.call(*args) if @checker
      end

      def min_argc
        case @argc_spec
        when Range then @argc_spec.begin
        when Integer then @argc_spec
        else
          raise TypeError, "argc_spec is not Range/Integer: #{inspect}"
        end
      end

      def block_required?
        @type == :block
      end

      def block_allowed?
        @type == :block or @type == :optional
      end
    end

    SYNTAX = {}

    def self.defblock(name, argc, optional = false, &block)
      defsyntax name, (optional ? :optional : :block), argc, &block
    end

    def self.defsingle(name, argc, &block)
      defsyntax name, :line, argc, &block
    end

    def self.defsyntax(name, type, argc, &block)
      SYNTAX[name] = SyntaxElement.new(name, type, argc, &block)
    end

    def self.definline(name)
      INLINE[name] = InlineSyntaxElement.new(name)
    end

    def syntax_defined?(name)
      SYNTAX.key?(name.to_sym)
    end

    def syntax_descriptor(name)
      SYNTAX[name.to_sym]
    end

    class InlineSyntaxElement
      def initialize(name)
        @name = name
      end

      attr_reader :name
    end

    INLINE = {}

    def inline_defined?(name)
      INLINE.key?(name.to_sym)
    end

    defblock :read, 0
    defblock :lead, 0
    defblock :list, 2..3
    defblock :emlist, 0..2
    defblock :cmd, 0..1
    defblock :table, 0..2
    defblock :imgtable, 0..2
    defblock :emtable, 0..1
    defblock :quote, 0
    defblock :image, 2..3, true
    defblock :source, 0..2
    defblock :listnum, 2..3
    defblock :emlistnum, 0..2
    defblock :bibpaper, 2..3, true
    defblock :doorquote, 1
    defblock :talk, 0
    defblock :texequation, 0
    defblock :graph, 1..3
    defblock :indepimage, 1..3, true
    defblock :numberlessimage, 1..3, true

    defblock :address, 0
    defblock :blockquote, 0
    defblock :bpo, 0
    defblock :flushright, 0
    defblock :centering, 0
    defblock :note, 0..1
    defblock :memo, 0..1
    defblock :info, 0..1
    defblock :important, 0..1
    defblock :caution, 0..1
    defblock :notice, 0..1
    defblock :warning, 0..1
    defblock :tip, 0..1
    defblock :box, 0..1
    defblock :comment, 0..1, true
    defblock :embed, 0..1

    defsingle :footnote, 2
    defsingle :noindent, 0
    defsingle :linebreak, 0
    defsingle :pagebreak, 0
    defsingle :hr, 0
    defsingle :parasep, 0
    defsingle :label, 1
    defsingle :raw, 1
    defsingle :tsize, 1
    defsingle :include, 1
    defsingle :olnum, 1
    defsingle :firstlinenum, 1

    definline :chapref
    definline :chap
    definline :title
    definline :img
    definline :imgref
    definline :icon
    definline :list
    definline :table
    definline :fn
    definline :kw
    definline :ruby
    definline :bou
    definline :ami
    definline :b
    definline :dtp
    definline :code
    definline :bib
    definline :hd
    definline :href
    definline :recipe
    definline :column
    definline :tcy

    definline :abbr
    definline :acronym
    definline :cite
    definline :dfn
    definline :em
    definline :kbd
    definline :q
    definline :samp
    definline :strong
    definline :var
    definline :big
    definline :small
    definline :del
    definline :ins
    definline :sup
    definline :sub
    definline :tt
    definline :i
    definline :tti
    definline :ttb
    definline :u
    definline :raw
    definline :br
    definline :m
    definline :uchar
    definline :idx
    definline :hidx
    definline :comment
    definline :include
    definline :tcy
    definline :embed
    definline :pageref

    private

    def do_compile
      f = LineInput.new(StringIO.new(@chapter.content))
      @strategy.bind self, @chapter, Location.new(@chapter.basename, f)
      tagged_section_init
      while f.next?
        case f.peek
        when /\A\#@/
          f.gets # Nothing to do
        when /\A=+[\[\s\{]/
          compile_headline f.gets
        when /\A\s+\*/
          compile_ulist f
        when /\A\s+\d+\./
          compile_olist f
        when /\A\s*:\s/
          compile_dlist f
        when %r{\A//\}}
          f.gets
          error 'block end seen but not opened'
        when %r{\A//[a-z]+}
          name, args, lines = read_command(f)
          syntax = syntax_descriptor(name)
          unless syntax
            error "unknown command: //#{name}"
            compile_unknown_command args, lines
            next
          end
          compile_command syntax, args, lines
        when %r{\A//}
          line = f.gets
          warn "`//' seen but is not valid command: #{line.strip.inspect}"
          if block_open?(line)
            warn 'skipping block...'
            read_block(f, false)
          end
        else
          if f.peek.strip.empty?
            f.gets
            next
          end
          compile_paragraph f
        end
      end
      close_all_tagged_section
    end

    def compile_headline(line)
      @headline_indexs ||= [@chapter.number.to_i - 1]
      m = /\A(=+)(?:\[(.+?)\])?(?:\{(.+?)\})?(.*)/.match(line)
      level = m[1].size
      tag = m[2]
      label = m[3]
      caption = m[4].strip
      index = level - 1
      if tag
        if tag !~ %r{\A/}
          warn 'headline is empty.' if caption.empty?
          close_current_tagged_section(level)
          open_tagged_section(tag, level, label, caption)
        else
          open_tag = tag[1..-1]
          prev_tag_info = @tagged_section.pop
          error "#{open_tag} is not opened." if prev_tag_info.nil? || prev_tag_info.first != open_tag
          close_tagged_section(*prev_tag_info)
        end
      else
        warn 'headline is empty.' if caption.empty?
        @headline_indexs = @headline_indexs[0..index] if @headline_indexs.size > (index + 1)
        @headline_indexs[index] = 0 if @headline_indexs[index].nil?
        @headline_indexs[index] += 1
        close_current_tagged_section(level)
        @strategy.headline level, label, caption
      end
    end

    def close_current_tagged_section(level)
      while @tagged_section.last and @tagged_section.last[1] >= level
        close_tagged_section(* @tagged_section.pop)
      end
    end

    def headline(level, label, caption)
      @strategy.headline level, label, caption
    end

    def tagged_section_init
      @tagged_section = []
    end

    def open_tagged_section(tag, level, label, caption)
      mid = "#{tag}_begin"
      unless @strategy.respond_to?(mid)
        error "strategy does not support tagged section: #{tag}"
        headline level, label, caption
        return
      end
      @tagged_section.push [tag, level]
      @strategy.__send__ mid, level, label, caption
    end

    def close_tagged_section(tag, level)
      mid = "#{tag}_end"
      if @strategy.respond_to?(mid)
        @strategy.__send__ mid, level
      else
        error "strategy does not support block op: #{mid}"
      end
    end

    def close_all_tagged_section
      close_tagged_section(* @tagged_section.pop) until @tagged_section.empty?
    end

    def compile_ulist(f)
      level = 0
      f.while_match(/\A\s+\*|\A\#@/) do |line|
        next if line =~ /\A\#@/

        buf = [text(line.sub(/\*+/, '').strip)]
        f.while_match(/\A\s+(?!\*)\S/) { |cont| buf.push text(cont.strip) }

        line =~ /\A\s+(\*+)/
        current_level = $1.size
        if level == current_level
          @strategy.ul_item_end
          # body
          @strategy.ul_item_begin buf
        elsif level < current_level # down
          level_diff = current_level - level
          level = current_level
          (1..(level_diff - 1)).to_a.reverse_each do |i|
            @strategy.ul_begin { i }
            @strategy.ul_item_begin []
          end
          @strategy.ul_begin { level }
          @strategy.ul_item_begin buf
        elsif level > current_level # up
          level_diff = level - current_level
          level = current_level
          (1..level_diff).to_a.reverse_each do |i|
            @strategy.ul_item_end
            @strategy.ul_end { level + i }
          end
          @strategy.ul_item_end
          # body
          @strategy.ul_item_begin buf
        end
      end

      (1..level).to_a.reverse_each do |i|
        @strategy.ul_item_end
        @strategy.ul_end { i }
      end
    end

    def compile_olist(f)
      @strategy.ol_begin
      f.while_match(/\A\s+\d+\.|\A\#@/) do |line|
        next if line =~ /\A\#@/

        num = line.match(/(\d+)\./)[1]
        buf = [text(line.sub(/\d+\./, '').strip)]
        f.while_match(/\A\s+(?!\d+\.)\S/) { |cont| buf.push text(cont.strip) }
        @strategy.ol_item buf, num
      end
      @strategy.ol_end
    end

    def compile_dlist(f)
      @strategy.dl_begin
      while /\A\s*:/ =~ f.peek
        @strategy.dt text(f.gets.sub(/\A\s*:/, '').strip)
        @strategy.dd(f.break(/\A(\S|\s*:|\s+\d+\.\s|\s+\*\s)/).map { |line| text(line.strip) })
        f.skip_blank_lines
        f.skip_comment_lines
      end
      @strategy.dl_end
    end

    def compile_paragraph(f)
      buf = []
      f.until_match(%r{\A//|\A\#@}) do |line|
        break if line.strip.empty?
        buf.push text(line.sub(/^(\t+)\s*/) { |m| '<!ESCAPETAB!>' * m.size }.strip.gsub('<!ESCAPETAB!>', "\t"))
      end
      @strategy.paragraph buf
    end

    def read_command(f)
      line = f.gets
      name = line.slice(/[a-z]+/).to_sym
      ignore_inline = (name == :embed)
      args = parse_args(line.sub(%r{\A//[a-z]+}, '').rstrip.chomp('{'), name)
      lines = block_open?(line) ? read_block(f, ignore_inline) : nil

      [name, args, lines]
    end

    def block_open?(line)
      line.rstrip[-1, 1] == '{'
    end

    def read_block(f, ignore_inline)
      head = f.lineno
      buf = []
      f.until_match(%r{\A//\}}) do |line|
        if ignore_inline
          buf.push line
        elsif line !~ /\A\#@/
          buf.push text(line.rstrip)
        end
      end
      unless %r{\A//\}} =~ f.peek
        error "unexpected EOF (block begins at: #{head})"
        return buf
      end
      f.gets # discard terminator
      buf
    end

    def parse_args(str, _name = nil)
      return [] if str.empty?
      scanner = StringScanner.new(str)
      words = []
      while word = scanner.scan(/(\[\]|\[.*?[^\\]\])/)
        w2 = word[1..-2].gsub(/\\(.)/) do
          ch = $1
          (ch == ']' or ch == '\\') ? ch : '\\' + ch
        end
        words << w2
      end
      unless scanner.eos?
        error "argument syntax error: #{scanner.rest} in #{str.inspect}"
        return []
      end
      words
    end

    def compile_command(syntax, args, lines)
      unless @strategy.respond_to?(syntax.name)
        error "strategy does not support command: //#{syntax.name}"
        compile_unknown_command args, lines
        return
      end
      begin
        syntax.check_args args
      rescue CompileError => err
        error err.message
        args = ['(NoArgument)'] * syntax.min_argc
      end
      if syntax.block_allowed?
        compile_block syntax, args, lines
      else
        error "block is not allowed for command //#{syntax.name}; ignore" if lines
        compile_single syntax, args
      end
    end

    def compile_unknown_command(args, lines)
      @strategy.unknown_command args, lines
    end

    def compile_block(syntax, args, lines)
      @strategy.__send__(syntax.name, (lines || default_block(syntax)), *args)
    end

    def default_block(syntax)
      error "block is required for //#{syntax.name}; use empty block" if syntax.block_required?
      []
    end

    def compile_single(syntax, args)
      @strategy.__send__(syntax.name, *args)
    end

    def replace_fence(str)
      str.gsub(/@<(\w+)>([$|])(.+?)(\2)/) do
        op = $1
        arg = $3.gsub('@', "\x01").gsub('\\}') { '\\\\}' }.gsub('}') { '\}' }.sub(/(?:\\)+$/) { |m| '\\\\' * m.size }
        "@<#{op}>{#{arg}}"
      end
    end

    def text(str)
      return '' if str.empty?
      words = replace_fence(str).split(/(@<\w+>\{(?:[^\}\\]|\\.)*?\})/, -1)
      words.each { |w| error "`@<xxx>' seen but is not valid inline op: #{w}" if w.scan(/@<\w+>/).size > 1 && !/\A@<raw>/.match(w) }
      result = @strategy.nofunc_text(words.shift)
      until words.empty?
        result << compile_inline(words.shift.gsub(/\\\}/, '}').gsub(/\\\\/, '\\'))
        result << @strategy.nofunc_text(words.shift)
      end
      result.gsub("\x01", '@')
    rescue => err
      error err.message
    end
    public :text # called from strategy

    def compile_inline(str)
      op, arg = /\A@<(\w+)>\{(.*?)\}\z/.match(str).captures
      raise CompileError, "no such inline op: #{op}" unless inline_defined?(op)
      raise "strategy does not support inline op: @<#{op}>" unless @strategy.respond_to?("inline_#{op}")
      @strategy.__send__("inline_#{op}", arg)
    rescue => err
      error err.message
      @strategy.nofunc_text(str)
    end

    def warn(msg)
      @strategy.warn msg
    end

    def error(msg)
      @strategy.error msg
    end
  end
end # module ReVIEW
