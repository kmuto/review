# Copyright (c) 2008-2020 Minero Aoki, Kenshi Muto
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
    def self.execute(*args)
      Signal.trap(:INT) { exit 1 }
      if RUBY_PLATFORM !~ /mswin(?!ce)|mingw|cygwin|bccwin/
        Signal.trap(:PIPE, 'IGNORE')
      end
      new.execute(*args)
    rescue Errno::EPIPE
      exit 0
    end

    def initialize
      @logger = ReVIEW.logger
      @config = ReVIEW::Configure.values
      @yamlfile = 'config.yml'
      @book = ReVIEW::Book::Base.load
      @upper = 4
      @indent = true
      @buildonly = nil
      @detail = nil
    end

    def execute(*args)
      parse_options(args)
      @book.config = ReVIEW::Configure.values
      unless File.readable?(@yamlfile)
        @logger.error("No such fiile or can't open #{@yamlfile}.")
        exit 1
      end
      @book.load_config(@yamlfile)
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
            result_array.push({ part: 'start' })
            if part.file?
              result = build_chap(part)
              result_array += parse_contents(part.name, @upper, result)
            else
              title = part.format_number + I18n.t('chapter_postfix') + part.title
              result_array += [
                { name: '', lines: 1, chars: title.size, list_lines: 0, text_lines: 1 },
                { level: 0, headline: title, lines: 1, chars: title.size, list_lines: 0, text_lines: 1 }
              ]
            end
          end

          part.chapters.each do |chap|
            if @buildonly.nil? || @buildonly.include?(chap.name)
              result = build_chap(chap)
              result_array += parse_contents(chap.name, @upper, result)
            end
          end
          if part.name.present? && (@buildonly.nil? || @buildonly.include?(part.name))
            result_array.push({ part: 'end' })
          end
        end
      rescue ReVIEW::FileNotFound => e
        @logger.error e
        exit 1
      end

      result_array
    end

    def print_result(result_array)
      result_array.each do |result|
        if result[:part]
          next
        end

        if result[:name]
          # file information
          if @detail
            puts '============================='
            printf("%6dC %5dL %5dP  %s\n", result[:chars], result[:lines], calc_pages(result).ceil, result[:name])
            puts '-----------------------------'
          end
          next
        end

        # section information
        if @detail
          printf('%6dC %5dL %5.1fP  ', result[:chars], result[:lines], calc_pages(result))
        end
        if @indent && result[:level]
          print '  ' * (result[:level] == 0 ? 0 : result[:level] - 1)
        end
        puts result[:headline]
      end
    end

    def calc_pages(result)
      p = 0
      p += result[:list_lines].to_f / @book.page_metric.list.n_lines
      p += result[:text_lines].to_f / @book.page_metric.text.n_lines
      p
    end

    def calc_linesize(l)
      return l.size unless @calc_char_width
      w = 0
      l.split('').each do |c|
        # XXX: should include A also?
        if %i[Na H N].include?(Unicode::Eaw.property(c))
          w += 0.5 # halfwidth
        else
          w += 1
        end
      end
      w
    end

    def parse_contents(name, upper, content)
      headline_array = []
      counter = { lines: 0, chars: 0, list_lines: 0, text_lines: 0 }
      listmode = nil

      content.split("\n").each do |l|
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
            if counter[:chars] > 0
              headline_array.push(counter)
            end
            headline = l
            counter = {
              level: level,
              headline: headline,
              lines: 1,
              chars: headline.size,
              list_lines: 0,
              text_lines: 1
            }
            next
          end
        end

        counter[:lines] += 1
        counter[:chars] += l.size

        if listmode
          # code list: calculate line wrapping
          if l.size == 0
            counter[:list_lines] += 1
          else
            counter[:list_lines] += (calc_linesize(l) - 1) / @book.page_metric.list.n_columns + 1
          end
        else
          # normal paragraph: calculate line wrapping
          if l.size == 0
            counter[:text_lines] += 1
          else
            counter[:text_lines] += (calc_linesize(l) - 1) / @book.page_metric.text.n_columns + 1
          end
        end
      end
      headline_array.push(counter)

      total_lines = 0
      total_chars = 0
      total_list_lines = 0
      total_text_lines = 0

      headline_array.each do |h|
        next unless h[:lines]
        total_lines += h[:lines]
        total_chars += h[:chars]
        total_list_lines += h[:list_lines]
        total_text_lines += h[:text_lines]
      end

      headline_array.delete_if(&:empty?).
        unshift({ name: name, lines: total_lines, chars: total_chars, list_lines: total_list_lines, text_lines: total_text_lines })
    end

    def build_chap(chap)
      compiler = ReVIEW::Compiler.new(ReVIEW::PLAINTEXTTocBuilder.new)
      begin
        compiler.compile(@book.chapter(chap.name))
      rescue ReVIEW::ApplicationError => e
        @logger.error e
        exit 1
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
