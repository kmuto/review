# Copyright (c) 2009-2020 Minero Aoki, Kenshi Muto
# Copyright (c) 2002-2007 Minero Aoki
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

require 'review/extentions'
require 'review/preprocessor'
require 'review/exception'
require 'review/location'
require 'strscan'

module ReVIEW
  class Compiler
    def initialize(builder)
      @builder = builder

      ## commands which do not parse block lines in compiler
      @non_parsed_commands = %i[embed texequation graph]

      ## to decide escaping/non-escaping for text
      @command_name_stack = []
    end

    attr_reader :builder, :previous_list_type

    def strategy
      error 'Compiler#strategy is obsoleted. Use Compiler#builder.'
      @builder
    end

    def non_escaped_commands
      if @builder.highlight?
        %i[list emlist listnum emlistnum cmd]
      else
        []
      end
    end

    def compile(chap)
      @chapter = chap
      do_compile
      @builder.result
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
        unless @argc_spec === args.size
          raise CompileError, "wrong # of parameters (block command //#{@name}, expect #{@argc_spec} but #{args.size})"
        end
        if @checker
          @checker.call(*args)
        end
      end

      def min_argc
        case @argc_spec
        when Range then @argc_spec.begin
        when Integer then @argc_spec
        else
          raise TypeError, "argc_spec is not Range/Integer: #{inspect}"
        end
      end

      def minicolumn?
        @type == :minicolumn
      end

      def block_required?
        @type == :block or @type == :minicolumn
      end

      def block_allowed?
        @type == :block or @type == :optional or @type == :minicolumn
      end
    end

    SYNTAX = {}

    def self.defblock(name, argc, optional = false, &block)
      defsyntax(name, (optional ? :optional : :block), argc, &block)
    end

    def self.defminicolumn(name, argc, _optional = false, &block)
      defsyntax(name, :minicolumn, argc, &block)
    end

    def self.defsingle(name, argc, &block)
      defsyntax(name, :line, argc, &block)
    end

    def self.defsyntax(name, type, argc, &block)
      SYNTAX[name] = SyntaxElement.new(name, type, argc, &block)
    end

    def self.definline(name)
      INLINE[name] = InlineSyntaxElement.new(name)
    end

    def self.minicolumn_names
      buf = []
      SYNTAX.each do |name, syntax|
        if syntax.minicolumn?
          buf << name.to_s
        end
      end
      buf
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
    defblock :imgtable, 0..3
    defblock :emtable, 0..1
    defblock :quote, 0
    defblock :image, 2..3, true
    defblock :source, 0..2
    defblock :listnum, 2..3
    defblock :emlistnum, 0..2
    defblock :bibpaper, 2..3, true
    defblock :doorquote, 1
    defblock :talk, 0
    defblock :texequation, 0..2
    defblock :graph, 1..3
    defblock :indepimage, 1..3, true
    defblock :numberlessimage, 1..3, true

    defblock :address, 0
    defblock :blockquote, 0
    defblock :bpo, 0
    defblock :flushright, 0
    defblock :centering, 0
    defblock :box, 0..1
    defblock :comment, 0..1, true
    defblock :embed, 0..1

    defminicolumn :note, 0..1
    defminicolumn :memo, 0..1
    defminicolumn :tip, 0..1
    defminicolumn :info, 0..1
    defminicolumn :warning, 0..1
    defminicolumn :important, 0..1
    defminicolumn :caution, 0..1
    defminicolumn :notice, 0..1

    defsingle :footnote, 2
    defsingle :noindent, 0
    defsingle :blankline, 0
    defsingle :pagebreak, 0
    defsingle :hr, 0
    defsingle :parasep, 0
    defsingle :label, 1
    defsingle :raw, 1
    defsingle :tsize, 1
    defsingle :include, 1
    defsingle :olnum, 1
    defsingle :firstlinenum, 1
    defsingle :beginchild, 0
    defsingle :endchild, 0

    definline :chapref
    definline :chap
    definline :title
    definline :img
    definline :imgref
    definline :icon
    definline :list
    definline :table
    definline :eq
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
    definline :balloon

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
    definline :embed
    definline :pageref
    definline :w
    definline :wb

    private

    def do_compile
      f = LineInput.new(StringIO.new(@chapter.content))
      @builder.bind(self, @chapter, Location.new(@chapter.basename, f))

      ## in minicolumn, such as note/info/alert...
      @minicolumn_name = nil

      tagged_section_init
      while f.next?
        case f.peek
        when /\A\#@/
          f.gets # Nothing to do
        when /\A=+[\[\s{]/
          compile_headline(f.gets)
          @builder.previous_list_type = nil
        when /\A\s+\*/
          compile_ulist(f)
          @builder.previous_list_type = 'ul'
        when /\A\s+\d+\./
          compile_olist(f)
          @builder.previous_list_type = 'ol'
        when /\A\s+:\s/
          compile_dlist(f)
          @builder.previous_list_type = 'dl'
        when /\A\s*:\s/
          warn 'Definition list starting with `:` is deprecated. It should start with ` : `.'
          compile_dlist(f)
          @builder.previous_list_type = 'dl'
        when %r{\A//\}}
          if in_minicolumn?
            _line = f.gets
            compile_minicolumn_end
          else
            f.gets
            error 'block end seen but not opened'
          end
        when %r{\A//[a-z]+}
          line = f.peek
          matched = line =~ %r|\A//([a-z]+)(:?\[.*\])?{\s*$|
          if matched && minicolumn_block_name?($1)
            line = f.gets
            name = $1
            args = parse_args(line.sub(%r{\A//[a-z]+}, '').rstrip.chomp('{'), name)
            compile_minicolumn_begin(name, *args)
          else
            # @command_name_stack.push(name) ## <- move into read_command() to use name
            name, args, lines = read_command(f)
            syntax = syntax_descriptor(name)
            unless syntax
              error "unknown command: //#{name}"
              compile_unknown_command(args, lines)
              @command_name_stack.pop
              next
            end
            compile_command(syntax, args, lines)
            @command_name_stack.pop
          end
          @builder.previous_list_type = nil
        when %r{\A//}
          line = f.gets
          warn "`//' seen but is not valid command: #{line.strip.inspect}"
          if block_open?(line)
            warn 'skipping block...'
            read_block(f, false)
          end
          @builder.previous_list_type = nil
        else
          if f.peek.strip.empty?
            f.gets
            next
          end
          compile_paragraph(f)
          @builder.previous_list_type = nil
        end
      end
      close_all_tagged_section
    end

    def compile_minicolumn_begin(name, caption = nil)
      mid = "#{name}_begin"
      unless @builder.respond_to?(mid)
        error "strategy does not support minicolumn: #{name}"
      end

      if @minicolumn_name
        error "minicolumn cannot be nested: #{name}"
        return
      end
      @minicolumn_name = name

      @builder.__send__(mid, caption)
    end

    def compile_minicolumn_end
      unless @minicolumn_name
        error "minicolumn is not used: #{name}"
        return
      end
      name = @minicolumn_name

      mid = "#{name}_end"
      @builder.__send__(mid)
      @minicolumn_name = nil
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
          if caption.empty?
            warn 'headline is empty.'
          end
          close_current_tagged_section(level)
          open_tagged_section(tag, level, label, caption)
        else
          open_tag = tag[1..-1]
          prev_tag_info = @tagged_section.pop
          if prev_tag_info.nil? || prev_tag_info.first != open_tag
            error "#{open_tag} is not opened."
          end
          close_tagged_section(*prev_tag_info)
        end
      else
        if caption.empty?
          warn 'headline is empty.'
        end
        if @headline_indexs.size > (index + 1)
          @headline_indexs = @headline_indexs[0..index]
        end
        if @headline_indexs[index].nil?
          @headline_indexs[index] = 0
        end
        @headline_indexs[index] += 1
        close_current_tagged_section(level)
        @builder.headline(level, label, caption)
      end
    end

    def close_current_tagged_section(level)
      while @tagged_section.last && (@tagged_section.last[1] >= level)
        close_tagged_section(* @tagged_section.pop)
      end
    end

    def headline(level, label, caption)
      @builder.headline(level, label, caption)
    end

    def tagged_section_init
      @tagged_section = []
    end

    def open_tagged_section(tag, level, label, caption)
      mid = "#{tag}_begin"
      unless @builder.respond_to?(mid)
        error "builder does not support tagged section: #{tag}"
        headline(level, label, caption)
        return
      end
      @tagged_section.push([tag, level])
      @builder.__send__(mid, level, label, caption)
    end

    def close_tagged_section(tag, level)
      mid = "#{tag}_end"
      if @builder.respond_to?(mid)
        @builder.__send__(mid, level)
      else
        error "builder does not support block op: #{mid}"
      end
    end

    def close_all_tagged_section
      until @tagged_section.empty?
        close_tagged_section(* @tagged_section.pop)
      end
    end

    def compile_ulist(f)
      level = 0
      f.while_match(/\A\s+\*|\A\#@/) do |line|
        next if line =~ /\A\#@/

        buf = [text(line.sub(/\*+/, '').strip)]
        f.while_match(/\A\s+(?!\*)\S/) do |cont|
          buf.push(text(cont.strip))
        end

        line =~ /\A\s+(\*+)/
        current_level = $1.size
        if level == current_level
          @builder.ul_item_end
          # body
          @builder.ul_item_begin(buf)
        elsif level < current_level # down
          level_diff = current_level - level
          if level_diff != 1
            error 'too many *.'
          end
          level = current_level
          @builder.ul_begin { level }
          @builder.ul_item_begin(buf)
        elsif level > current_level # up
          level_diff = level - current_level
          level = current_level
          (1..level_diff).to_a.reverse_each do |i|
            @builder.ul_item_end
            @builder.ul_end { level + i }
          end
          @builder.ul_item_end
          # body
          @builder.ul_item_begin(buf)
        end
      end

      (1..level).to_a.reverse_each do |i|
        @builder.ul_item_end
        @builder.ul_end { i }
      end
    end

    def compile_olist(f)
      @builder.ol_begin
      f.while_match(/\A\s+\d+\.|\A\#@/) do |line|
        next if line =~ /\A\#@/

        num = line.match(/(\d+)\./)[1]
        buf = [text(line.sub(/\d+\./, '').strip)]
        f.while_match(/\A\s+(?!\d+\.)\S/) do |cont|
          buf.push(text(cont.strip))
        end
        @builder.ol_item(buf, num)
      end
      @builder.ol_end
    end

    def compile_dlist(f)
      @builder.dl_begin
      while /\A\s*:/ =~ f.peek
        # defer compile_inline to handle footnotes
        @builder.doc_status[:dt] = true
        @builder.dt(text(f.gets.sub(/\A\s*:/, '').strip))
        @builder.doc_status[:dt] = nil
        desc = f.break(/\A(\S|\s*:|\s+\d+\.\s|\s+\*\s)/).map { |line| text(line.strip) }
        @builder.dd(desc)
        f.skip_blank_lines
        f.skip_comment_lines
      end
      @builder.dl_end
    end

    def compile_paragraph(f)
      buf = []
      f.until_match(%r{\A//|\A\#@}) do |line|
        break if line.strip.empty?
        buf.push(text(line.sub(/^(\t+)\s*/) { |m| '<!ESCAPETAB!>' * m.size }.strip.gsub('<!ESCAPETAB!>', "\t")))
      end
      @builder.paragraph(buf)
    end

    def read_command(f)
      line = f.gets
      name = line.slice(/[a-z]+/).to_sym
      ignore_inline = @non_parsed_commands.include?(name)
      @command_name_stack.push(name)
      args = parse_args(line.sub(%r{\A//[a-z]+}, '').rstrip.chomp('{'), name)
      @builder.doc_status[name] = true
      lines = block_open?(line) ? read_block(f, ignore_inline) : nil
      @builder.doc_status[name] = nil
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
          buf.push(line.chomp)
        elsif line !~ /\A\#@/
          buf.push(text(line.rstrip, true))
        end
      end
      unless f.peek.to_s.start_with?('//}')
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
          [']', '\\'].include?(ch) ? ch : '\\' + ch
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
      unless @builder.respond_to?(syntax.name)
        error "builder does not support command: //#{syntax.name}"
        compile_unknown_command(args, lines)
        return
      end
      begin
        syntax.check_args(args)
      rescue CompileError => e
        error e.message
        args = ['(NoArgument)'] * syntax.min_argc
      end
      if syntax.block_allowed?
        compile_block(syntax, args, lines)
      else
        if lines
          error "block is not allowed for command //#{syntax.name}; ignore"
        end
        compile_single(syntax, args)
      end
    end

    def compile_unknown_command(args, lines)
      @builder.unknown_command(args, lines)
    end

    def compile_block(syntax, args, lines)
      @builder.__send__(syntax.name, (lines || default_block(syntax)), *args)
    end

    def default_block(syntax)
      if syntax.block_required?
        error "block is required for //#{syntax.name}; use empty block"
      end
      []
    end

    def compile_single(syntax, args)
      @builder.__send__(syntax.name, *args)
    end

    def replace_fence(str)
      str.gsub(/@<(\w+)>([$|])(.+?)(\2)/) do
        op = $1
        arg = $3
        if arg =~ /[\x01\x02\x03\x04]/
          error "invalid character in '#{str}'"
        end
        replaced = arg.gsub('@', "\x01").gsub('\\', "\x02").gsub('{', "\x03").gsub('}', "\x04")
        "@<#{op}>{#{replaced}}"
      end
    end

    def revert_replace_fence(str)
      str.gsub("\x01", '@').gsub("\x02", '\\').gsub("\x03", '{').gsub("\x04", '}')
    end

    def in_non_escaped_command?
      current_command = @command_name_stack.last
      current_command && non_escaped_commands.include?(current_command)
    end

    def text(str, block_mode = false)
      return '' if str.empty?
      words = replace_fence(str).split(/(@<\w+>\{(?:[^}\\]|\\.)*?\})/, -1)
      words.each do |w|
        if w.scan(/@<\w+>/).size > 1 && !/\A@<raw>/.match(w)
          error "`@<xxx>' seen but is not valid inline op: #{w}"
        end
      end
      result = ''
      until words.empty?
        if in_non_escaped_command? && block_mode
          result << revert_replace_fence(words.shift)
        else
          result << @builder.nofunc_text(revert_replace_fence(words.shift))
        end
        break if words.empty?
        result << compile_inline(revert_replace_fence(words.shift.gsub(/\\\}/, '}').gsub(/\\\\/, '\\')))
      end
      result
    rescue => e
      error e.message
    end
    public :text # called from builder

    def compile_inline(str)
      op, arg = /\A@<(\w+)>\{(.*?)\}\z/.match(str).captures
      unless inline_defined?(op)
        raise CompileError, "no such inline op: #{op}"
      end
      unless @builder.respond_to?("inline_#{op}")
        raise "builder does not support inline op: @<#{op}>"
      end
      @builder.__send__("inline_#{op}", arg)
    rescue => e
      error e.message
      @builder.nofunc_text(str)
    end

    def in_minicolumn?
      @builder.in_minicolumn?
    end

    def minicolumn_block_name?(name)
      @builder.minicolumn_block_name?(name)
    end

    def warn(msg)
      @builder.warn msg
    end

    def error(msg)
      @builder.error msg
    end
  end
end # module ReVIEW
