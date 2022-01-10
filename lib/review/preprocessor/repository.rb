# Copyright (c) 2010-2021 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
#

require 'review/textutils'
require 'review/loggable'

module ReVIEW
  class Preprocessor
    class Repository
      include TextUtils
      include Loggable

      def initialize(param)
        @repository = {}
        @config = param
        @leave_content = nil
        @logger = ReVIEW.logger
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
        @leave_content = File.extname(fname) == '.re'
        return @repository[fname] if @repository[fname]

        @repository[fname] = git?(fname) ? parse_git_blob(fname) : parse_file(fname)
      end

      def git?(fname)
        fname.start_with?('git|')
      end

      def parse_git_blob(g_obj)
        IO.popen('git show ' + g_obj.sub(/\Agit\|/, ''), 'r') do |f|
          @inf = f
          return _parse_file(f)
        end
      end

      def parse_file(fname)
        File.open(fname, 'rt:BOM|utf-8') do |f|
          @inf = f
          return _parse_file(f)
        end
      end

      def _parse_file(f)
        whole = []
        repo = { 'file' => whole }
        curr = { 'WHOLE' => whole }
        lineno = 1
        yacchack = false # remove ';'-only lines.
        opened = [['(not opened)', '(not opened)']] * 3

        f.each do |line|
          begin
            case line
            when /(?:\A\#@|\#@@)([a-z]+)_(begin|end)\((.*)\)/
              type = check_type($1)
              direction = $2
              spec = check_spec($3)
              case direction
              when 'begin'
                key = "#{type}/#{spec}"
                if curr[key]
                  app_error "begin x2: #{key}"
                end
                (repo[type] ||= {})[spec] = curr[key] = []
              when 'end'
                curr.delete("#{type}/#{spec}") or
                  app_error "end before begin: #{type}/#{spec}"
              else
                app_error 'must not happen'
              end

            when %r{(?:\A\#@|\#@@)([a-z]+)/(\w+)\{}
              type = check_type($1)
              spec = check_spec($2)
              key = "#{type}/#{spec}"
              if curr[key]
                app_error "begin x2: #{key}"
              end
              (repo[type] ||= {})[spec] = curr[key] = []
              opened.push([type, spec])

            when %r{(?:\A\#@|\#@@)([a-z]+)/(\w+)\}}
              type = check_type($1)
              spec = check_spec($2)
              curr.delete("#{type}/#{spec}") or
                app_error "end before begin: #{type}/#{spec}"
              opened.delete("#{type}/#{spec}")

            when /(?:\A\#@|\#@@)\}/
              type, spec = opened.last
              curr.delete("#{type}/#{spec}") or
                app_error "closed before open: #{type}/#{spec}"
              opened.pop

            when /(?:\A\#@|\#@@)yacchack/
              yacchack = true

            when /\A\#@-/ # does not increment line number.
              line = canonical($')
              curr.each_value { |list| list.push(Line.new(nil, line)) }

            else
              next if yacchack && (line.strip == ';')

              line = canonical(line)
              curr.each_value { |list| list.push(Line.new(lineno, line)) }
              lineno += 1
            end
          rescue ApplicationError => e
            @has_errors = true
            error e.message, location: location
          end
        end
        if curr.size > 1
          curr.delete('WHOLE')
          curr.each { |range, lines| warn "#{@inf.path}: unclosed range: #{range} (begin @#{lines.first.number})" }
          @has_errors = true
        end

        if @has_errors
          error! 'repository failed.'
        end

        repo
      end

      def canonical(line)
        if @leave_content
          return line
        end

        tabwidth = @config['tabwidth'] || 8
        if tabwidth > 0
          detab(line, tabwidth).rstrip + "\n"
        else
          line
        end
      end

      def check_type(type)
        app_error "wrong type: #{type.inspect}" unless Preprocessor::TYPES.index(type)
        type
      end

      def check_spec(spec)
        app_error "wrong spec: #{spec.inspect}" unless /\A\w+\z/.match?(spec)
        spec
      end

      def location
        "#{@inf.path}:#{@inf.lineno}"
      end
    end
  end
end
