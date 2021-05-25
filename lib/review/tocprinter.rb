# Copyright (c) 2008-2021 Minero Aoki, Kenshi Muto
#               1999-2007 Minero Aoki
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
#

require 'review/book'
require 'review/version'
require 'optparse'
require 'review/plaintextbuilder'

module ReVIEW
  class PLAINTEXTTocBuilder < PLAINTEXTBuilder
    def headline(level, label, caption)
      if @chapter.is_a?(ReVIEW::Book::Part)
        print "\x01H0\x01" # XXX: don't modify level value. level value will be handled in sec_counter#prefix()
      else
        print "\x01H#{level}\x01"
      end
      # embed header information for tocparser
      super(level, label, caption)
    end

    def base_block(type, lines, caption = nil)
      puts "\x01STARTLIST\x01"
      super(type, lines, caption)
      puts "\x01ENDLIST\x01"
    end

    def blank
      @blank_seen = true
    end
  end

  class TOCPrinter
    class Counter
      def initialize(name: nil, level: nil, headline: nil, lines: nil, chars: nil, list_lines: nil, text_lines: nil, part: nil)
        @name = name
        @level = level
        @headline = headline
        @lines = lines
        @chars = chars
        @list_lines = list_lines
        @text_lines = text_lines
        @part = part
      end

      attr_accessor :name, :level, :headline, :lines, :chars, :list_lines, :text_lines, :part
    end

    def self.execute(*args)
      new.execute(*args)
    end

    def initialize
      @logger = ReVIEW.logger
      @yamlfile = 'config.yml'
      @upper = 4
      @indent = true
      @buildonly = nil
      @detail = nil
      @calc_char_width = nil
    end

    attr_accessor :calc_char_width

    def execute(*args)
      parse_options(args)
      @config = ReVIEW::Configure.create(yamlfile: @yamlfile)
      @book = ReVIEW::Book::Base.new('.', config: @config)
      unless File.readable?(@yamlfile)
        @logger.error("No such fiile or can't open #{@yamlfile}.")
        exit 1
      end
      I18n.setup(@config['language'])

      if @detail
        begin
          require 'unicode/eaw'
          @calc_char_width = true
        rescue LoadError
          @logger.warn('not found unicode/eaw library. page volume may be unreliable.')
          @calc_char_width = nil
        end
      end

      print_result(build_result_array)
    end

    def build_result_array
      result_array = []
      begin
        @book.parts.each do |part|
          if part.name.present? && (@buildonly.nil? || @buildonly.include?(part.name))
            result_array.push(Counter.new(part: 'start'))
            if part.file?
              content = build_chap(part)
              result_array.concat(parse_contents(part.name, @upper, content))
            else
              title = part.format_number + I18n.t('chapter_postfix') + part.title
              result_array.push(
                Counter.new(name: '', lines: 1, chars: title.size, list_lines: 0, text_lines: 1),
                Counter.new(level: 0, headline: title, lines: 1, chars: title.size, list_lines: 0, text_lines: 1)
              )
            end
          end

          part.chapters.each do |chap|
            if @buildonly.nil? || @buildonly.include?(chap.name)
              content = build_chap(chap)
              result_array.concat(parse_contents(chap.name, @upper, content))
            end
          end
          if part.name.present? && (@buildonly.nil? || @buildonly.include?(part.name))
            result_array.push(Counter.new(part: 'end'))
          end
        end
      rescue ReVIEW::FileNotFound, ReVIEW::CompileError => e
        @logger.error e
        exit 1
      end

      result_array
    end

    def print_result(result_array)
      result_array.each do |result|
        if result.part
          next
        end

        if result.name
          # file information
          if @detail
            puts '============================='
            printf("%6dC %5dL %5dP  %s\n", result.chars, result.lines, calc_pages(result).ceil, result.name)
            puts '-----------------------------'
          end
          next
        end

        # section information
        if @detail
          printf('%6dC %5dL %5.1fP  ', result.chars, result.lines, calc_pages(result))
        end
        if @indent && result.level
          print '  ' * (result.level == 0 ? 0 : result.level - 1)
        end
        puts result.headline
      end
    end

    def calc_pages(result)
      (result.list_lines.to_f / @book.page_metric.list.n_lines) +
        (result.text_lines.to_f / @book.page_metric.text.n_lines)
    end

    def calc_linesize(line)
      return line.size unless @calc_char_width

      line.each_char.inject(0) do |result, char|
        # XXX: should include A also?
        if %i[Na H N].include?(Unicode::Eaw.property(char))
          result + 0.5 # halfwidth
        else
          result + 1
        end
      end
    end

    def parse_contents(name, upper, content)
      headline_array = []
      counter = Counter.new(lines: 0, chars: 0, list_lines: 0, text_lines: 0)
      listmode = nil

      content.each_line(chomp: true) do |l|
        if l.start_with?("\x01STARTLIST\x01")
          listmode = true
          next
        elsif l.start_with?("\x01ENDLIST\x01")
          listmode = nil
          next
        elsif l =~ /\A\x01H(\d)\x01/
          # headline
          level = $1.to_i
          l = $'
          if level <= upper
            if counter.chars > 0
              headline_array.push(counter)
            end
            headline = l
            counter = Counter.new(
              level: level,
              headline: headline,
              lines: 1,
              chars: headline.size,
              list_lines: 0,
              text_lines: 1
            )
            next
          end
        end

        counter.lines += 1
        counter.chars += l.size

        if listmode
          # code list: calculate line wrapping
          counter.list_lines += calc_line_wrapping(l, mode: :list)
        else
          # normal paragraph: calculate line wrapping
          counter.text_lines += calc_line_wrapping(l, mode: :text)
        end
      end
      headline_array.push(counter)

      total = calc_total_count(name, headline_array)
      headline_array.unshift(total)
    end

    def calc_line_wrapping(line, mode:)
      return 1 if line.size == 0

      case mode
      when :list
        (calc_linesize(line) - 1) / @book.page_metric.list.n_columns + 1
      else # mode == :text
        (calc_linesize(line) - 1) / @book.page_metric.text.n_columns + 1
      end
    end

    def calc_total_count(name, headline_array)
      total = Counter.new(name: name,
                          lines: 0,
                          chars: 0,
                          list_lines: 0,
                          text_lines: 0)

      headline_array.each do |h|
        next unless h.lines

        total.lines += h.lines
        total.chars += h.chars
        total.list_lines += h.list_lines
        total.text_lines += h.text_lines
      end

      total
    end

    def build_chap(chap)
      compiler = ReVIEW::Compiler.new(ReVIEW::PLAINTEXTTocBuilder.new)
      begin
        compiler.compile(@book.chapter(chap.name))
      rescue ReVIEW::ApplicationError => e
        @logger.error e.message
        ''
      end
    end

    def parse_options(args)
      opts = OptionParser.new
      opts.version = ReVIEW::VERSION
      opts.on('--yaml=YAML', 'Read configurations from YAML file.') { |yaml| @yamlfile = yaml }
      opts.on('-y', '--only file1,file2,...', 'list only specified files.') do |v|
        @buildonly = v.split(/\s*,\s*/).map { |m| m.strip.sub(/\.re\Z/, '') }
      end
      opts.on('-l', '--level N', 'list upto N level (default=4)') do |n|
        @upper = n.to_i
      end
      opts.on('-d', '--detail', 'show characters and lines of each section.') do
        @detail = true
      end
      opts.on('--noindent', "don't indent headlines.") do
        @indent = nil
      end
      opts.on('--help', 'print this message and quit.') do
        puts opts.help
        exit 0
      end
      begin
        opts.parse!(args)
      rescue OptionParser::ParseError => e
        @logger.error e.message
        $stderr.puts opts.help
        exit 1
      end
    end
  end
end
