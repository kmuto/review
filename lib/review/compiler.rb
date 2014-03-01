class ReVIEW::Compiler
  # :stopdoc:

    # This is distinct from setup_parser so that a standalone parser
    # can redefine #initialize and still have access to the proper
    # parser setup code.
    def initialize(str, debug=false)
      setup_parser(str, debug)
    end



    # Prepares for parsing +str+.  If you define a custom initialize you must
    # call this method before #parse
    def setup_parser(str, debug=false)
      set_string str, 0
      @memoizations = Hash.new { |h,k| h[k] = {} }
      @result = nil
      @failed_rule = nil
      @failing_rule_offset = -1

      setup_foreign_grammar
    end

    attr_reader :string
    attr_reader :failing_rule_offset
    attr_accessor :result, :pos

    def current_column(target=pos)
      if c = string.rindex("\n", target-1)
        return target - c - 1
      end

      target + 1
    end

    def current_line(target=pos)
      cur_offset = 0
      cur_line = 0

      string.each_line do |line|
        cur_line += 1
        cur_offset += line.size
        return cur_line if cur_offset >= target
      end

      -1
    end

    def lines
      lines = []
      string.each_line { |l| lines << l }
      lines
    end



    def get_text(start)
      @string[start..@pos-1]
    end

    # Sets the string and current parsing position for the parser.
    def set_string string, pos
      @string = string
      @string_size = string ? string.size : 0
      @pos = pos
    end

    def show_pos
      width = 10
      if @pos < width
        "#{@pos} (\"#{@string[0,@pos]}\" @ \"#{@string[@pos,width]}\")"
      else
        "#{@pos} (\"... #{@string[@pos - width, width]}\" @ \"#{@string[@pos,width]}\")"
      end
    end

    def failure_info
      l = current_line @failing_rule_offset
      c = current_column @failing_rule_offset

      if @failed_rule.kind_of? Symbol
        info = self.class::Rules[@failed_rule]
        "line #{l}, column #{c}: failed rule '#{info.name}' = '#{info.rendered}'"
      else
        "line #{l}, column #{c}: failed rule '#{@failed_rule}'"
      end
    end

    def failure_caret
      l = current_line @failing_rule_offset
      c = current_column @failing_rule_offset

      line = lines[l-1]
      "#{line}\n#{' ' * (c - 1)}^"
    end

    def failure_character
      l = current_line @failing_rule_offset
      c = current_column @failing_rule_offset
      lines[l-1][c-1, 1]
    end

    def failure_oneline
      l = current_line @failing_rule_offset
      c = current_column @failing_rule_offset

      char = lines[l-1][c-1, 1]

      if @failed_rule.kind_of? Symbol
        info = self.class::Rules[@failed_rule]
        "@#{l}:#{c} failed rule '#{info.name}', got '#{char}'"
      else
        "@#{l}:#{c} failed rule '#{@failed_rule}', got '#{char}'"
      end
    end

    class ParseError < RuntimeError
    end

    def raise_error
      raise ParseError, failure_oneline
    end

    def show_error(io=STDOUT)
      error_pos = @failing_rule_offset
      line_no = current_line(error_pos)
      col_no = current_column(error_pos)

      io.puts "On line #{line_no}, column #{col_no}:"

      if @failed_rule.kind_of? Symbol
        info = self.class::Rules[@failed_rule]
        io.puts "Failed to match '#{info.rendered}' (rule '#{info.name}')"
      else
        io.puts "Failed to match rule '#{@failed_rule}'"
      end

      io.puts "Got: #{string[error_pos,1].inspect}"
      line = lines[line_no-1]
      io.puts "=> #{line}"
      io.print(" " * (col_no + 3))
      io.puts "^"
    end

    def set_failed_rule(name)
      if @pos > @failing_rule_offset
        @failed_rule = name
        @failing_rule_offset = @pos
      end
    end

    attr_reader :failed_rule

    def match_string(str)
      len = str.size
      if @string[pos,len] == str
        @pos += len
        return str
      end

      return nil
    end

    def scan(reg)
      if m = reg.match(@string[@pos..-1])
        width = m.end(0)
        @pos += width
        return true
      end

      return nil
    end

    if "".respond_to? :ord
      def get_byte
        if @pos >= @string_size
          return nil
        end

        s = @string[@pos].ord
        @pos += 1
        s
      end
    else
      def get_byte
        if @pos >= @string_size
          return nil
        end

        s = @string[@pos]
        @pos += 1
        s
      end
    end

    def parse(rule=nil)
      # We invoke the rules indirectly via apply
      # instead of by just calling them as methods because
      # if the rules use left recursion, apply needs to
      # manage that.

      if !rule
        apply(:_root)
      else
        method = rule.gsub("-","_hyphen_")
        apply :"_#{method}"
      end
    end

    class MemoEntry
      def initialize(ans, pos)
        @ans = ans
        @pos = pos
        @result = nil
        @set = false
        @left_rec = false
      end

      attr_reader :ans, :pos, :result, :set
      attr_accessor :left_rec

      def move!(ans, pos, result)
        @ans = ans
        @pos = pos
        @result = result
        @set = true
        @left_rec = false
      end
    end

    def external_invoke(other, rule, *args)
      old_pos = @pos
      old_string = @string

      set_string other.string, other.pos

      begin
        if val = __send__(rule, *args)
          other.pos = @pos
          other.result = @result
        else
          other.set_failed_rule "#{self.class}##{rule}"
        end
        val
      ensure
        set_string old_string, old_pos
      end
    end

    def apply_with_args(rule, *args)
      memo_key = [rule, args]
      if m = @memoizations[memo_key][@pos]
        @pos = m.pos
        if !m.set
          m.left_rec = true
          return nil
        end

        @result = m.result

        return m.ans
      else
        m = MemoEntry.new(nil, @pos)
        @memoizations[memo_key][@pos] = m
        start_pos = @pos

        ans = __send__ rule, *args

        lr = m.left_rec

        m.move! ans, @pos, @result

        # Don't bother trying to grow the left recursion
        # if it's failing straight away (thus there is no seed)
        if ans and lr
          return grow_lr(rule, args, start_pos, m)
        else
          return ans
        end

        return ans
      end
    end

    def apply(rule)
      if m = @memoizations[rule][@pos]
        @pos = m.pos
        if !m.set
          m.left_rec = true
          return nil
        end

        @result = m.result

        return m.ans
      else
        m = MemoEntry.new(nil, @pos)
        @memoizations[rule][@pos] = m
        start_pos = @pos

        ans = __send__ rule

        lr = m.left_rec

        m.move! ans, @pos, @result

        # Don't bother trying to grow the left recursion
        # if it's failing straight away (thus there is no seed)
        if ans and lr
          return grow_lr(rule, nil, start_pos, m)
        else
          return ans
        end

        return ans
      end
    end

    def grow_lr(rule, args, start_pos, m)
      while true
        @pos = start_pos
        @result = m.result

        if args
          ans = __send__ rule, *args
        else
          ans = __send__ rule
        end
        return nil unless ans

        break if @pos <= m.pos

        m.move! ans, @pos, @result
      end

      @result = m.result
      @pos = m.pos
      return m.ans
    end

    class RuleInfo
      def initialize(name, rendered)
        @name = name
        @rendered = rendered
      end

      attr_reader :name, :rendered
    end

    def self.rule_info(name, rendered)
      RuleInfo.new(name, rendered)
    end


  # :startdoc:



  class Error; end

require 'review/location'
require 'review/extentions'
require 'review/preprocessor'
require 'review/exception'
  require 'lineinput'
  if RUBY_VERSION > '1.9' then
    require 'review/compiler/literals_1_9'
  else
    require 'review/compiler/literals_1_8'
  end

  ## redifine Compiler.new
  def initialize(strategy)
    @strategy = strategy
  end

  attr_accessor :strategy

    def compile(chap)
      @chapter = chap
      do_compile
      @strategy.result
    end

    def do_compile
      f = LineInput.new(ReVIEW::Preprocessor::Strip.new(StringIO.new(@chapter.content)))
      @strategy.bind self, @chapter, ReVIEW::Location.new(@chapter.basename, f)
      setup_parser(@chapter.content)
      parse()
    end

    def text(str)
      st = @strategy.dup
      f = LineInput.new(ReVIEW::Preprocessor::Strip.new(StringIO.new(str)))
      st.bind self, @chapter, ReVIEW::Location.new(@chapter.basename, f)
      parser = ReVIEW::Compiler.new(st)
      parser.setup_parser(str)
      parser.parse("InlineElementContents")
      st.result
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
        @checker.call(*args) if @checker
      end

      def min_argc
        case @argc_spec
        when Range then @argc_spec.begin
        when Integer then @argc_spec
        else
          raise TypeError, "argc_spec is not Range/Integer: #{inspect()}"
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

    def self.definline(name)
      INLINE[name] = InlineSyntaxElement.new(name)
    end

    def inline_defined?(name)
      INLINE.key?(name.to_sym)
    end

    defblock :read, 0
    defblock :lead, 0
    defblock :list, 2
    defblock :emlist, 0..1
    defblock :cmd, 0..1
    defblock :table, 0..2
    defblock :quote, 0
    defblock :image, 2..3, true
    defblock :source, 0..1
    defblock :listnum, 2
    defblock :emlistnum, 0..1
    defblock :bibpaper, 2..3, true
    defblock :doorquote, 1
    defblock :talk, 0
    defblock :texequation, 0
    defblock :graph, 1..3

    defblock :address, 0
    defblock :blockquote, 0
    defblock :bpo, 0
    defblock :flushright, 0
    defblock :centering, 0
    defblock :note, 0..1
    defblock :box, 0..1
    defblock :comment, 0..1, true

    defsingle :footnote, 2
    defsingle :noindent, 0
    defsingle :linebreak, 0
    defsingle :pagebreak, 0
    defsingle :indepimage, 1..3
    defsingle :numberlessimage, 1..3
    defsingle :hr, 0
    defsingle :parasep, 0
    defsingle :label, 1
    defsingle :raw, 1
    defsingle :tsize, 1
    defsingle :include, 1
    defsingle :olnum, 1

    definline :chapref
    definline :chap
    definline :title
    definline :img
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


    def tagged_section_init
      @tagged_section = []
    end

    def open_tagged_section(tag, level, label, caption)
      mid = "#{tag}_begin"
      unless @strategy.respond_to?(mid)
        error "strategy does not support tagged section: #{tag}"
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
      until @tagged_section.empty?
        close_tagged_section(* @tagged_section.pop)
      end
    end

    def compile_command(name, args, lines)
          syntax = syntax_descriptor(name)
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
        if lines
          error "block is not allowed for command //#{syntax.name}; ignore"
        end
        compile_single syntax, args
      end
    end

    def compile_headline(level, tag, label, caption)
      @headline_indexs ||= [0] ## XXX
      caption.strip!
      index = level - 1
      if tag
        if tag !~ /\A\//
          close_current_tagged_section(level)
          open_tagged_section(tag, level, label, caption)
        else
          open_tag = tag[1..-1]
          prev_tag_info = @tagged_section.pop
          unless prev_tag_info.first == open_tag
            raise CompileError, "#{open_tag} is not opened."
          end
          close_tagged_section(*prev_tag_info)
        end
      else
        if @headline_indexs.size > (index + 1)
          @headline_indexs = @headline_indexs[0..index]
        end
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

    def comment(text)
      @strategy.comment(text)
    end

    def compile_ulist(elem)
      level = 0
      elem.each do |current_level, buf|
        if level == current_level
          @strategy.ul_item_end
          # body
          @strategy.ul_item_begin [buf]
        elsif level < current_level # down
          level_diff = current_level - level
          level = current_level
          (1..(level_diff - 1)).to_a.reverse.each do |i|
            @strategy.ul_begin {i}
            @strategy.ul_item_begin []
          end
          @strategy.ul_begin {level}
          @strategy.ul_item_begin [buf]
        elsif level > current_level # up
          level_diff = level - current_level
          level = current_level
          (1..level_diff).to_a.reverse.each do |i|
            @strategy.ul_item_end
            @strategy.ul_end {level + i}
          end
          @strategy.ul_item_end
          # body
          @strategy.ul_item_begin [buf]
        end
      end

      (1..level).to_a.reverse.each do |i|
        @strategy.ul_item_end
        @strategy.ul_end {i}
      end
    end

    def compile_olist(elem)
      @strategy.ol_begin
      elem.each do |num, buf|
        @strategy.ol_item buf, num
      end
      @strategy.ol_end
    end


    def compile_unknown_command(args, lines)
      @strategy.unknown_command args, lines
    end

    def compile_block(syntax, args, lines)
      @strategy.__send__(syntax.name, (lines || default_block(syntax)), *args)
    end

    def default_block(syntax)
      if syntax.block_required?
        error "block is required for //#{syntax.name}; use empty block"
      end
      []
    end

    def compile_single(syntax, args)
      @strategy.__send__(syntax.name, *args)
    end



    def compile_inline(op, arg)
      unless inline_defined?(op)
        raise CompileError, "no such inline op: #{op}"
      end
      unless @strategy.respond_to?("inline_#{op}")
        raise "strategy does not support inline op: @<#{op}>"
      end
      @strategy.__send__("inline_#{op}", arg)
    rescue => err
      error err.message
    end

    def compile_paragraph(buf)
      @strategy.paragraph buf
    end

    def warn(msg)
      @strategy.warn msg
    end

    def error(msg)
      @strategy.error msg
    end




  # :stopdoc:
  def setup_foreign_grammar
    @_grammar_literals = ReVIEW::Compiler::Literals.new(nil)
  end

  # root = Start
  def _root
    _tmp = apply(:_Start)
    set_failed_rule :_root unless _tmp
    return _tmp
  end

  # Start = &. { tagged_section_init } Block* { close_all_tagged_section }
  def _Start

    _save = self.pos
    while true # sequence
      _save1 = self.pos
      _tmp = get_byte
      self.pos = _save1
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  tagged_section_init ; end
      _tmp = true
      unless _tmp
        self.pos = _save
        break
      end
      while true
        _tmp = apply(:_Block)
        break unless _tmp
      end
      _tmp = true
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  close_all_tagged_section ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_Start unless _tmp
    return _tmp
  end

  # Block = BlankLine* (SinglelineComment:c | Headline:headline | BlockElement:c | Ulist:c | Olist:c | Dlist:c | Paragraph:c)
  def _Block

    _save = self.pos
    while true # sequence
      while true
        _tmp = apply(:_BlankLine)
        break unless _tmp
      end
      _tmp = true
      unless _tmp
        self.pos = _save
        break
      end

      _save2 = self.pos
      while true # choice
        _tmp = apply(:_SinglelineComment)
        c = @result
        break if _tmp
        self.pos = _save2
        _tmp = apply(:_Headline)
        headline = @result
        break if _tmp
        self.pos = _save2
        _tmp = apply(:_BlockElement)
        c = @result
        break if _tmp
        self.pos = _save2
        _tmp = apply(:_Ulist)
        c = @result
        break if _tmp
        self.pos = _save2
        _tmp = apply(:_Olist)
        c = @result
        break if _tmp
        self.pos = _save2
        _tmp = apply(:_Dlist)
        c = @result
        break if _tmp
        self.pos = _save2
        _tmp = apply(:_Paragraph)
        c = @result
        break if _tmp
        self.pos = _save2
        break
      end # end choice

      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_Block unless _tmp
    return _tmp
  end

  # BlankLine = Newline
  def _BlankLine
    _tmp = apply(:_Newline)
    set_failed_rule :_BlankLine unless _tmp
    return _tmp
  end

  # Headline = HeadlinePrefix:level BracketArg?:cmd BraceArg?:label Space* SinglelineContent:caption Newline* { compile_headline(level, cmd, label, caption) }
  def _Headline

    _save = self.pos
    while true # sequence
      _tmp = apply(:_HeadlinePrefix)
      level = @result
      unless _tmp
        self.pos = _save
        break
      end
      _save1 = self.pos
      _tmp = apply(:_BracketArg)
      @result = nil unless _tmp
      unless _tmp
        _tmp = true
        self.pos = _save1
      end
      cmd = @result
      unless _tmp
        self.pos = _save
        break
      end
      _save2 = self.pos
      _tmp = apply(:_BraceArg)
      @result = nil unless _tmp
      unless _tmp
        _tmp = true
        self.pos = _save2
      end
      label = @result
      unless _tmp
        self.pos = _save
        break
      end
      while true
        _tmp = apply(:_Space)
        break unless _tmp
      end
      _tmp = true
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_SinglelineContent)
      caption = @result
      unless _tmp
        self.pos = _save
        break
      end
      while true
        _tmp = apply(:_Newline)
        break unless _tmp
      end
      _tmp = true
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  compile_headline(level, cmd, label, caption) ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_Headline unless _tmp
    return _tmp
  end

  # HeadlinePrefix = < /={1,5}/ > { text.length }
  def _HeadlinePrefix

    _save = self.pos
    while true # sequence
      _text_start = self.pos
      _tmp = scan(/\A(?-mix:={1,5})/)
      if _tmp
        text = get_text(_text_start)
      end
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  text.length ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_HeadlinePrefix unless _tmp
    return _tmp
  end

  # Paragraph = ParagraphSub+:c { compile_paragraph(c) }
  def _Paragraph

    _save = self.pos
    while true # sequence
      _save1 = self.pos
      _ary = []
      _tmp = apply(:_ParagraphSub)
      if _tmp
        _ary << @result
        while true
          _tmp = apply(:_ParagraphSub)
          _ary << @result if _tmp
          break unless _tmp
        end
        _tmp = true
        @result = _ary
      else
        self.pos = _save1
      end
      c = @result
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  compile_paragraph(c) ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_Paragraph unless _tmp
    return _tmp
  end

  # ParagraphSub = (InlineElement:c { c } | < ContentText > { text })+:d Newline { d }
  def _ParagraphSub

    _save = self.pos
    while true # sequence
      _save1 = self.pos
      _ary = []

      _save2 = self.pos
      while true # choice

        _save3 = self.pos
        while true # sequence
          _tmp = apply(:_InlineElement)
          c = @result
          unless _tmp
            self.pos = _save3
            break
          end
          @result = begin;  c ; end
          _tmp = true
          unless _tmp
            self.pos = _save3
          end
          break
        end # end sequence

        break if _tmp
        self.pos = _save2

        _save4 = self.pos
        while true # sequence
          _text_start = self.pos
          _tmp = apply(:_ContentText)
          if _tmp
            text = get_text(_text_start)
          end
          unless _tmp
            self.pos = _save4
            break
          end
          @result = begin;  text ; end
          _tmp = true
          unless _tmp
            self.pos = _save4
          end
          break
        end # end sequence

        break if _tmp
        self.pos = _save2
        break
      end # end choice

      if _tmp
        _ary << @result
        while true

          _save5 = self.pos
          while true # choice

            _save6 = self.pos
            while true # sequence
              _tmp = apply(:_InlineElement)
              c = @result
              unless _tmp
                self.pos = _save6
                break
              end
              @result = begin;  c ; end
              _tmp = true
              unless _tmp
                self.pos = _save6
              end
              break
            end # end sequence

            break if _tmp
            self.pos = _save5

            _save7 = self.pos
            while true # sequence
              _text_start = self.pos
              _tmp = apply(:_ContentText)
              if _tmp
                text = get_text(_text_start)
              end
              unless _tmp
                self.pos = _save7
                break
              end
              @result = begin;  text ; end
              _tmp = true
              unless _tmp
                self.pos = _save7
              end
              break
            end # end sequence

            break if _tmp
            self.pos = _save5
            break
          end # end choice

          _ary << @result if _tmp
          break unless _tmp
        end
        _tmp = true
        @result = _ary
      else
        self.pos = _save1
      end
      d = @result
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_Newline)
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  d ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_ParagraphSub unless _tmp
    return _tmp
  end

  # ContentText = NonInlineElement+:c { c }
  def _ContentText

    _save = self.pos
    while true # sequence
      _save1 = self.pos
      _ary = []
      _tmp = apply(:_NonInlineElement)
      if _tmp
        _ary << @result
        while true
          _tmp = apply(:_NonInlineElement)
          _ary << @result if _tmp
          break unless _tmp
        end
        _tmp = true
        @result = _ary
      else
        self.pos = _save1
      end
      c = @result
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  c ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_ContentText unless _tmp
    return _tmp
  end

  # NonInlineElement = !InlineElement < /[^\r\n]/ > { text }
  def _NonInlineElement

    _save = self.pos
    while true # sequence
      _save1 = self.pos
      _tmp = apply(:_InlineElement)
      _tmp = _tmp ? nil : true
      self.pos = _save1
      unless _tmp
        self.pos = _save
        break
      end
      _text_start = self.pos
      _tmp = scan(/\A(?-mix:[^\r\n])/)
      if _tmp
        text = get_text(_text_start)
      end
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  text ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_NonInlineElement unless _tmp
    return _tmp
  end

  # BlockElement = ("//" ElementName:symbol BracketArg*:args "{" Space* Newline BlockElementContents?:contents "//}" Space* Newline {           compile_command(symbol, args, contents) } | "//" ElementName:symbol BracketArg*:args Space* Newline)
  def _BlockElement

    _save = self.pos
    while true # choice

      _save1 = self.pos
      while true # sequence
        _tmp = match_string("//")
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = apply(:_ElementName)
        symbol = @result
        unless _tmp
          self.pos = _save1
          break
        end
        _ary = []
        while true
          _tmp = apply(:_BracketArg)
          _ary << @result if _tmp
          break unless _tmp
        end
        _tmp = true
        @result = _ary
        args = @result
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = match_string("{")
        unless _tmp
          self.pos = _save1
          break
        end
        while true
          _tmp = apply(:_Space)
          break unless _tmp
        end
        _tmp = true
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = apply(:_Newline)
        unless _tmp
          self.pos = _save1
          break
        end
        _save4 = self.pos
        _tmp = apply(:_BlockElementContents)
        @result = nil unless _tmp
        unless _tmp
          _tmp = true
          self.pos = _save4
        end
        contents = @result
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = match_string("//}")
        unless _tmp
          self.pos = _save1
          break
        end
        while true
          _tmp = apply(:_Space)
          break unless _tmp
        end
        _tmp = true
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = apply(:_Newline)
        unless _tmp
          self.pos = _save1
          break
        end
        @result = begin;            compile_command(symbol, args, contents) ; end
        _tmp = true
        unless _tmp
          self.pos = _save1
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save6 = self.pos
      while true # sequence
        _tmp = match_string("//")
        unless _tmp
          self.pos = _save6
          break
        end
        _tmp = apply(:_ElementName)
        symbol = @result
        unless _tmp
          self.pos = _save6
          break
        end
        _ary = []
        while true
          _tmp = apply(:_BracketArg)
          _ary << @result if _tmp
          break unless _tmp
        end
        _tmp = true
        @result = _ary
        args = @result
        unless _tmp
          self.pos = _save6
          break
        end
        while true
          _tmp = apply(:_Space)
          break unless _tmp
        end
        _tmp = true
        unless _tmp
          self.pos = _save6
          break
        end
        _tmp = apply(:_Newline)
        unless _tmp
          self.pos = _save6
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_BlockElement unless _tmp
    return _tmp
  end

  # InlineElement = "@<" < /[^>\r\n]+/ > {symbol = text} ">" "{" < InlineElementContents? > { contents = text } "}" { compile_inline(symbol,contents); }
  def _InlineElement

    _save = self.pos
    while true # sequence
      _tmp = match_string("@<")
      unless _tmp
        self.pos = _save
        break
      end
      _text_start = self.pos
      _tmp = scan(/\A(?-mix:[^>\r\n]+)/)
      if _tmp
        text = get_text(_text_start)
      end
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; symbol = text; end
      _tmp = true
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = match_string(">")
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = match_string("{")
      unless _tmp
        self.pos = _save
        break
      end
      _text_start = self.pos
      _save1 = self.pos
      _tmp = apply(:_InlineElementContents)
      unless _tmp
        _tmp = true
        self.pos = _save1
      end
      if _tmp
        text = get_text(_text_start)
      end
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  contents = text ; end
      _tmp = true
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = match_string("}")
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  compile_inline(symbol,contents); ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_InlineElement unless _tmp
    return _tmp
  end

  # BracketArg = "[" < /([^\r\n\]\\]|\\[^\r\n])*/ > "]" { text }
  def _BracketArg

    _save = self.pos
    while true # sequence
      _tmp = match_string("[")
      unless _tmp
        self.pos = _save
        break
      end
      _text_start = self.pos
      _tmp = scan(/\A(?-mix:([^\r\n\]\\]|\\[^\r\n])*)/)
      if _tmp
        text = get_text(_text_start)
      end
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = match_string("]")
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  text ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_BracketArg unless _tmp
    return _tmp
  end

  # BraceArg = "{" < /([^\r\n}\\]|\\[^\r\n])*/ > "}" { text }
  def _BraceArg

    _save = self.pos
    while true # sequence
      _tmp = match_string("{")
      unless _tmp
        self.pos = _save
        break
      end
      _text_start = self.pos
      _tmp = scan(/\A(?-mix:([^\r\n}\\]|\\[^\r\n])*)/)
      if _tmp
        text = get_text(_text_start)
      end
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = match_string("}")
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  text ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_BraceArg unless _tmp
    return _tmp
  end

  # BlockElementContents = BlockElementContent+:c
  def _BlockElementContents
    _save = self.pos
    _ary = []
    _tmp = apply(:_BlockElementContent)
    if _tmp
      _ary << @result
      while true
        _tmp = apply(:_BlockElementContent)
        _ary << @result if _tmp
        break unless _tmp
      end
      _tmp = true
      @result = _ary
    else
      self.pos = _save
    end
    c = @result
    set_failed_rule :_BlockElementContents unless _tmp
    return _tmp
  end

  # BlockElementContent = (SinglelineComment:c | BlockElement:c | BlockElementParagraph:c)
  def _BlockElementContent

    _save = self.pos
    while true # choice
      _tmp = apply(:_SinglelineComment)
      c = @result
      break if _tmp
      self.pos = _save
      _tmp = apply(:_BlockElement)
      c = @result
      break if _tmp
      self.pos = _save
      _tmp = apply(:_BlockElementParagraph)
      c = @result
      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_BlockElementContent unless _tmp
    return _tmp
  end

  # BlockElementParagraph = &. { @blockElem = [] } BlockElementParagraphSub+:c { @blockElem }
  def _BlockElementParagraph

    _save = self.pos
    while true # sequence
      _save1 = self.pos
      _tmp = get_byte
      self.pos = _save1
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  @blockElem = [] ; end
      _tmp = true
      unless _tmp
        self.pos = _save
        break
      end
      _save2 = self.pos
      _ary = []
      _tmp = apply(:_BlockElementParagraphSub)
      if _tmp
        _ary << @result
        while true
          _tmp = apply(:_BlockElementParagraphSub)
          _ary << @result if _tmp
          break unless _tmp
        end
        _tmp = true
        @result = _ary
      else
        self.pos = _save2
      end
      c = @result
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  @blockElem ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_BlockElementParagraph unless _tmp
    return _tmp
  end

  # BlockElementParagraphSub = (InlineElement:c { @blockElem << c } | BlockElementContentText:c { @blockElem << c })+ Newline
  def _BlockElementParagraphSub

    _save = self.pos
    while true # sequence
      _save1 = self.pos

      _save2 = self.pos
      while true # choice

        _save3 = self.pos
        while true # sequence
          _tmp = apply(:_InlineElement)
          c = @result
          unless _tmp
            self.pos = _save3
            break
          end
          @result = begin;  @blockElem << c ; end
          _tmp = true
          unless _tmp
            self.pos = _save3
          end
          break
        end # end sequence

        break if _tmp
        self.pos = _save2

        _save4 = self.pos
        while true # sequence
          _tmp = apply(:_BlockElementContentText)
          c = @result
          unless _tmp
            self.pos = _save4
            break
          end
          @result = begin;  @blockElem << c ; end
          _tmp = true
          unless _tmp
            self.pos = _save4
          end
          break
        end # end sequence

        break if _tmp
        self.pos = _save2
        break
      end # end choice

      if _tmp
        while true

          _save5 = self.pos
          while true # choice

            _save6 = self.pos
            while true # sequence
              _tmp = apply(:_InlineElement)
              c = @result
              unless _tmp
                self.pos = _save6
                break
              end
              @result = begin;  @blockElem << c ; end
              _tmp = true
              unless _tmp
                self.pos = _save6
              end
              break
            end # end sequence

            break if _tmp
            self.pos = _save5

            _save7 = self.pos
            while true # sequence
              _tmp = apply(:_BlockElementContentText)
              c = @result
              unless _tmp
                self.pos = _save7
                break
              end
              @result = begin;  @blockElem << c ; end
              _tmp = true
              unless _tmp
                self.pos = _save7
              end
              break
            end # end sequence

            break if _tmp
            self.pos = _save5
            break
          end # end choice

          break unless _tmp
        end
        _tmp = true
      else
        self.pos = _save1
      end
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_Newline)
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_BlockElementParagraphSub unless _tmp
    return _tmp
  end

  # BlockElementContentText = !"//}" !SinglelineComment !BlockElement !Ulist !Olist !Dlist < NonInlineElement+ > { text }
  def _BlockElementContentText

    _save = self.pos
    while true # sequence
      _save1 = self.pos
      _tmp = match_string("//}")
      _tmp = _tmp ? nil : true
      self.pos = _save1
      unless _tmp
        self.pos = _save
        break
      end
      _save2 = self.pos
      _tmp = apply(:_SinglelineComment)
      _tmp = _tmp ? nil : true
      self.pos = _save2
      unless _tmp
        self.pos = _save
        break
      end
      _save3 = self.pos
      _tmp = apply(:_BlockElement)
      _tmp = _tmp ? nil : true
      self.pos = _save3
      unless _tmp
        self.pos = _save
        break
      end
      _save4 = self.pos
      _tmp = apply(:_Ulist)
      _tmp = _tmp ? nil : true
      self.pos = _save4
      unless _tmp
        self.pos = _save
        break
      end
      _save5 = self.pos
      _tmp = apply(:_Olist)
      _tmp = _tmp ? nil : true
      self.pos = _save5
      unless _tmp
        self.pos = _save
        break
      end
      _save6 = self.pos
      _tmp = apply(:_Dlist)
      _tmp = _tmp ? nil : true
      self.pos = _save6
      unless _tmp
        self.pos = _save
        break
      end
      _text_start = self.pos
      _save7 = self.pos
      _tmp = apply(:_NonInlineElement)
      if _tmp
        while true
          _tmp = apply(:_NonInlineElement)
          break unless _tmp
        end
        _tmp = true
      else
        self.pos = _save7
      end
      if _tmp
        text = get_text(_text_start)
      end
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  text ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_BlockElementContentText unless _tmp
    return _tmp
  end

  # InlineElementContents = !"}" InlineElementContent+:c { c }
  def _InlineElementContents

    _save = self.pos
    while true # sequence
      _save1 = self.pos
      _tmp = match_string("}")
      _tmp = _tmp ? nil : true
      self.pos = _save1
      unless _tmp
        self.pos = _save
        break
      end
      _save2 = self.pos
      _ary = []
      _tmp = apply(:_InlineElementContent)
      if _tmp
        _ary << @result
        while true
          _tmp = apply(:_InlineElementContent)
          _ary << @result if _tmp
          break unless _tmp
        end
        _tmp = true
        @result = _ary
      else
        self.pos = _save2
      end
      c = @result
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  c ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_InlineElementContents unless _tmp
    return _tmp
  end

  # InlineElementContent = (InlineElement:c | InlineElementContentText:c)
  def _InlineElementContent

    _save = self.pos
    while true # choice
      _tmp = apply(:_InlineElement)
      c = @result
      break if _tmp
      self.pos = _save
      _tmp = apply(:_InlineElementContentText)
      c = @result
      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_InlineElementContent unless _tmp
    return _tmp
  end

  # InlineElementContentText = (!InlineElement /[^\r\n}]/)+
  def _InlineElementContentText
    _save = self.pos

    _save1 = self.pos
    while true # sequence
      _save2 = self.pos
      _tmp = apply(:_InlineElement)
      _tmp = _tmp ? nil : true
      self.pos = _save2
      unless _tmp
        self.pos = _save1
        break
      end
      _tmp = scan(/\A(?-mix:[^\r\n}])/)
      unless _tmp
        self.pos = _save1
      end
      break
    end # end sequence

    if _tmp
      while true

        _save3 = self.pos
        while true # sequence
          _save4 = self.pos
          _tmp = apply(:_InlineElement)
          _tmp = _tmp ? nil : true
          self.pos = _save4
          unless _tmp
            self.pos = _save3
            break
          end
          _tmp = scan(/\A(?-mix:[^\r\n}])/)
          unless _tmp
            self.pos = _save3
          end
          break
        end # end sequence

        break unless _tmp
      end
      _tmp = true
    else
      self.pos = _save
    end
    set_failed_rule :_InlineElementContentText unless _tmp
    return _tmp
  end

  # SinglelineContent = ContentInlines:c (Newline | EOF) { c }
  def _SinglelineContent

    _save = self.pos
    while true # sequence
      _tmp = apply(:_ContentInlines)
      c = @result
      unless _tmp
        self.pos = _save
        break
      end

      _save1 = self.pos
      while true # choice
        _tmp = apply(:_Newline)
        break if _tmp
        self.pos = _save1
        _tmp = apply(:_EOF)
        break if _tmp
        self.pos = _save1
        break
      end # end choice

      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  c ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_SinglelineContent unless _tmp
    return _tmp
  end

  # ContentInlines = ContentInline+:c { c.join }
  def _ContentInlines

    _save = self.pos
    while true # sequence
      _save1 = self.pos
      _ary = []
      _tmp = apply(:_ContentInline)
      if _tmp
        _ary << @result
        while true
          _tmp = apply(:_ContentInline)
          _ary << @result if _tmp
          break unless _tmp
        end
        _tmp = true
        @result = _ary
      else
        self.pos = _save1
      end
      c = @result
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  c.join ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_ContentInlines unless _tmp
    return _tmp
  end

  # ContentInline = (InlineElement:c { c } | !Newline < /[^\r\n]/ > {text })
  def _ContentInline

    _save = self.pos
    while true # choice

      _save1 = self.pos
      while true # sequence
        _tmp = apply(:_InlineElement)
        c = @result
        unless _tmp
          self.pos = _save1
          break
        end
        @result = begin;  c ; end
        _tmp = true
        unless _tmp
          self.pos = _save1
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save2 = self.pos
      while true # sequence
        _save3 = self.pos
        _tmp = apply(:_Newline)
        _tmp = _tmp ? nil : true
        self.pos = _save3
        unless _tmp
          self.pos = _save2
          break
        end
        _text_start = self.pos
        _tmp = scan(/\A(?-mix:[^\r\n])/)
        if _tmp
          text = get_text(_text_start)
        end
        unless _tmp
          self.pos = _save2
          break
        end
        @result = begin; text ; end
        _tmp = true
        unless _tmp
          self.pos = _save2
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_ContentInline unless _tmp
    return _tmp
  end

  # Ulist = &. { @ulist_elem=[] } (UlistElement | SinglelineComment)+ (Newline | EOF) { compile_ulist(@ulist_elem) }
  def _Ulist

    _save = self.pos
    while true # sequence
      _save1 = self.pos
      _tmp = get_byte
      self.pos = _save1
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  @ulist_elem=[] ; end
      _tmp = true
      unless _tmp
        self.pos = _save
        break
      end
      _save2 = self.pos

      _save3 = self.pos
      while true # choice
        _tmp = apply(:_UlistElement)
        break if _tmp
        self.pos = _save3
        _tmp = apply(:_SinglelineComment)
        break if _tmp
        self.pos = _save3
        break
      end # end choice

      if _tmp
        while true

          _save4 = self.pos
          while true # choice
            _tmp = apply(:_UlistElement)
            break if _tmp
            self.pos = _save4
            _tmp = apply(:_SinglelineComment)
            break if _tmp
            self.pos = _save4
            break
          end # end choice

          break unless _tmp
        end
        _tmp = true
      else
        self.pos = _save2
      end
      unless _tmp
        self.pos = _save
        break
      end

      _save5 = self.pos
      while true # choice
        _tmp = apply(:_Newline)
        break if _tmp
        self.pos = _save5
        _tmp = apply(:_EOF)
        break if _tmp
        self.pos = _save5
        break
      end # end choice

      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  compile_ulist(@ulist_elem) ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_Ulist unless _tmp
    return _tmp
  end

  # UlistElement = " "+ "*"+:level " "* SinglelineContent:c { @ulist_elem << [level.size, c] }
  def _UlistElement

    _save = self.pos
    while true # sequence
      _save1 = self.pos
      _tmp = match_string(" ")
      if _tmp
        while true
          _tmp = match_string(" ")
          break unless _tmp
        end
        _tmp = true
      else
        self.pos = _save1
      end
      unless _tmp
        self.pos = _save
        break
      end
      _save2 = self.pos
      _ary = []
      _tmp = match_string("*")
      if _tmp
        _ary << @result
        while true
          _tmp = match_string("*")
          _ary << @result if _tmp
          break unless _tmp
        end
        _tmp = true
        @result = _ary
      else
        self.pos = _save2
      end
      level = @result
      unless _tmp
        self.pos = _save
        break
      end
      while true
        _tmp = match_string(" ")
        break unless _tmp
      end
      _tmp = true
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_SinglelineContent)
      c = @result
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  @ulist_elem << [level.size, c] ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_UlistElement unless _tmp
    return _tmp
  end

  # Olist = { @olist_elem = [] } (OlistElement | SinglelineComment)+:c { compile_olist(@olist_elem) }
  def _Olist

    _save = self.pos
    while true # sequence
      @result = begin;  @olist_elem = [] ; end
      _tmp = true
      unless _tmp
        self.pos = _save
        break
      end
      _save1 = self.pos
      _ary = []

      _save2 = self.pos
      while true # choice
        _tmp = apply(:_OlistElement)
        break if _tmp
        self.pos = _save2
        _tmp = apply(:_SinglelineComment)
        break if _tmp
        self.pos = _save2
        break
      end # end choice

      if _tmp
        _ary << @result
        while true

          _save3 = self.pos
          while true # choice
            _tmp = apply(:_OlistElement)
            break if _tmp
            self.pos = _save3
            _tmp = apply(:_SinglelineComment)
            break if _tmp
            self.pos = _save3
            break
          end # end choice

          _ary << @result if _tmp
          break unless _tmp
        end
        _tmp = true
        @result = _ary
      else
        self.pos = _save1
      end
      c = @result
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  compile_olist(@olist_elem) ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_Olist unless _tmp
    return _tmp
  end

  # OlistElement = " "+ < /\d/+ > { level=text } "." Space* SinglelineContent:c {@olist_elem << [level, c] }
  def _OlistElement

    _save = self.pos
    while true # sequence
      _save1 = self.pos
      _tmp = match_string(" ")
      if _tmp
        while true
          _tmp = match_string(" ")
          break unless _tmp
        end
        _tmp = true
      else
        self.pos = _save1
      end
      unless _tmp
        self.pos = _save
        break
      end
      _text_start = self.pos
      _save2 = self.pos
      _tmp = scan(/\A(?-mix:\d)/)
      if _tmp
        while true
          _tmp = scan(/\A(?-mix:\d)/)
          break unless _tmp
        end
        _tmp = true
      else
        self.pos = _save2
      end
      if _tmp
        text = get_text(_text_start)
      end
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  level=text ; end
      _tmp = true
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = match_string(".")
      unless _tmp
        self.pos = _save
        break
      end
      while true
        _tmp = apply(:_Space)
        break unless _tmp
      end
      _tmp = true
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_SinglelineContent)
      c = @result
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; @olist_elem << [level, c] ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_OlistElement unless _tmp
    return _tmp
  end

  # Dlist = (DlistElement | SinglelineComment):c Dlist?:cc
  def _Dlist

    _save = self.pos
    while true # sequence

      _save1 = self.pos
      while true # choice
        _tmp = apply(:_DlistElement)
        break if _tmp
        self.pos = _save1
        _tmp = apply(:_SinglelineComment)
        break if _tmp
        self.pos = _save1
        break
      end # end choice

      c = @result
      unless _tmp
        self.pos = _save
        break
      end
      _save2 = self.pos
      _tmp = apply(:_Dlist)
      @result = nil unless _tmp
      unless _tmp
        _tmp = true
        self.pos = _save2
      end
      cc = @result
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_Dlist unless _tmp
    return _tmp
  end

  # DlistElement = " "* ":" " " Space* SinglelineContent:text DlistElementContent:content
  def _DlistElement

    _save = self.pos
    while true # sequence
      while true
        _tmp = match_string(" ")
        break unless _tmp
      end
      _tmp = true
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = match_string(":")
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = match_string(" ")
      unless _tmp
        self.pos = _save
        break
      end
      while true
        _tmp = apply(:_Space)
        break unless _tmp
      end
      _tmp = true
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_SinglelineContent)
      text = @result
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_DlistElementContent)
      content = @result
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_DlistElement unless _tmp
    return _tmp
  end

  # DlistElementContent = /[ \t]+/ SinglelineContent:c
  def _DlistElementContent

    _save = self.pos
    while true # sequence
      _tmp = scan(/\A(?-mix:[ \t]+)/)
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_SinglelineContent)
      c = @result
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_DlistElementContent unless _tmp
    return _tmp
  end

  # SinglelineComment = "#@" < NonNewLine > { comment(text) } Newline
  def _SinglelineComment

    _save = self.pos
    while true # sequence
      _tmp = match_string("\#@")
      unless _tmp
        self.pos = _save
        break
      end
      _text_start = self.pos
      _tmp = apply(:_NonNewLine)
      if _tmp
        text = get_text(_text_start)
      end
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  comment(text) ; end
      _tmp = true
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_Newline)
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_SinglelineComment unless _tmp
    return _tmp
  end

  # NonNewLine = /[^\r\n]+/
  def _NonNewLine
    _tmp = scan(/\A(?-mix:[^\r\n]+)/)
    set_failed_rule :_NonNewLine unless _tmp
    return _tmp
  end

  # Digits = Digit+:c { c }
  def _Digits

    _save = self.pos
    while true # sequence
      _save1 = self.pos
      _ary = []
      _tmp = apply(:_Digit)
      if _tmp
        _ary << @result
        while true
          _tmp = apply(:_Digit)
          _ary << @result if _tmp
          break unless _tmp
        end
        _tmp = true
        @result = _ary
      else
        self.pos = _save1
      end
      c = @result
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  c ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_Digits unless _tmp
    return _tmp
  end

  # Space = /[ \t]/
  def _Space
    _tmp = scan(/\A(?-mix:[ \t])/)
    set_failed_rule :_Space unless _tmp
    return _tmp
  end

  # EOF = !.
  def _EOF
    _save = self.pos
    _tmp = get_byte
    _tmp = _tmp ? nil : true
    self.pos = _save
    set_failed_rule :_EOF unless _tmp
    return _tmp
  end

  # ElementName = < LowerAlphabetAscii+ > { text }
  def _ElementName

    _save = self.pos
    while true # sequence
      _text_start = self.pos
      _save1 = self.pos
      _tmp = apply(:_LowerAlphabetAscii)
      if _tmp
        while true
          _tmp = apply(:_LowerAlphabetAscii)
          break unless _tmp
        end
        _tmp = true
      else
        self.pos = _save1
      end
      if _tmp
        text = get_text(_text_start)
      end
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  text ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_ElementName unless _tmp
    return _tmp
  end

  # Alphanumeric = %literals.Alphanumeric
  def _Alphanumeric
    _tmp = @_grammar_literals.external_invoke(self, :_Alphanumeric)
    set_failed_rule :_Alphanumeric unless _tmp
    return _tmp
  end

  # AlphanumericAscii = %literals.AlphanumericAscii
  def _AlphanumericAscii
    _tmp = @_grammar_literals.external_invoke(self, :_AlphanumericAscii)
    set_failed_rule :_AlphanumericAscii unless _tmp
    return _tmp
  end

  # LowerAlphabetAscii = %literals.LowerAlphabetAscii
  def _LowerAlphabetAscii
    _tmp = @_grammar_literals.external_invoke(self, :_LowerAlphabetAscii)
    set_failed_rule :_LowerAlphabetAscii unless _tmp
    return _tmp
  end

  # Digit = %literals.Digit
  def _Digit
    _tmp = @_grammar_literals.external_invoke(self, :_Digit)
    set_failed_rule :_Digit unless _tmp
    return _tmp
  end

  # BOM = %literals.BOM
  def _BOM
    _tmp = @_grammar_literals.external_invoke(self, :_BOM)
    set_failed_rule :_BOM unless _tmp
    return _tmp
  end

  # Newline = %literals.Newline
  def _Newline
    _tmp = @_grammar_literals.external_invoke(self, :_Newline)
    set_failed_rule :_Newline unless _tmp
    return _tmp
  end

  # NonAlphanumeric = %literals.NonAlphanumeric
  def _NonAlphanumeric
    _tmp = @_grammar_literals.external_invoke(self, :_NonAlphanumeric)
    set_failed_rule :_NonAlphanumeric unless _tmp
    return _tmp
  end

  # Spacechar = %literals.Spacechar
  def _Spacechar
    _tmp = @_grammar_literals.external_invoke(self, :_Spacechar)
    set_failed_rule :_Spacechar unless _tmp
    return _tmp
  end

  Rules = {}
  Rules[:_root] = rule_info("root", "Start")
  Rules[:_Start] = rule_info("Start", "&. { tagged_section_init } Block* { close_all_tagged_section }")
  Rules[:_Block] = rule_info("Block", "BlankLine* (SinglelineComment:c | Headline:headline | BlockElement:c | Ulist:c | Olist:c | Dlist:c | Paragraph:c)")
  Rules[:_BlankLine] = rule_info("BlankLine", "Newline")
  Rules[:_Headline] = rule_info("Headline", "HeadlinePrefix:level BracketArg?:cmd BraceArg?:label Space* SinglelineContent:caption Newline* { compile_headline(level, cmd, label, caption) }")
  Rules[:_HeadlinePrefix] = rule_info("HeadlinePrefix", "< /={1,5}/ > { text.length }")
  Rules[:_Paragraph] = rule_info("Paragraph", "ParagraphSub+:c { compile_paragraph(c) }")
  Rules[:_ParagraphSub] = rule_info("ParagraphSub", "(InlineElement:c { c } | < ContentText > { text })+:d Newline { d }")
  Rules[:_ContentText] = rule_info("ContentText", "NonInlineElement+:c { c }")
  Rules[:_NonInlineElement] = rule_info("NonInlineElement", "!InlineElement < /[^\\r\\n]/ > { text }")
  Rules[:_BlockElement] = rule_info("BlockElement", "(\"//\" ElementName:symbol BracketArg*:args \"{\" Space* Newline BlockElementContents?:contents \"//}\" Space* Newline {           compile_command(symbol, args, contents) } | \"//\" ElementName:symbol BracketArg*:args Space* Newline)")
  Rules[:_InlineElement] = rule_info("InlineElement", "\"@<\" < /[^>\\r\\n]+/ > {symbol = text} \">\" \"{\" < InlineElementContents? > { contents = text } \"}\" { compile_inline(symbol,contents); }")
  Rules[:_BracketArg] = rule_info("BracketArg", "\"[\" < /([^\\r\\n\\]\\\\]|\\\\[^\\r\\n])*/ > \"]\" { text }")
  Rules[:_BraceArg] = rule_info("BraceArg", "\"{\" < /([^\\r\\n}\\\\]|\\\\[^\\r\\n])*/ > \"}\" { text }")
  Rules[:_BlockElementContents] = rule_info("BlockElementContents", "BlockElementContent+:c")
  Rules[:_BlockElementContent] = rule_info("BlockElementContent", "(SinglelineComment:c | BlockElement:c | BlockElementParagraph:c)")
  Rules[:_BlockElementParagraph] = rule_info("BlockElementParagraph", "&. { @blockElem = [] } BlockElementParagraphSub+:c { @blockElem }")
  Rules[:_BlockElementParagraphSub] = rule_info("BlockElementParagraphSub", "(InlineElement:c { @blockElem << c } | BlockElementContentText:c { @blockElem << c })+ Newline")
  Rules[:_BlockElementContentText] = rule_info("BlockElementContentText", "!\"//}\" !SinglelineComment !BlockElement !Ulist !Olist !Dlist < NonInlineElement+ > { text }")
  Rules[:_InlineElementContents] = rule_info("InlineElementContents", "!\"}\" InlineElementContent+:c { c }")
  Rules[:_InlineElementContent] = rule_info("InlineElementContent", "(InlineElement:c | InlineElementContentText:c)")
  Rules[:_InlineElementContentText] = rule_info("InlineElementContentText", "(!InlineElement /[^\\r\\n}]/)+")
  Rules[:_SinglelineContent] = rule_info("SinglelineContent", "ContentInlines:c (Newline | EOF) { c }")
  Rules[:_ContentInlines] = rule_info("ContentInlines", "ContentInline+:c { c.join }")
  Rules[:_ContentInline] = rule_info("ContentInline", "(InlineElement:c { c } | !Newline < /[^\\r\\n]/ > {text })")
  Rules[:_Ulist] = rule_info("Ulist", "&. { @ulist_elem=[] } (UlistElement | SinglelineComment)+ (Newline | EOF) { compile_ulist(@ulist_elem) }")
  Rules[:_UlistElement] = rule_info("UlistElement", "\" \"+ \"*\"+:level \" \"* SinglelineContent:c { @ulist_elem << [level.size, c] }")
  Rules[:_Olist] = rule_info("Olist", "{ @olist_elem = [] } (OlistElement | SinglelineComment)+:c { compile_olist(@olist_elem) }")
  Rules[:_OlistElement] = rule_info("OlistElement", "\" \"+ < /\\d/+ > { level=text } \".\" Space* SinglelineContent:c {@olist_elem << [level, c] }")
  Rules[:_Dlist] = rule_info("Dlist", "(DlistElement | SinglelineComment):c Dlist?:cc")
  Rules[:_DlistElement] = rule_info("DlistElement", "\" \"* \":\" \" \" Space* SinglelineContent:text DlistElementContent:content")
  Rules[:_DlistElementContent] = rule_info("DlistElementContent", "/[ \\t]+/ SinglelineContent:c")
  Rules[:_SinglelineComment] = rule_info("SinglelineComment", "\"\#@\" < NonNewLine > { comment(text) } Newline")
  Rules[:_NonNewLine] = rule_info("NonNewLine", "/[^\\r\\n]+/")
  Rules[:_Digits] = rule_info("Digits", "Digit+:c { c }")
  Rules[:_Space] = rule_info("Space", "/[ \\t]/")
  Rules[:_EOF] = rule_info("EOF", "!.")
  Rules[:_ElementName] = rule_info("ElementName", "< LowerAlphabetAscii+ > { text }")
  Rules[:_Alphanumeric] = rule_info("Alphanumeric", "%literals.Alphanumeric")
  Rules[:_AlphanumericAscii] = rule_info("AlphanumericAscii", "%literals.AlphanumericAscii")
  Rules[:_LowerAlphabetAscii] = rule_info("LowerAlphabetAscii", "%literals.LowerAlphabetAscii")
  Rules[:_Digit] = rule_info("Digit", "%literals.Digit")
  Rules[:_BOM] = rule_info("BOM", "%literals.BOM")
  Rules[:_Newline] = rule_info("Newline", "%literals.Newline")
  Rules[:_NonAlphanumeric] = rule_info("NonAlphanumeric", "%literals.NonAlphanumeric")
  Rules[:_Spacechar] = rule_info("Spacechar", "%literals.Spacechar")
  # :startdoc:
end
