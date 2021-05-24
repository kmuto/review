# Copyright (c) 2010-2019 Minero Aoki, Kenshi Muto
#               2002-2009 Minero Aoki
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
#

require 'review/textutils'
require 'review/exception'
require 'review/preprocessor/directive'
require 'review/preprocessor/line'
require 'review/preprocessor/repository'
require 'review/loggable'
require 'open3'

module ReVIEW
  class Preprocessor
    include Loggable

    TYPES = %w[file range].freeze
    KNOWN_DIRECTIVES = %w[require provide warn ok].freeze
    INF_INDENT = 9999

    def initialize(param)
      @repository = ReVIEW::Preprocessor::Repository.new(param)
      @config = param ## do not use params in this class; only used in Repository
      @logger = ReVIEW.logger
      @leave_content = nil
    end

    def process(path)
      File.open(path) do |inf|
        @inf = inf
        @f = StringIO.new
        begin
          preproc(@inf)
        rescue Errno::ENOENT => e
          error! e.message
        end
        @f.string
      end
    end

    private

    def preproc(f)
      @vartable = {}
      @has_errors = false

      f.each_line do |line|
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
          get_output(expand(direc.arg), direc['stderr']).each { |out| @f.print out.string }
          skip_list(f)

        when /\A\#@mapfile/
          direc = parse_directive(line, 1, 'eval')
          path = expand(direc.arg)
          @leave_content = File.extname(path) == '.re'
          if direc['eval']
            ent = evaluate(path, ent)
          else
            ent = @repository.fetch_file(path)
          end
          replace_block(f, line, ent, false) # FIXME: turn off lineno: tmp

        when /\A\#@map(?:range)?/
          direc = parse_directive(line, 2, 'unindent')
          path = expand(direc.args[0])
          @leave_content = File.extname(path) == '.re'
          ent = @repository.fetch_range(path, direc.args[1]) or
            app_error "unknown range: #{path}: #{direc.args[1]}"
          ent = (direc['unindent'] ? unindent(ent, direc['unindent']) : ent)
          replace_block(f, line, ent, false) # FIXME: turn off lineno: tmp

        when /\A\#@end/
          app_error 'unbaranced #@end'

        when /\A\#@/
          op = line.slice(/@(\w+)/, 1)
          warn "unknown directive: #{line.strip}", location: location unless known_directive?(op)
          if op == 'warn'
            warn line.strip.sub(/\#@warn\((.+)\)/, '\1'), location: location
          end
          @f.print line

        when /\A\s*\z/ # empty line
          @f.puts
        else # rubocop:disable Lint/DuplicateBranch
          @f.print line
        end
      rescue ApplicationError => e
        @has_errors = true
        error e.message, location: location
      end

      if @has_erros
        error! 'preprocessor failed.'
      end
    end

    def known_directive?(op)
      KNOWN_DIRECTIVES.index(op)
    end

    def replace_block(f, directive_line, newlines, with_lineno)
      @f.print directive_line
      newlines.each do |line|
        if with_lineno
          print_number(line.number)
        end
        @f.print line.string
      end
      skip_list(f)
    end

    def print_number(num)
      @f.printf('%4s  ', (num ? num.to_s : ''))
    end

    def skip_list(f)
      begline = f.lineno
      f.each_line do |line|
        case line
        when /\A\#@end/
          @f.print line
          return nil
        when %r{\A//\}}
          unless @leave_content
            warn '//} seen in list', location: location
            @f.print line
            return nil
          end
        when /\A\#@\w/
          warn "#{line.slice(/\A\#@\w+/)} seen in list", location: location
          @f.print line
        when /\A\#@/
          @f.print line
        end
      end
      app_error "list reached end of file (beginning line = #{begline})"
    end

    def parse_directive(line, argc, *optdecl)
      m = /\A\#@(\w+)\((.*?)\)(?:\[(.*?)\])?\z/.match(line.strip) or
        app_error "wrong directive: #{line.strip}"
      op = m[1]
      args = m[2].split(/,\s*/)
      opts = parse_optargs(m[3])
      return if (argc == 0) && args.empty?

      if argc == -1
        # Any number of arguments are allowed.
      elsif args.size != argc
        app_error 'wrong arg size'
      end
      if opts
        wrong_opts = opts.keys - optdecl
        unless wrong_opts.empty?
          app_error "wrong option: #{wrong_opts.keys.join(' ')}"
        end
      end
      Directive.new(op, args, opts || {})
    end

    def parse_optargs(str)
      return nil unless str

      table = {}
      str.split(/,\s*/).each do |a|
        name, spec = a.split('=', 2)
        table[name] = optarg_value(spec)
      end
      table
    end

    def optarg_value(spec)
      case spec
      when 'true' # [name=true], [name]
        true
      when 'false' # [name=false]
        false
      when 'nil' # [name=nil]
        nil
      when /^\d+$/ # [name=8]
        $&.to_i
      else # [name=val]
        spec
      end
    end

    def defvar(name, value)
      @vartable[name] = value
    end

    def expand(str)
      str.gsub(/\$\w+/) do |name|
        s = @vartable[name.sub('$', '')]
        s ? expand(s) : name
      end
    end

    def unindent(chunk, n)
      n = minimum_indent(chunk) unless n.is_a?(Integer)
      re = /\A#{' ' * n}/
      chunk.map { |line| line.edit { |s| s.sub(re, '') } }
    end

    def minimum_indent(chunk)
      n = chunk.map { |line| line.empty? ? INF_INDENT : line.num_indent }.min
      n == INF_INDENT ? 0 : n
    end

    def evaluate(path, chunk)
      outputs = get_output("ruby #{path}", false).split("\n").map(&:strip)
      chunk.map do |line|
        if /\# \$\d+/ =~ line.string
          # map result into source.
          line.edit { |s| s.sub(/\$(\d+)/) { outputs[$1.to_i - 1] } }
        else
          line
        end
      end
    end

    def get_output(cmd, use_stderr)
      out = err = nil
      Open3.popen3(cmd) do |_stdin, stdout, stderr|
        out = stdout.readlines
        if use_stderr
          out.concat(stderr.readlines)
        else
          err = stderr.readlines
        end
      end
      if err && !err.empty?
        $stderr.puts '[unexpected stderr message]'
        err.each { |line| $stderr.print line }
        app_error 'get_output: got unexpected output'
      end
      num = 0
      out.map { |line| Line.new(num += 1, line) }
    end

    def location
      "#{filename}:#{lineno}"
    end

    def filename
      @inf.path
    end

    def lineno
      @inf.lineno
    end
  end
end
