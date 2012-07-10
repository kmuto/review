#
# $Id: preprocessor.rb 4250 2009-05-24 14:03:01Z aamine $
#
# Copyright (c) 2002-2009 Minero Aoki
# Copyright (c) 2010 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
#

require 'review/textutils'
require 'review/exception'
require 'nkf'

module ReVIEW

  module ErrorUtils

    def init_ErrorUtils(f)
      @errutils_file = f
      @errutils_err = false
    end

    def warn(msg)
      if @param["outencoding"] =~ /^EUC$/
        msg = NKF.nkf("-W -e", msg)
      elsif @param["outencoding"] =~ /^SJIS$/
        msg = NKF.nkf("-W -s", msg)
      elsif @param["outencoding"] =~ /^JIS$/
        msg = NKF.nkf("-W -j", msg)
      end
      $stderr.puts "#{location()}: warning: #{msg}"
    end

    def error(msg)
      if @param["outencoding"] =~ /^EUC$/
        msg = NKF.nkf("-W -e", msg)
      elsif @param["outencoding"] =~ /^SJIS$/
        msg = NKF.nkf("-W -s", msg)
      elsif @param["outencoding"] =~ /^JIS$/
        msg = NKF.nkf("-W -j", msg)
      end
      @errutils_err = true
      raise ApplicationError, "#{location()}: #{msg}"
    end

    def location
      "#{filename()}:#{lineno()}"
    end

    def filename
      @errutils_file.path
    end

    def lineno
      @errutils_file.lineno
    end

  end


  class Preprocessor

    include ErrorUtils

    def Preprocessor.strip(f)
      buf = ''
      Strip.new(f).each do |line|
        buf << line.rstrip << "\n"
      end
      buf
    end

    class Strip
      def initialize(f)
        @f = f
      end

      def pos;@f.pos end
      def pos= v;@f.pos = v end

      def path
        @f.path
      end

      def lineno
        @f.lineno
      end

      def gets
        while line = @f.gets
          return line unless /\A\#@/ =~ line
        end
        nil
      end

      def each
        @f.each do |line|
          yield line unless /\A\#@/ =~ line
        end
      end
    end

    def initialize(repo, param)
      @repository = repo
      @param = param
    end

    def process(inf, outf)
      init_ErrorUtils inf
      @f = outf
      begin
        preproc inf
      rescue Errno::ENOENT => err
        error err.message
      end
    end

    private

    TYPES = %w( file range )

    def preproc(f)
      init_vars
      while line = f.gets
        case line
        when /\A\#@\#/, /\A\#\#\#\#/
          @f.print line

        when /\A\#@defvar/
          @f.print line
          direc = parse_directive(line, 2)
          defvar(*direc.args)

        when /\A\#@mapoutput/
          direc = parse_directive(line, 1, 'stderr')
          @f.print line
          get_output(expand(direc.arg), direc['stderr']).each do |out|
            @f.print out.string
          end
          skip_list f
        
        when /\A\#@mapfile/
          direc = parse_directive(line, 1, 'eval')
          path = expand(direc.arg)
          ent = @repository.fetch_file(path)
          ent = evaluate(path, ent) if direc['eval']
          replace_block f, line, ent, false   # FIXME: turn off lineno: tmp

        when /\A\#@map(?:range)?/
          direc = parse_directive(line, 2, 'unindent')
          path = expand(direc.args[0])
          ent = @repository.fetch_range(path, direc.args[1]) or
                  error "unknown range: #{path}: #{direc.args[1]}"
          ent = (direc['unindent'] ? unindent(ent, direc['unindent']) : ent)
          replace_block f, line, ent, false   # FIXME: turn off lineno: tmp

        when /\A\#@end/
          error 'unbaranced #@end'

        when /\A\#@/
          op = line.slice(/@(\w+)/, 1)
          #error "unkown directive: #{line.strip}" unless known_directive?(op)
          warn "unkown directive: #{line.strip}" unless known_directive?(op)
          @f.print line
        
        when /\A\s*\z/   # empty line
          @f.puts
        else
          @f.print line
        end
      end
    end

    private

    KNOWN_DIRECTIVES = %w( require provide warn ok )

    def known_directive?(op)
      KNOWN_DIRECTIVES.index(op)
    end

    def convert_outencoding(*s)
      ine = ""
      if @param["inencoding"] =~ /^EUC$/i
        ine = "-E,"
      elsif @param["inencoding"] =~ /^SJIS$/i
        ine = "-S,"
      elsif @param["inencoding"] =~ /^JIS$/i
        ine = "-J,"
      elsif @param["inencoding"] =~ /^UTF\-8$/i
        ine = "-W,"
      end

      if @param["outencoding"] =~ /^EUC$/i
        NKF.nkf("#{ine} -m0x -e", *s)
      elsif @param["outencoding"] =~ /^SJIS$/i
        NKF.nkf("#{ine} -m0x -s", *s)
      elsif @param["outencoding"] =~ /^JIS$/i
        NKF.nkf("#{ine} -m0x -j", *s)
      else
        NKF.nkf("#{ine} -m0x -w", *s)
      end
    end

    def replace_block(f, directive_line, newlines, with_lineno)
      @f.print directive_line
      newlines.each do |line|
        print_number line.number if with_lineno
        @f.print convert_outencoding(line.string)
      end
      skip_list f
    end

    def print_number(num)
      @f.printf '%4s  ', (num ? num.to_s : '')
    end

    def skip_list(f)
      begline = f.lineno
      while line = f.gets
        case line
        when %r[\A\#@end]
          @f.print line
          return
        when %r[\A//\}]
          warn '//} seen in list'
          @f.print line
          return
        when %r[\A\#@\w]
          warn "#{line.slice(/\A\#@\w+/)} seen in list"
          @f.print line
        when %r[\A\#@]
          @f.print line
        end
      end
      error "list reached end of file (beginning line = #{begline})"
    end

    class Directive
      def initialize(op, args, opts)
        @op = op
	@args = args
	@opts = opts
      end

      attr_reader :op
      attr_reader :args
      attr_reader :opts

      def arg
        @args.first
      end

      def opt
        @opts.first
      end

      def [](key)
        @opts[key]
      end
    end

    def parse_directive(line, argc, *optdecl)
      m = /\A\#@(\w+)\((.*?)\)(?:\[(.*?)\])?\z/.match(line.strip) or
              error "wrong directive: #{line.strip}"
      op = m[1]
      args = m[2].split(/,\s*/)
      opts = parse_optargs(m[3])
      return if argc == 0 and args.empty?
      if argc == -1
        # Any number of arguments are allowed.
      elsif args.size != argc
        error "wrong arg size"
      end
      if opts
        wrong_opts = opts.keys - optdecl
        unless wrong_opts.empty?
          error "wrong option: #{wrong_opts.keys.join(' ')}"
        end
      end
      Directive.new(op, args, opts || {})
    end

    def parse_optargs(str)
      return nil unless str
      table = {}
      str.split(/,\s*/).each do |a|
        name, spec = a.split(/=/, 2)
        table[name] = optarg_value(spec)
      end
      table
    end

    def optarg_value(spec)
      case spec
      when 'true'  then true      # [name=true]
      when 'false' then false     # [name=false]
      when 'nil'   then nil       # [name=nil]
      when nil     then true      # [name]
      when /^\d+$/ then $&.to_i   # [name=8]
      else                        # [name=val]
        spec
      end
    end

    def init_vars
      @vartable = {}
    end

    def defvar(name, value)
      @vartable[name] = value
    end

    def expand(str)
      str.gsub(/\$\w+/) {|name|
        s = @vartable[name.sub('$', '')]
        s ? expand(s) : name
      }
    end

    def unindent(chunk, n)
      n = minimum_indent(chunk) unless n.kind_of?(Integer)
      re = /\A#{' ' * n}/
      chunk.map {|line| line.edit {|s| s.sub(re,'') } }
    end

    INF_INDENT = 9999

    def minimum_indent(chunk)
      n = chunk.map {|line| line.empty? ? INF_INDENT : line.num_indent }.min
      n == INF_INDENT ? 0 : n
    end

    def check_ruby_syntax(rbfile)
      status = spawn {
        exec("ruby -c #{rbfile} 2>&1 > /dev/null")
      }
      error "syntax check failed: #{rbfile}" unless status.exitstatus == 0
    end

    def spawn
      pid, status = *Process.waitpid2(fork { yield })
      status
    end

    def evaluate(path, chunk)
      outputs = get_output("ruby #{path}", false).split(/\n/).map {|s| s.strip }
      chunk.map {|line|
        if /\# \$\d+/ =~ line.string
          # map result into source.
          line.edit {|s|
            s.sub(/\$(\d+)/) { outputs[$1.to_i - 1] }
          }
        else
          line
        end
      }
    end

    require 'open3'

    def get_output(cmd, use_stderr)
      out = err = nil
      Open3.popen3(cmd) {|stdin, stdout, stderr|
        out = stdout.readlines
        if use_stderr
          out.concat stderr.readlines
        else
          err = stderr.readlines
        end
      }
      if err and not err.empty?
        $stderr.puts "[unexpected stderr message]"
        err.each do |line|
          $stderr.print line
        end
        error "get_output: got unexpected output"
      end
      num = 0
      out.map {|line| Line.new(num += 1, line) }
    end

  end


  class Line
    def initialize(number, string)
      @number = number
      @string = string
    end

    attr_reader :number
    attr_reader :string
    alias to_s string

    def edit
      self.class.new(@number, yield(@string))
    end

    def empty?
      @string.strip.empty?
    end

    def num_indent
      @string.slice(/\A\s*/).size
    end
  end


  class Repository

    include TextUtils
    include ErrorUtils

    def initialize(param)
      @repository = {}
      @param = param
    end

    def fetch_file(file)
      file_descripter(file)['file']
    end

    def fetch_range(file, name)
      fetch(file, 'range', name)
    end

    def fetch(file, type, name)
      table = file_descripter(file)[type] or return nil
      table[name]
    end

    private

    def file_descripter(fname)
      return @repository[fname] if @repository[fname]

      @repository[fname] = git?(fname) ? parse_git_blob(fname) : parse_file(fname)
    end

    def git?(fname)
      fname =~ /\Agit\|/
    end

    def parse_git_blob(g_obj)
      IO.popen('git show ' + g_obj.sub(/\Agit\|/, ''), 'r') do |f|
        init_ErrorUtils f
        return _parse_file(f)
      end
    end

    def parse_file(fname)
      File.open(fname) {|f|
        init_ErrorUtils f
        return _parse_file(f)
      }
    end

    def _parse_file(f)
      whole = []
      repo = {'file' => whole}
      curr = {'WHOLE' => whole}
      lineno = 1
      yacchack = false   # remove ';'-only lines.
      opened = [['(not opened)', '(not opened)']] * 3

      f.each do |line|
        case line
        when /(?:\A\#@|\#@@)([a-z]+)_(begin|end)\((.*)\)/
          type = check_type($1)
          direction = $2
          spec = check_spec($3)
          case direction
          when 'begin'
            key = "#{type}/#{spec}"
            error "begin x2: #{key}" if curr[key]
            (repo[type] ||= {})[spec] = curr[key] = []
          when 'end'
            curr.delete("#{type}/#{spec}") or
                    error "end before begin: #{type}/#{spec}"
          else
            raise 'must not happen'
          end

        when %r<(?:\A\#@|\#@@)([a-z]+)/(\w+)\{>
          type = check_type($1)
          spec = check_spec($2)
          key = "#{type}/#{spec}"
          error "begin x2: #{key}" if curr[key]
          (repo[type] ||= {})[spec] = curr[key] = []
          opened.push [type, spec]

        when %r<(?:\A\#@|\#@@)([a-z]+)/(\w+)\}>
          type = check_type($1)
          spec = check_spec($2)
          curr.delete("#{type}/#{spec}") or
              error "end before begin: #{type}/#{spec}"
          opened.delete "#{type}/#{spec}"

        when %r<(?:\A\#@|\#@@)\}>
          type, spec = opened.last
          curr.delete("#{type}/#{spec}") or
              error "closed before open: #{type}/#{spec}"
          opened.pop

        when /(?:\A\#@|\#@@)yacchack/
          yacchack = true

        when /\A\#@-/   # does not increment line number.
          line = canonical($')
          curr.each_value do |list|
            list.push Line.new(nil, line)
          end

        else
          next if yacchack and line.strip == ';'
          line = canonical(line)
          curr.each_value do |list|
            list.push Line.new(lineno, line)
          end
          lineno += 1
        end
      end
      if curr.size > 1
        curr.delete 'WHOLE'
        curr.each do |range, lines|
          $stderr.puts "#{filename()}: unclosed range: #{range} (begin @#{lines.first.number})"
        end
        raise ApplicationError, "ERROR"
      end

      repo
    end

    def canonical(line)
      tabwidth = 8
      if @param['tabwidth']
        tabwidth = @param['tabwidth']
      end
      detab(line, tabwidth).rstrip + "\n"
    end

    def check_type(type)
      unless Preprocessor::TYPES.index(type)
        error "wrong type: #{type.inspect}"
      end
      type
    end

    def check_spec(spec)
      unless /\A\w+\z/ =~ spec
        error "wrong spec: #{spec.inspect}"
      end
      spec
    end

  end

end
