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
        level = 0
      end
      # embed header information for tocparser
      print "\x01H#{level}\x01"
      super(level, label, caption)
    end
  end

  class IndexPrinter
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

      result_array = []

      begin
        @book.parts.each do |part|
          if part.name.present? && (@buildonly.nil? || @buildonly.include?(part.name))
            if part.file?
              result = build_chap(part)
              result_array += parse_contents(part.name, @upper, result)
            else
              result_array += [
                { name: '', lines: 1, chars: part.name.size },
                { level: 0, headline: part.name, lines: 1, chars: part.name.size }
              ]
            end
          end

          part.chapters.each do |chap|
            if @buildonly.nil? || @buildonly.include?(chap.name)
              result = build_chap(chap)
              result_array += parse_contents(chap.name, @upper, result)
            end
          end
        end
      rescue ReVIEW::FileNotFound => e
        @logger.error e
        exit 1
      end

      print_result(result_array)
    end

    def print_result(result_array)
      result_array.each do |result|
        if result[:name]
          # file information
          if @detail
            puts '============================='
            printf("%6dC %5dL  %s\n", result[:chars], result[:lines], result[:name])
            puts '-----------------------------'
          end
          next
        end

        # section information
        if @detail
          printf('%6dC %5dL  ', result[:chars], result[:lines])
        end
        if @indent
          print '  ' * (result[:level] == 0 ? 0 : result[:level] - 1)
        end
        puts result[:headline]
      end
    end

    def parse_contents(name, upper, content)
      headline_array = []

      lines = 0
      chars = 0
      counter = {}

      content.split("\n").each do |l|
        if l =~ /\A\x01H(\d)\x01/
          # headline
          level = $1.to_i
          l = $'
          if level <= upper
            headline_array.push(counter)

            headline = l
            counter = {
              level: level,
              headline: headline,
              lines: 1,
              chars: headline.size
            }
            next
          end
        end

        counter[:lines] += 1
        counter[:chars] += l.size
      end
      headline_array.push(counter)

      total_lines = 0
      total_chars = 0
      headline_array.each do |h|
        next unless h[:lines]
        total_lines += h[:lines]
        total_chars += h[:chars]
      end

      headline_array.delete_if {|h| h.empty? }.
        unshift({name: name, lines: total_lines, chars: total_chars})
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
      opts.on('--noindent', "don't indent headlines") do
        @indent = nil
      end
      opts.on('--help', 'print this message and quit.') do
        puts opts.help
        exit 0
      end
      begin
        opts.parse!
      rescue OptionParser::ParseError => e
        @logger.error e.message
        $stderr.puts opts.help
        exit 1
      end
    end
  end
end
