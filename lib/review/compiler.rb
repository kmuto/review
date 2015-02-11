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
require 'review/node'
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
      @strategy.bind self, @chapter, ReVIEW::Location.new(@chapter.basename, self)
      setup_parser(@chapter.content)
      parse()
      convert_ast
    end

    def convert_ast
      ast = @strategy.ast
      convert_column(ast)
      @strategy.output << ast.to_doc
    end

    def flush_column(new_content)
      if @current_column
        new_content << @current_column
        @current_column = nil
      end
    end

    def convert_column(ast)
      @column_stack = []
      content = ast.content
      new_content = []
      @current_content = new_content
      content.each do |elem|
        if elem.kind_of?(ReVIEW::HeadlineNode) && elem.cmd && elem.cmd.to_doc == "column"
          flush_column(new_content)
          @current_content = []
          @current_column = ReVIEW::ColumnNode.new(elem.compiler, elem.level,
                                                  elem.label, elem.content, @current_content)
          next
        elsif elem.kind_of?(ReVIEW::HeadlineNode) && elem.cmd && elem.cmd.to_doc =~ %r|^/|
          cmd_name = elem.cmd.to_doc[1..-1]
          if cmd_name != "column"
            raise ReVIEW::CompileError, "#{cmd_name} is not opened."
          end
          flush_column(new_content)
          @current_content = new_content
          next
        elsif elem.kind_of?(ReVIEW::HeadlineNode) && @current_column && elem.level <= @current_column.level
          flush_column(new_content)
          @current_content = new_content
        end
        @current_content << elem
      end
      flush_column(new_content)
      ast.content = new_content
      ast
    end

    def compile_text(text)
      @strategy.nofunc_text(text)
    end

    class SyntaxElement
      def initialize(name, type, argc, esc, &block)
        @name = name
        @type = type
        @argc_spec = argc
        @esc_patterns = esc
        @checker = block
      end

      attr_reader :name

      def check_args(args)
        unless @argc_spec === args.size
          raise ReVIEW::CompileError, "wrong # of parameters (block command //#{@name}, expect #{@argc_spec} but #{args.size})"
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

      def parse_args(args)
        if @esc_patterns
          args.map.with_index do |pattern, i|
            if @esc_patterns[i]
              args[i].__send__("to_#{@esc_patterns[i]}")
            else
              args[i].to_doc
            end
          end
        else
          args.map(&:to_doc)
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

    def self.defblock(name, argc, optional = false, esc = nil, &block)
      defsyntax(name, (optional ? :optional : :block), argc, esc, &block)
    end

    def self.defsingle(name, argc, &block)
      defsyntax name, :line, argc, &block
    end

    def self.defsyntax(name, type, argc, esc = nil, &block)
      SYNTAX[name] = SyntaxElement.new(name, type, argc, esc, &block)
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
    defblock :list, 2, nil, [:raw,:doc]
    defblock :emlist, 0..1
    defblock :cmd, 0..1
    defblock :table, 0..2
    defblock :quote, 0
    defblock :image, 2..3, true, [:raw,:doc,:raw]
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


    def compile_column(level, label, caption, content)
      buf = ""
      buf << @strategy.__send__("column_begin", level, label, caption)
      buf << content.to_doc
      buf << @strategy.__send__("column_end", level)
      buf
    end

    def compile_command(name, args, lines, node)
      syntax = syntax_descriptor(name)
      if !syntax || !@strategy.respond_to?(syntax.name)
        error "strategy does not support command: //#{name}"
        compile_unknown_command args, lines
        return
      end
      begin
        syntax.check_args args
      rescue ReVIEW::CompileError => err
        error err.message
        args = ['(NoArgument)'] * syntax.min_argc
      end
      if syntax.block_allowed?
        compile_block(syntax, args, lines, node)
      else
        if lines
          error "block is not allowed for command //#{syntax.name}; ignore"
        end
        compile_single(syntax, args, node)
      end
    end

    def compile_headline(level, tag, label, caption)
      buf = ""
      @headline_indexs ||= [0] ## XXX
      caption ||= ""
      caption.strip!
      index = level - 1
      if @headline_indexs.size > (index + 1)
        @headline_indexs = @headline_indexs[0..index]
      end
      @headline_indexs[index] = 0 if @headline_indexs[index].nil?
      @headline_indexs[index] += 1
      buf << @strategy.headline(level, label, caption)
      buf
    end

    def comment(text)
      @strategy.comment(text)
    end

    def compile_ulist(content)
      buf0 = ""
      level = 0
      content.each do |element|
        current_level, buf = element.level, element.to_doc
        if level == current_level
          buf0 << @strategy.ul_item_end
          # body
          buf0 << @strategy.ul_item_begin([buf])
        elsif level < current_level # down
          level_diff = current_level - level
          level = current_level
          (1..(level_diff - 1)).to_a.reverse.each do |i|
            buf0 << @strategy.ul_begin{i}
            buf0 << @strategy.ul_item_begin([])
          end
          buf0 << @strategy.ul_begin{level}
          buf0 << @strategy.ul_item_begin([buf])
        elsif level > current_level # up
          level_diff = level - current_level
          level = current_level
          (1..level_diff).to_a.reverse.each do |i|
            buf0 << @strategy.ul_item_end
            buf0 << @strategy.ul_end{level + i}
          end
          buf0 << @strategy.ul_item_end
          # body
          buf0 <<@strategy.ul_item_begin([buf])
        end
      end

      (1..level).to_a.reverse.each do |i|
        buf0 << @strategy.ul_item_end
        buf0 << @strategy.ul_end{i}
      end
      buf0
    end

    def compile_olist(content)
      buf0 = ""
      buf0 << @strategy.ol_begin
      content.each do |element|
        ## XXX 1st arg should be String, not Array
        buf0 << @strategy.ol_item(element.to_doc.split(/\n/), element.num)
      end
      buf0 << @strategy.ol_end
      buf0
    end

    def compile_dlist(content)
      buf = ""
      buf << @strategy.dl_begin
      content.each do |element|
        buf << @strategy.dt(element.text.to_doc)
        buf << @strategy.dd(element.content.map{|s| s.to_doc})
      end
      buf << @strategy.dl_end
      buf
    end


    def compile_unknown_command(args, lines)
      @strategy.unknown_command(args, lines)
    end

    def compile_block(syntax, args, lines, node)
      node_name = "node_#{syntax.name}".to_sym
      if @strategy.respond_to?(node_name)
        @strategy.__send__(node_name, node)
      else
        args_conv = syntax.parse_args(args)
        @strategy.__send__(syntax.name, (lines || default_block(syntax)), *args_conv)
      end
    end

    def default_block(syntax)
      if syntax.block_required?
        error "block is required for //#{syntax.name}; use empty block"
      end
      []
    end

    def compile_single(syntax, args, node)
      node_name = "node_#{syntax.name}".to_sym
      if @strategy.respond_to?(node_name)
        @strategy.__send__(node_name, node)
      else
        args_conv = syntax.parse_args(args)
        @strategy.__send__(syntax.name, *args_conv)
      end
    end


    def compile_inline(op, args)
      unless inline_defined?(op)
        raise ReVIEW::CompileError, "no such inline op: #{op}"
      end
      if @strategy.respond_to?("node_inline_#{op}")
        return @strategy.__send__("node_inline_#{op}", args)
      end
      unless @strategy.respond_to?("inline_#{op}")
        raise "strategy does not support inline op: @<#{op}>"
      end
      if !args
        @strategy.__send__("inline_#{op}", "")
      else
        @strategy.__send__("inline_#{op}", *(args.map(&:to_doc)))
      end
    rescue => err
      error err.message
    end

    def compile_paragraph(buf)
      @strategy.paragraph buf
    end

    def compile_raw(builders, content)
      c = @strategy.class.to_s.gsub(/ReVIEW::/, '').gsub(/Builder/, '').downcase
      if !builders || builders.include?(c)
        content.gsub("\\n", "\n")
      else
        ""
      end
    end

    def warn(msg)
      @strategy.warn msg
    end

    def error(msg)
      @strategy.error msg
    end




  # :stopdoc:

  module ::ReVIEW
    class Node; end
    class BlockElementNode < Node
      def initialize(compiler, name, args, content)
        @compiler = compiler
        @name = name
        @args = args
        @content = content
      end
      attr_reader :compiler
      attr_reader :name
      attr_reader :args
      attr_reader :content
    end
    class BraceNode < Node
      def initialize(compiler, content)
        @compiler = compiler
        @content = content
      end
      attr_reader :compiler
      attr_reader :content
    end
    class BracketArgNode < Node
      def initialize(compiler, content)
        @compiler = compiler
        @content = content
      end
      attr_reader :compiler
      attr_reader :content
    end
    class ColumnNode < Node
      def initialize(compiler, level, label, caption, content)
        @compiler = compiler
        @level = level
        @label = label
        @caption = caption
        @content = content
      end
      attr_reader :compiler
      attr_reader :level
      attr_reader :label
      attr_reader :caption
      attr_reader :content
    end
    class DlistNode < Node
      def initialize(compiler, content)
        @compiler = compiler
        @content = content
      end
      attr_reader :compiler
      attr_reader :content
    end
    class DlistElementNode < Node
      def initialize(compiler, text, content)
        @compiler = compiler
        @text = text
        @content = content
      end
      attr_reader :compiler
      attr_reader :text
      attr_reader :content
    end
    class DocumentNode < Node
      def initialize(compiler, content)
        @compiler = compiler
        @content = content
      end
      attr_reader :compiler
      attr_reader :content
    end
    class HeadlineNode < Node
      def initialize(compiler, level, cmd, label, content)
        @compiler = compiler
        @level = level
        @cmd = cmd
        @label = label
        @content = content
      end
      attr_reader :compiler
      attr_reader :level
      attr_reader :cmd
      attr_reader :label
      attr_reader :content
    end
    class InlineElementNode < Node
      def initialize(compiler, symbol, content)
        @compiler = compiler
        @symbol = symbol
        @content = content
      end
      attr_reader :compiler
      attr_reader :symbol
      attr_reader :content
    end
    class InlineElementContentNode < Node
      def initialize(compiler, content)
        @compiler = compiler
        @content = content
      end
      attr_reader :compiler
      attr_reader :content
    end
    class OlistNode < Node
      def initialize(compiler, content)
        @compiler = compiler
        @content = content
      end
      attr_reader :compiler
      attr_reader :content
    end
    class OlistElementNode < Node
      def initialize(compiler, num, content)
        @compiler = compiler
        @num = num
        @content = content
      end
      attr_reader :compiler
      attr_reader :num
      attr_reader :content
    end
    class ParagraphNode < Node
      def initialize(compiler, content)
        @compiler = compiler
        @content = content
      end
      attr_reader :compiler
      attr_reader :content
    end
    class RawNode < Node
      def initialize(compiler, builder, content)
        @compiler = compiler
        @builder = builder
        @content = content
      end
      attr_reader :compiler
      attr_reader :builder
      attr_reader :content
    end
    class SinglelineCommentNode < Node
      def initialize(compiler, content)
        @compiler = compiler
        @content = content
      end
      attr_reader :compiler
      attr_reader :content
    end
    class SinglelineContentNode < Node
      def initialize(compiler, content)
        @compiler = compiler
        @content = content
      end
      attr_reader :compiler
      attr_reader :content
    end
    class TextNode < Node
      def initialize(compiler, content)
        @compiler = compiler
        @content = content
      end
      attr_reader :compiler
      attr_reader :content
    end
    class UlistNode < Node
      def initialize(compiler, content)
        @compiler = compiler
        @content = content
      end
      attr_reader :compiler
      attr_reader :content
    end
    class UlistElementNode < Node
      def initialize(compiler, level, content)
        @compiler = compiler
        @level = level
        @content = content
      end
      attr_reader :compiler
      attr_reader :level
      attr_reader :content
    end
  end
  module ::ReVIEWConstruction
    def block_element(compiler, name, args, content)
      ::ReVIEW::BlockElementNode.new(compiler, name, args, content)
    end
    def brace(compiler, content)
      ::ReVIEW::BraceNode.new(compiler, content)
    end
    def bracket_arg(compiler, content)
      ::ReVIEW::BracketArgNode.new(compiler, content)
    end
    def column(compiler, level, label, caption, content)
      ::ReVIEW::ColumnNode.new(compiler, level, label, caption, content)
    end
    def dlist(compiler, content)
      ::ReVIEW::DlistNode.new(compiler, content)
    end
    def dlist_element(compiler, text, content)
      ::ReVIEW::DlistElementNode.new(compiler, text, content)
    end
    def document(compiler, content)
      ::ReVIEW::DocumentNode.new(compiler, content)
    end
    def headline(compiler, level, cmd, label, content)
      ::ReVIEW::HeadlineNode.new(compiler, level, cmd, label, content)
    end
    def inline_element(compiler, symbol, content)
      ::ReVIEW::InlineElementNode.new(compiler, symbol, content)
    end
    def inline_element_content(compiler, content)
      ::ReVIEW::InlineElementContentNode.new(compiler, content)
    end
    def olist(compiler, content)
      ::ReVIEW::OlistNode.new(compiler, content)
    end
    def olist_element(compiler, num, content)
      ::ReVIEW::OlistElementNode.new(compiler, num, content)
    end
    def paragraph(compiler, content)
      ::ReVIEW::ParagraphNode.new(compiler, content)
    end
    def raw(compiler, builder, content)
      ::ReVIEW::RawNode.new(compiler, builder, content)
    end
    def singleline_comment(compiler, content)
      ::ReVIEW::SinglelineCommentNode.new(compiler, content)
    end
    def singleline_content(compiler, content)
      ::ReVIEW::SinglelineContentNode.new(compiler, content)
    end
    def text(compiler, content)
      ::ReVIEW::TextNode.new(compiler, content)
    end
    def ulist(compiler, content)
      ::ReVIEW::UlistNode.new(compiler, content)
    end
    def ulist_element(compiler, level, content)
      ::ReVIEW::UlistElementNode.new(compiler, level, content)
    end
  end
  include ::ReVIEWConstruction
  def setup_foreign_grammar
    @_grammar_literals = ReVIEW::Compiler::Literals.new(nil)
  end

  # root = Start
  def _root
    _tmp = apply(:_Start)
    set_failed_rule :_root unless _tmp
    return _tmp
  end

  # Start = &. Document:c { @strategy.ast = c }
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
      _tmp = apply(:_Document)
      c = @result
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  @strategy.ast = c ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_Start unless _tmp
    return _tmp
  end

  # Document = Block*:c {document(self, c)}
  def _Document

    _save = self.pos
    while true # sequence
      _ary = []
      while true
        _tmp = apply(:_Block)
        _ary << @result if _tmp
        break unless _tmp
      end
      _tmp = true
      @result = _ary
      c = @result
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; document(self, c); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_Document unless _tmp
    return _tmp
  end

  # Block = BlankLine* (SinglelineComment:c | Headline:c | BlockElement:c | Ulist:c | Olist:c | Dlist:c | Paragraph:c) { c }
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
        c = @result
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
        break
      end
      @result = begin;  c ; end
      _tmp = true
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

  # Headline = HeadlinePrefix:level BracketArg?:cmd BraceArg?:label Space* SinglelineContent?:caption (Newline | EOF) {headline(self, level, cmd, label, caption)}
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
      _save4 = self.pos
      _tmp = apply(:_SinglelineContent)
      @result = nil unless _tmp
      unless _tmp
        _tmp = true
        self.pos = _save4
      end
      caption = @result
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
      @result = begin; headline(self, level, cmd, label, caption); end
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

  # Paragraph = !/\/\/A-Za-z/ ParagraphSub+:c {paragraph(self, c.flatten)}
  def _Paragraph

    _save = self.pos
    while true # sequence
      _save1 = self.pos
      _tmp = scan(/\A(?-mix:\/\/A-Za-z)/)
      _tmp = _tmp ? nil : true
      self.pos = _save1
      unless _tmp
        self.pos = _save
        break
      end
      _save2 = self.pos
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
        self.pos = _save2
      end
      c = @result
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; paragraph(self, c.flatten); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_Paragraph unless _tmp
    return _tmp
  end

  # ParagraphSub = Inline+:d { e=d.flatten } Newline { e }
  def _ParagraphSub

    _save = self.pos
    while true # sequence
      _save1 = self.pos
      _ary = []
      _tmp = apply(:_Inline)
      if _tmp
        _ary << @result
        while true
          _tmp = apply(:_Inline)
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
      @result = begin;  e=d.flatten ; end
      _tmp = true
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_Newline)
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  e ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_ParagraphSub unless _tmp
    return _tmp
  end

  # Inline = (InlineElement | ContentText)
  def _Inline

    _save = self.pos
    while true # choice
      _tmp = apply(:_InlineElement)
      break if _tmp
      self.pos = _save
      _tmp = apply(:_ContentText)
      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_Inline unless _tmp
    return _tmp
  end

  # ContentText = !Headline !SinglelineComment !BlockElement !Ulist !Olist !Dlist NonInlineElement+:c { c }
  def _ContentText

    _save = self.pos
    while true # sequence
      _save1 = self.pos
      _tmp = apply(:_Headline)
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
      _save7 = self.pos
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
        self.pos = _save7
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

  # NonInlineElement = !InlineElement < NonNewLine > {text(self, text)}
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
      _tmp = apply(:_NonNewLine)
      if _tmp
        text = get_text(_text_start)
      end
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; text(self, text); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_NonInlineElement unless _tmp
    return _tmp
  end

  # BlockElement = ("//raw[" RawBlockBuilderSelect?:b RawBlockElementArg*:r1 "]" Space* Newline {raw(self, b, r1)} | !"//raw" "//" ElementName:symbol BracketArg*:args "{" Space* Newline BlockElementContents?:contents "//}" Space* Newline {block_element(self, symbol, args, contents)} | !"//raw" "//" ElementName:symbol BracketArg*:args Space* Newline {block_element(self, symbol, args, nil)})
  def _BlockElement

    _save = self.pos
    while true # choice

      _save1 = self.pos
      while true # sequence
        _tmp = match_string("//raw[")
        unless _tmp
          self.pos = _save1
          break
        end
        _save2 = self.pos
        _tmp = apply(:_RawBlockBuilderSelect)
        @result = nil unless _tmp
        unless _tmp
          _tmp = true
          self.pos = _save2
        end
        b = @result
        unless _tmp
          self.pos = _save1
          break
        end
        _ary = []
        while true
          _tmp = apply(:_RawBlockElementArg)
          _ary << @result if _tmp
          break unless _tmp
        end
        _tmp = true
        @result = _ary
        r1 = @result
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = match_string("]")
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
        @result = begin; raw(self, b, r1); end
        _tmp = true
        unless _tmp
          self.pos = _save1
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save5 = self.pos
      while true # sequence
        _save6 = self.pos
        _tmp = match_string("//raw")
        _tmp = _tmp ? nil : true
        self.pos = _save6
        unless _tmp
          self.pos = _save5
          break
        end
        _tmp = match_string("//")
        unless _tmp
          self.pos = _save5
          break
        end
        _tmp = apply(:_ElementName)
        symbol = @result
        unless _tmp
          self.pos = _save5
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
          self.pos = _save5
          break
        end
        _tmp = match_string("{")
        unless _tmp
          self.pos = _save5
          break
        end
        while true
          _tmp = apply(:_Space)
          break unless _tmp
        end
        _tmp = true
        unless _tmp
          self.pos = _save5
          break
        end
        _tmp = apply(:_Newline)
        unless _tmp
          self.pos = _save5
          break
        end
        _save9 = self.pos
        _tmp = apply(:_BlockElementContents)
        @result = nil unless _tmp
        unless _tmp
          _tmp = true
          self.pos = _save9
        end
        contents = @result
        unless _tmp
          self.pos = _save5
          break
        end
        _tmp = match_string("//}")
        unless _tmp
          self.pos = _save5
          break
        end
        while true
          _tmp = apply(:_Space)
          break unless _tmp
        end
        _tmp = true
        unless _tmp
          self.pos = _save5
          break
        end
        _tmp = apply(:_Newline)
        unless _tmp
          self.pos = _save5
          break
        end
        @result = begin; block_element(self, symbol, args, contents); end
        _tmp = true
        unless _tmp
          self.pos = _save5
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save11 = self.pos
      while true # sequence
        _save12 = self.pos
        _tmp = match_string("//raw")
        _tmp = _tmp ? nil : true
        self.pos = _save12
        unless _tmp
          self.pos = _save11
          break
        end
        _tmp = match_string("//")
        unless _tmp
          self.pos = _save11
          break
        end
        _tmp = apply(:_ElementName)
        symbol = @result
        unless _tmp
          self.pos = _save11
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
          self.pos = _save11
          break
        end
        while true
          _tmp = apply(:_Space)
          break unless _tmp
        end
        _tmp = true
        unless _tmp
          self.pos = _save11
          break
        end
        _tmp = apply(:_Newline)
        unless _tmp
          self.pos = _save11
          break
        end
        @result = begin; block_element(self, symbol, args, nil); end
        _tmp = true
        unless _tmp
          self.pos = _save11
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

  # RawBlockBuilderSelect = "|" Space* RawBlockBuilderSelectSub:c Space* "|" { c }
  def _RawBlockBuilderSelect

    _save = self.pos
    while true # sequence
      _tmp = match_string("|")
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
      _tmp = apply(:_RawBlockBuilderSelectSub)
      c = @result
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
      _tmp = match_string("|")
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

    set_failed_rule :_RawBlockBuilderSelect unless _tmp
    return _tmp
  end

  # RawBlockBuilderSelectSub = (< AlphanumericAscii+ >:c1 Space* "," Space* RawBlockBuilderSelectSub:c2 { [text] + c2 } | < AlphanumericAscii+ >:c1 { [text] })
  def _RawBlockBuilderSelectSub

    _save = self.pos
    while true # choice

      _save1 = self.pos
      while true # sequence
        _text_start = self.pos
        _save2 = self.pos
        _tmp = apply(:_AlphanumericAscii)
        if _tmp
          while true
            _tmp = apply(:_AlphanumericAscii)
            break unless _tmp
          end
          _tmp = true
        else
          self.pos = _save2
        end
        if _tmp
          text = get_text(_text_start)
        end
        c1 = @result
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
        _tmp = match_string(",")
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
        _tmp = apply(:_RawBlockBuilderSelectSub)
        c2 = @result
        unless _tmp
          self.pos = _save1
          break
        end
        @result = begin;  [text] + c2 ; end
        _tmp = true
        unless _tmp
          self.pos = _save1
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save5 = self.pos
      while true # sequence
        _text_start = self.pos
        _save6 = self.pos
        _tmp = apply(:_AlphanumericAscii)
        if _tmp
          while true
            _tmp = apply(:_AlphanumericAscii)
            break unless _tmp
          end
          _tmp = true
        else
          self.pos = _save6
        end
        if _tmp
          text = get_text(_text_start)
        end
        c1 = @result
        unless _tmp
          self.pos = _save5
          break
        end
        @result = begin;  [text] ; end
        _tmp = true
        unless _tmp
          self.pos = _save5
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_RawBlockBuilderSelectSub unless _tmp
    return _tmp
  end

  # RawBlockElementArg = !"]" ("\\]" { "]" } | "\\n" { "\n" } | < NonNewLine > { text })
  def _RawBlockElementArg

    _save = self.pos
    while true # sequence
      _save1 = self.pos
      _tmp = match_string("]")
      _tmp = _tmp ? nil : true
      self.pos = _save1
      unless _tmp
        self.pos = _save
        break
      end

      _save2 = self.pos
      while true # choice

        _save3 = self.pos
        while true # sequence
          _tmp = match_string("\\]")
          unless _tmp
            self.pos = _save3
            break
          end
          @result = begin;  "]" ; end
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
          _tmp = match_string("\\n")
          unless _tmp
            self.pos = _save4
            break
          end
          @result = begin;  "\n" ; end
          _tmp = true
          unless _tmp
            self.pos = _save4
          end
          break
        end # end sequence

        break if _tmp
        self.pos = _save2

        _save5 = self.pos
        while true # sequence
          _text_start = self.pos
          _tmp = apply(:_NonNewLine)
          if _tmp
            text = get_text(_text_start)
          end
          unless _tmp
            self.pos = _save5
            break
          end
          @result = begin;  text ; end
          _tmp = true
          unless _tmp
            self.pos = _save5
          end
          break
        end # end sequence

        break if _tmp
        self.pos = _save2
        break
      end # end choice

      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_RawBlockElementArg unless _tmp
    return _tmp
  end

  # InlineElement = (RawInlineElement:c { c } | !RawInlineElement "@<" InlineElementSymbol:symbol ">" "{" InlineElementContents?:contents "}" {inline_element(self, symbol,contents)})
  def _InlineElement

    _save = self.pos
    while true # choice

      _save1 = self.pos
      while true # sequence
        _tmp = apply(:_RawInlineElement)
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
        _tmp = apply(:_RawInlineElement)
        _tmp = _tmp ? nil : true
        self.pos = _save3
        unless _tmp
          self.pos = _save2
          break
        end
        _tmp = match_string("@<")
        unless _tmp
          self.pos = _save2
          break
        end
        _tmp = apply(:_InlineElementSymbol)
        symbol = @result
        unless _tmp
          self.pos = _save2
          break
        end
        _tmp = match_string(">")
        unless _tmp
          self.pos = _save2
          break
        end
        _tmp = match_string("{")
        unless _tmp
          self.pos = _save2
          break
        end
        _save4 = self.pos
        _tmp = apply(:_InlineElementContents)
        @result = nil unless _tmp
        unless _tmp
          _tmp = true
          self.pos = _save4
        end
        contents = @result
        unless _tmp
          self.pos = _save2
          break
        end
        _tmp = match_string("}")
        unless _tmp
          self.pos = _save2
          break
        end
        @result = begin; inline_element(self, symbol,contents); end
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

    set_failed_rule :_InlineElement unless _tmp
    return _tmp
  end

  # RawInlineElement = "@<raw>{" RawBlockBuilderSelect?:builders RawInlineElementContent+:c "}" {raw(self, builders,c)}
  def _RawInlineElement

    _save = self.pos
    while true # sequence
      _tmp = match_string("@<raw>{")
      unless _tmp
        self.pos = _save
        break
      end
      _save1 = self.pos
      _tmp = apply(:_RawBlockBuilderSelect)
      @result = nil unless _tmp
      unless _tmp
        _tmp = true
        self.pos = _save1
      end
      builders = @result
      unless _tmp
        self.pos = _save
        break
      end
      _save2 = self.pos
      _ary = []
      _tmp = apply(:_RawInlineElementContent)
      if _tmp
        _ary << @result
        while true
          _tmp = apply(:_RawInlineElementContent)
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
      _tmp = match_string("}")
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; raw(self, builders,c); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_RawInlineElement unless _tmp
    return _tmp
  end

  # RawInlineElementContent = ("\\}" { "}" } | < /[^\r\n\}]/ > { text })
  def _RawInlineElementContent

    _save = self.pos
    while true # choice

      _save1 = self.pos
      while true # sequence
        _tmp = match_string("\\}")
        unless _tmp
          self.pos = _save1
          break
        end
        @result = begin;  "}" ; end
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
        _text_start = self.pos
        _tmp = scan(/\A(?-mix:[^\r\n\}])/)
        if _tmp
          text = get_text(_text_start)
        end
        unless _tmp
          self.pos = _save2
          break
        end
        @result = begin;  text ; end
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

    set_failed_rule :_RawInlineElementContent unless _tmp
    return _tmp
  end

  # InlineElementSymbol = < AlphanumericAscii+ > { text }
  def _InlineElementSymbol

    _save = self.pos
    while true # sequence
      _text_start = self.pos
      _save1 = self.pos
      _tmp = apply(:_AlphanumericAscii)
      if _tmp
        while true
          _tmp = apply(:_AlphanumericAscii)
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

    set_failed_rule :_InlineElementSymbol unless _tmp
    return _tmp
  end

  # InlineElementContents = !"}" InlineElementContentsSub:c { c }
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
      _tmp = apply(:_InlineElementContentsSub)
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

  # InlineElementContentsSub = !"}" (InlineElementContent:c1 Space* "," Space* InlineElementContentsSub:c2 {  [c1]+c2 } | InlineElementContent:c1 { [c1] })
  def _InlineElementContentsSub

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
      while true # choice

        _save3 = self.pos
        while true # sequence
          _tmp = apply(:_InlineElementContent)
          c1 = @result
          unless _tmp
            self.pos = _save3
            break
          end
          while true
            _tmp = apply(:_Space)
            break unless _tmp
          end
          _tmp = true
          unless _tmp
            self.pos = _save3
            break
          end
          _tmp = match_string(",")
          unless _tmp
            self.pos = _save3
            break
          end
          while true
            _tmp = apply(:_Space)
            break unless _tmp
          end
          _tmp = true
          unless _tmp
            self.pos = _save3
            break
          end
          _tmp = apply(:_InlineElementContentsSub)
          c2 = @result
          unless _tmp
            self.pos = _save3
            break
          end
          @result = begin;   [c1]+c2 ; end
          _tmp = true
          unless _tmp
            self.pos = _save3
          end
          break
        end # end sequence

        break if _tmp
        self.pos = _save2

        _save6 = self.pos
        while true # sequence
          _tmp = apply(:_InlineElementContent)
          c1 = @result
          unless _tmp
            self.pos = _save6
            break
          end
          @result = begin;  [c1] ; end
          _tmp = true
          unless _tmp
            self.pos = _save6
          end
          break
        end # end sequence

        break if _tmp
        self.pos = _save2
        break
      end # end choice

      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_InlineElementContentsSub unless _tmp
    return _tmp
  end

  # InlineElementContent = InlineElementContentSub+:d { d }
  def _InlineElementContent

    _save = self.pos
    while true # sequence
      _save1 = self.pos
      _ary = []
      _tmp = apply(:_InlineElementContentSub)
      if _tmp
        _ary << @result
        while true
          _tmp = apply(:_InlineElementContentSub)
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
      @result = begin;  d ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_InlineElementContent unless _tmp
    return _tmp
  end

  # InlineElementContentSub = (InlineElement:c { c } | !InlineElement InlineElementContentText+:content {inline_element_content(self, content)})
  def _InlineElementContentSub

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
        _tmp = apply(:_InlineElement)
        _tmp = _tmp ? nil : true
        self.pos = _save3
        unless _tmp
          self.pos = _save2
          break
        end
        _save4 = self.pos
        _ary = []
        _tmp = apply(:_InlineElementContentText)
        if _tmp
          _ary << @result
          while true
            _tmp = apply(:_InlineElementContentText)
            _ary << @result if _tmp
            break unless _tmp
          end
          _tmp = true
          @result = _ary
        else
          self.pos = _save4
        end
        content = @result
        unless _tmp
          self.pos = _save2
          break
        end
        @result = begin; inline_element_content(self, content); end
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

    set_failed_rule :_InlineElementContentSub unless _tmp
    return _tmp
  end

  # InlineElementContentText = ("\\}" {text(self, "}")} | "\\," {text(self, ",")} | "\\\\" {text(self, "\\" )} | "\\" {text(self, "\\" )} | !InlineElement < /[^\r\n\\},]/ > {text(self,text)})
  def _InlineElementContentText

    _save = self.pos
    while true # choice

      _save1 = self.pos
      while true # sequence
        _tmp = match_string("\\}")
        unless _tmp
          self.pos = _save1
          break
        end
        @result = begin; text(self, "}"); end
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
        _tmp = match_string("\\,")
        unless _tmp
          self.pos = _save2
          break
        end
        @result = begin; text(self, ","); end
        _tmp = true
        unless _tmp
          self.pos = _save2
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save3 = self.pos
      while true # sequence
        _tmp = match_string("\\\\")
        unless _tmp
          self.pos = _save3
          break
        end
        @result = begin; text(self, "\\" ); end
        _tmp = true
        unless _tmp
          self.pos = _save3
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save4 = self.pos
      while true # sequence
        _tmp = match_string("\\")
        unless _tmp
          self.pos = _save4
          break
        end
        @result = begin; text(self, "\\" ); end
        _tmp = true
        unless _tmp
          self.pos = _save4
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save5 = self.pos
      while true # sequence
        _save6 = self.pos
        _tmp = apply(:_InlineElement)
        _tmp = _tmp ? nil : true
        self.pos = _save6
        unless _tmp
          self.pos = _save5
          break
        end
        _text_start = self.pos
        _tmp = scan(/\A(?-mix:[^\r\n\\},])/)
        if _tmp
          text = get_text(_text_start)
        end
        unless _tmp
          self.pos = _save5
          break
        end
        @result = begin; text(self,text); end
        _tmp = true
        unless _tmp
          self.pos = _save5
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_InlineElementContentText unless _tmp
    return _tmp
  end

  # BracketArg = "[" BracketArgContentInline*:content "]" {bracket_arg(self, content)}
  def _BracketArg

    _save = self.pos
    while true # sequence
      _tmp = match_string("[")
      unless _tmp
        self.pos = _save
        break
      end
      _ary = []
      while true
        _tmp = apply(:_BracketArgContentInline)
        _ary << @result if _tmp
        break unless _tmp
      end
      _tmp = true
      @result = _ary
      content = @result
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = match_string("]")
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; bracket_arg(self, content); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_BracketArg unless _tmp
    return _tmp
  end

  # BracketArgContentInline = (InlineElement:c { c } | "\\]" {text(self, "]")} | "\\\\" {text(self, "\\")} | < /[^\r\n\]]/ > {text(self, text)})
  def _BracketArgContentInline

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
        _tmp = match_string("\\]")
        unless _tmp
          self.pos = _save2
          break
        end
        @result = begin; text(self, "]"); end
        _tmp = true
        unless _tmp
          self.pos = _save2
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save3 = self.pos
      while true # sequence
        _tmp = match_string("\\\\")
        unless _tmp
          self.pos = _save3
          break
        end
        @result = begin; text(self, "\\"); end
        _tmp = true
        unless _tmp
          self.pos = _save3
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save4 = self.pos
      while true # sequence
        _text_start = self.pos
        _tmp = scan(/\A(?-mix:[^\r\n\]])/)
        if _tmp
          text = get_text(_text_start)
        end
        unless _tmp
          self.pos = _save4
          break
        end
        @result = begin; text(self, text); end
        _tmp = true
        unless _tmp
          self.pos = _save4
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_BracketArgContentInline unless _tmp
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

  # BlockElementContents = BlockElementContent+:c { c }
  def _BlockElementContents

    _save = self.pos
    while true # sequence
      _save1 = self.pos
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

    set_failed_rule :_BlockElementContents unless _tmp
    return _tmp
  end

  # BlockElementContent = (SinglelineComment:c {singleline_content(self, c)} | BlockElement:c {singleline_content(self, c)} | BlockElementParagraph:c {singleline_content(self, c)} | Newline:c {singleline_content(self, "")})
  def _BlockElementContent

    _save = self.pos
    while true # choice

      _save1 = self.pos
      while true # sequence
        _tmp = apply(:_SinglelineComment)
        c = @result
        unless _tmp
          self.pos = _save1
          break
        end
        @result = begin; singleline_content(self, c); end
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
        _tmp = apply(:_BlockElement)
        c = @result
        unless _tmp
          self.pos = _save2
          break
        end
        @result = begin; singleline_content(self, c); end
        _tmp = true
        unless _tmp
          self.pos = _save2
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save3 = self.pos
      while true # sequence
        _tmp = apply(:_BlockElementParagraph)
        c = @result
        unless _tmp
          self.pos = _save3
          break
        end
        @result = begin; singleline_content(self, c); end
        _tmp = true
        unless _tmp
          self.pos = _save3
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save4 = self.pos
      while true # sequence
        _tmp = apply(:_Newline)
        c = @result
        unless _tmp
          self.pos = _save4
          break
        end
        @result = begin; singleline_content(self, ""); end
        _tmp = true
        unless _tmp
          self.pos = _save4
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_BlockElementContent unless _tmp
    return _tmp
  end

  # BlockElementParagraph = BlockElementParagraphSub+:c Newline { c.flatten }
  def _BlockElementParagraph

    _save = self.pos
    while true # sequence
      _save1 = self.pos
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
        self.pos = _save1
      end
      c = @result
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_Newline)
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  c.flatten ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_BlockElementParagraph unless _tmp
    return _tmp
  end

  # BlockElementParagraphSub = (InlineElement:c | BlockElementContentText:c)
  def _BlockElementParagraphSub

    _save = self.pos
    while true # choice
      _tmp = apply(:_InlineElement)
      c = @result
      break if _tmp
      self.pos = _save
      _tmp = apply(:_BlockElementContentText)
      c = @result
      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_BlockElementParagraphSub unless _tmp
    return _tmp
  end

  # BlockElementContentText = !"//}" !SinglelineComment !BlockElement !Ulist !Olist !Dlist NonInlineElement+:c { c }
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
      _save7 = self.pos
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
        self.pos = _save7
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

    set_failed_rule :_BlockElementContentText unless _tmp
    return _tmp
  end

  # SinglelineContent = ContentInlines:c {singleline_content(self,c)}
  def _SinglelineContent

    _save = self.pos
    while true # sequence
      _tmp = apply(:_ContentInlines)
      c = @result
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; singleline_content(self,c); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_SinglelineContent unless _tmp
    return _tmp
  end

  # ContentInlines = ContentInline+:c { c }
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
      @result = begin;  c ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_ContentInlines unless _tmp
    return _tmp
  end

  # ContentInline = (InlineElement:c { c } | NonInlineElement)
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
      _tmp = apply(:_NonInlineElement)
      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_ContentInline unless _tmp
    return _tmp
  end

  # Ulist = &. { @ulist_elem=[] } UlistElement (UlistElement | UlistContLine | SinglelineComment)+ {ulist(self, @ulist_elem)}
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
      _tmp = apply(:_UlistElement)
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
        _tmp = apply(:_UlistContLine)
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
            _tmp = apply(:_UlistContLine)
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
      @result = begin; ulist(self, @ulist_elem); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_Ulist unless _tmp
    return _tmp
  end

  # UlistElement = " "+ "*"+:level " "* SinglelineContent:c (EOF | Newline) { @ulist_elem << ::ReVIEW::UlistElementNode.new(self, level.size, [c]) }
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

      _save4 = self.pos
      while true # choice
        _tmp = apply(:_EOF)
        break if _tmp
        self.pos = _save4
        _tmp = apply(:_Newline)
        break if _tmp
        self.pos = _save4
        break
      end # end choice

      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  @ulist_elem << ::ReVIEW::UlistElementNode.new(self, level.size, [c]) ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_UlistElement unless _tmp
    return _tmp
  end

  # UlistContLine = " " " "+ !"*" SinglelineContent:c (EOF | Newline) {  @ulist_elem[-1].concat(c) }
  def _UlistContLine

    _save = self.pos
    while true # sequence
      _tmp = match_string(" ")
      unless _tmp
        self.pos = _save
        break
      end
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
      _tmp = match_string("*")
      _tmp = _tmp ? nil : true
      self.pos = _save2
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

      _save3 = self.pos
      while true # choice
        _tmp = apply(:_EOF)
        break if _tmp
        self.pos = _save3
        _tmp = apply(:_Newline)
        break if _tmp
        self.pos = _save3
        break
      end # end choice

      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;   @ulist_elem[-1].concat(c) ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_UlistContLine unless _tmp
    return _tmp
  end

  # Olist = { @olist_elem = [] } (OlistElement | SinglelineComment)+:c {olist(self, @olist_elem)}
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
      @result = begin; olist(self, @olist_elem); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_Olist unless _tmp
    return _tmp
  end

  # OlistElement = " "+ < /\d/+ > { num=text } "." Space* SinglelineContent:c (EOF | Newline) {@olist_elem << ReVIEW::OlistElementNode.new(self, num.to_i, [c]) }
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
      @result = begin;  num=text ; end
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

      _save4 = self.pos
      while true # choice
        _tmp = apply(:_EOF)
        break if _tmp
        self.pos = _save4
        _tmp = apply(:_Newline)
        break if _tmp
        self.pos = _save4
        break
      end # end choice

      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; @olist_elem << ReVIEW::OlistElementNode.new(self, num.to_i, [c]) ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_OlistElement unless _tmp
    return _tmp
  end

  # Dlist = (DlistElement | SinglelineComment)+:content {dlist(self, content)}
  def _Dlist

    _save = self.pos
    while true # sequence
      _save1 = self.pos
      _ary = []

      _save2 = self.pos
      while true # choice
        _tmp = apply(:_DlistElement)
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
            _tmp = apply(:_DlistElement)
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
      content = @result
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; dlist(self, content); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_Dlist unless _tmp
    return _tmp
  end

  # DlistElement = " "* ":" " " Space* SinglelineContent:text Newline DlistElementContent+:content {dlist_element(self, text, content)}
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
      _tmp = apply(:_Newline)
      unless _tmp
        self.pos = _save
        break
      end
      _save3 = self.pos
      _ary = []
      _tmp = apply(:_DlistElementContent)
      if _tmp
        _ary << @result
        while true
          _tmp = apply(:_DlistElementContent)
          _ary << @result if _tmp
          break unless _tmp
        end
        _tmp = true
        @result = _ary
      else
        self.pos = _save3
      end
      content = @result
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; dlist_element(self, text, content); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_DlistElement unless _tmp
    return _tmp
  end

  # DlistElementContent = /[ \t]+/ SinglelineContent:c Newline:n { c }
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
        break
      end
      _tmp = apply(:_Newline)
      n = @result
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

    set_failed_rule :_DlistElementContent unless _tmp
    return _tmp
  end

  # SinglelineComment = "#@" < NonNewLine+ > Newline {singleline_comment(self, text)}
  def _SinglelineComment

    _save = self.pos
    while true # sequence
      _tmp = match_string("\#@")
      unless _tmp
        self.pos = _save
        break
      end
      _text_start = self.pos
      _save1 = self.pos
      _tmp = apply(:_NonNewLine)
      if _tmp
        while true
          _tmp = apply(:_NonNewLine)
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
      _tmp = apply(:_Newline)
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; singleline_comment(self, text); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_SinglelineComment unless _tmp
    return _tmp
  end

  # NonNewLine = /[^\r\n]/
  def _NonNewLine
    _tmp = scan(/\A(?-mix:[^\r\n])/)
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
  Rules[:_Start] = rule_info("Start", "&. Document:c { @strategy.ast = c }")
  Rules[:_Document] = rule_info("Document", "Block*:c {document(self, c)}")
  Rules[:_Block] = rule_info("Block", "BlankLine* (SinglelineComment:c | Headline:c | BlockElement:c | Ulist:c | Olist:c | Dlist:c | Paragraph:c) { c }")
  Rules[:_BlankLine] = rule_info("BlankLine", "Newline")
  Rules[:_Headline] = rule_info("Headline", "HeadlinePrefix:level BracketArg?:cmd BraceArg?:label Space* SinglelineContent?:caption (Newline | EOF) {headline(self, level, cmd, label, caption)}")
  Rules[:_HeadlinePrefix] = rule_info("HeadlinePrefix", "< /={1,5}/ > { text.length }")
  Rules[:_Paragraph] = rule_info("Paragraph", "!/\\/\\/A-Za-z/ ParagraphSub+:c {paragraph(self, c.flatten)}")
  Rules[:_ParagraphSub] = rule_info("ParagraphSub", "Inline+:d { e=d.flatten } Newline { e }")
  Rules[:_Inline] = rule_info("Inline", "(InlineElement | ContentText)")
  Rules[:_ContentText] = rule_info("ContentText", "!Headline !SinglelineComment !BlockElement !Ulist !Olist !Dlist NonInlineElement+:c { c }")
  Rules[:_NonInlineElement] = rule_info("NonInlineElement", "!InlineElement < NonNewLine > {text(self, text)}")
  Rules[:_BlockElement] = rule_info("BlockElement", "(\"//raw[\" RawBlockBuilderSelect?:b RawBlockElementArg*:r1 \"]\" Space* Newline {raw(self, b, r1)} | !\"//raw\" \"//\" ElementName:symbol BracketArg*:args \"{\" Space* Newline BlockElementContents?:contents \"//}\" Space* Newline {block_element(self, symbol, args, contents)} | !\"//raw\" \"//\" ElementName:symbol BracketArg*:args Space* Newline {block_element(self, symbol, args, nil)})")
  Rules[:_RawBlockBuilderSelect] = rule_info("RawBlockBuilderSelect", "\"|\" Space* RawBlockBuilderSelectSub:c Space* \"|\" { c }")
  Rules[:_RawBlockBuilderSelectSub] = rule_info("RawBlockBuilderSelectSub", "(< AlphanumericAscii+ >:c1 Space* \",\" Space* RawBlockBuilderSelectSub:c2 { [text] + c2 } | < AlphanumericAscii+ >:c1 { [text] })")
  Rules[:_RawBlockElementArg] = rule_info("RawBlockElementArg", "!\"]\" (\"\\\\]\" { \"]\" } | \"\\\\n\" { \"\\n\" } | < NonNewLine > { text })")
  Rules[:_InlineElement] = rule_info("InlineElement", "(RawInlineElement:c { c } | !RawInlineElement \"@<\" InlineElementSymbol:symbol \">\" \"{\" InlineElementContents?:contents \"}\" {inline_element(self, symbol,contents)})")
  Rules[:_RawInlineElement] = rule_info("RawInlineElement", "\"@<raw>{\" RawBlockBuilderSelect?:builders RawInlineElementContent+:c \"}\" {raw(self, builders,c)}")
  Rules[:_RawInlineElementContent] = rule_info("RawInlineElementContent", "(\"\\\\}\" { \"}\" } | < /[^\\r\\n\\}]/ > { text })")
  Rules[:_InlineElementSymbol] = rule_info("InlineElementSymbol", "< AlphanumericAscii+ > { text }")
  Rules[:_InlineElementContents] = rule_info("InlineElementContents", "!\"}\" InlineElementContentsSub:c { c }")
  Rules[:_InlineElementContentsSub] = rule_info("InlineElementContentsSub", "!\"}\" (InlineElementContent:c1 Space* \",\" Space* InlineElementContentsSub:c2 {  [c1]+c2 } | InlineElementContent:c1 { [c1] })")
  Rules[:_InlineElementContent] = rule_info("InlineElementContent", "InlineElementContentSub+:d { d }")
  Rules[:_InlineElementContentSub] = rule_info("InlineElementContentSub", "(InlineElement:c { c } | !InlineElement InlineElementContentText+:content {inline_element_content(self, content)})")
  Rules[:_InlineElementContentText] = rule_info("InlineElementContentText", "(\"\\\\}\" {text(self, \"}\")} | \"\\\\,\" {text(self, \",\")} | \"\\\\\\\\\" {text(self, \"\\\\\" )} | \"\\\\\" {text(self, \"\\\\\" )} | !InlineElement < /[^\\r\\n\\\\},]/ > {text(self,text)})")
  Rules[:_BracketArg] = rule_info("BracketArg", "\"[\" BracketArgContentInline*:content \"]\" {bracket_arg(self, content)}")
  Rules[:_BracketArgContentInline] = rule_info("BracketArgContentInline", "(InlineElement:c { c } | \"\\\\]\" {text(self, \"]\")} | \"\\\\\\\\\" {text(self, \"\\\\\")} | < /[^\\r\\n\\]]/ > {text(self, text)})")
  Rules[:_BraceArg] = rule_info("BraceArg", "\"{\" < /([^\\r\\n}\\\\]|\\\\[^\\r\\n])*/ > \"}\" { text }")
  Rules[:_BlockElementContents] = rule_info("BlockElementContents", "BlockElementContent+:c { c }")
  Rules[:_BlockElementContent] = rule_info("BlockElementContent", "(SinglelineComment:c {singleline_content(self, c)} | BlockElement:c {singleline_content(self, c)} | BlockElementParagraph:c {singleline_content(self, c)} | Newline:c {singleline_content(self, \"\")})")
  Rules[:_BlockElementParagraph] = rule_info("BlockElementParagraph", "BlockElementParagraphSub+:c Newline { c.flatten }")
  Rules[:_BlockElementParagraphSub] = rule_info("BlockElementParagraphSub", "(InlineElement:c | BlockElementContentText:c)")
  Rules[:_BlockElementContentText] = rule_info("BlockElementContentText", "!\"//}\" !SinglelineComment !BlockElement !Ulist !Olist !Dlist NonInlineElement+:c { c }")
  Rules[:_SinglelineContent] = rule_info("SinglelineContent", "ContentInlines:c {singleline_content(self,c)}")
  Rules[:_ContentInlines] = rule_info("ContentInlines", "ContentInline+:c { c }")
  Rules[:_ContentInline] = rule_info("ContentInline", "(InlineElement:c { c } | NonInlineElement)")
  Rules[:_Ulist] = rule_info("Ulist", "&. { @ulist_elem=[] } UlistElement (UlistElement | UlistContLine | SinglelineComment)+ {ulist(self, @ulist_elem)}")
  Rules[:_UlistElement] = rule_info("UlistElement", "\" \"+ \"*\"+:level \" \"* SinglelineContent:c (EOF | Newline) { @ulist_elem << ::ReVIEW::UlistElementNode.new(self, level.size, [c]) }")
  Rules[:_UlistContLine] = rule_info("UlistContLine", "\" \" \" \"+ !\"*\" SinglelineContent:c (EOF | Newline) {  @ulist_elem[-1].concat(c) }")
  Rules[:_Olist] = rule_info("Olist", "{ @olist_elem = [] } (OlistElement | SinglelineComment)+:c {olist(self, @olist_elem)}")
  Rules[:_OlistElement] = rule_info("OlistElement", "\" \"+ < /\\d/+ > { num=text } \".\" Space* SinglelineContent:c (EOF | Newline) {@olist_elem << ReVIEW::OlistElementNode.new(self, num.to_i, [c]) }")
  Rules[:_Dlist] = rule_info("Dlist", "(DlistElement | SinglelineComment)+:content {dlist(self, content)}")
  Rules[:_DlistElement] = rule_info("DlistElement", "\" \"* \":\" \" \" Space* SinglelineContent:text Newline DlistElementContent+:content {dlist_element(self, text, content)}")
  Rules[:_DlistElementContent] = rule_info("DlistElementContent", "/[ \\t]+/ SinglelineContent:c Newline:n { c }")
  Rules[:_SinglelineComment] = rule_info("SinglelineComment", "\"\#@\" < NonNewLine+ > Newline {singleline_comment(self, text)}")
  Rules[:_NonNewLine] = rule_info("NonNewLine", "/[^\\r\\n]/")
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
