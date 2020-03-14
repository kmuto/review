# Copyright (c) 2008-2019 Minero Aoki, Kenshi Muto
#               1999-2007 Minero Aoki
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
#

require 'review/book'
require 'review/tocparser'
require 'review/tocprinter'
require 'review/version'
require 'optparse'

module ReVIEW
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
      @upper = ReVIEW::TOCPrinter.default_upper_level
      @book = ReVIEW::Book::Base.load
      @printer_class = ReVIEW::TextTOCPrinter
      @source = nil
    end

    def execute(*args)
      parse_options(args)
      param = {}

      @book.config = ReVIEW::Configure.values
      unless File.readable?(@yamlfile)
        @logger.error("No such fiile or can't open #{@yamlfile}.")
        exit 1
      end
      @book.load_config(@yamlfile)

      begin
        printer = @printer_class.new(@upper, param)
        if @source.is_a?(ReVIEW::Book::Part)
          printer.print_part(@source)
        else
          printer.print_book(@source)
        end
      rescue ReVIEW::Error, RuntimeError, Errno::ENOENT => e
        raise if $DEBUG
        error_exit(e.message)
      end
    end

    def parse_options(args)
      opts = OptionParser.new
      opts.version = ReVIEW::VERSION
      opts.on('--yaml=YAML', 'Read configurations from YAML file.') { |yaml| @yamlfile = yaml }
      opts.on('-a', '--all', 'print all chapters.') { @source = @book }
      opts.on('-p', '--part N', 'list only part N.') do |n|
        @source = @book.part(Integer(n)) or
          error_exit("part #{n} does not exist in this book")
      end
      opts.on('-c', '--chapter C', 'list only chapter C.') do |c|
        begin
          @source = ReVIEW::Book::Part.new(nil, 1, [@book.chapter(c)])
        rescue
          error_exit("chapter #{c} does not exist in this book")
        end
      end
      opts.on('-l', '--level N', 'list upto N level (1..4, default=4)') do |n|
        @upper = Integer(n)
        unless (0..4).cover?(@upper) # 0 is hidden option
          $stderr.puts '-l/--level option accepts only 1..4'
          exit 1
        end
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

      if @source
        error_exit('-a/-s option and file arguments are exclusive') unless ARGV.empty?
      else
        puts opts.help
        exit 0
      end
    end

    def error_exit(msg)
      @logger.error msg
      exit 1
    end
  end
end
