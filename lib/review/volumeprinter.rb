# frozen_string_literal: true

#
# Copyright (c) 2014-2021 Minero Aoki, Kenshi Muto
#               2003-2014 Minero Aoki
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
#
require 'optparse'
require 'review'
require 'review/i18n'
require 'review/plaintextbuilder'

include ReVIEW::TextUtils

module ReVIEW
  class VolumePrinter
    def self.execute(*args)
      new.execute(*args)
    end

    def initialize
      @logger = ReVIEW.logger
      @yamlfile = 'config.yml'
    end

    def execute(*args)
      parse_options(args)
      begin
        @config = ReVIEW::Configure.create(yamlfile: @yamlfile)
        @book = ReVIEW::Book::Base.new('.', config: @config)
        unless File.readable?(@yamlfile)
          raise ReVIEW::FileNotFound, "No such fiile or can't open #{@yamlfile}."
        end

        I18n.setup(@book.config['language'])

        @book.each_part do |part|
          if part.number
            print_chapter_volume(part)
          end
          part.each_chapter do |chap|
            print_chapter_volume(chap)
          end
        end
      rescue ReVIEW::ConfigError, ReVIEW::FileNotFound, ReVIEW::CompileError, ReVIEW::ApplicationError => e
        @logger.error e.message
        exit 1
      end
      puts '============================='
      print_volume(@book.volume)
    end

    def parse_options(args)
      opts = OptionParser.new
      opts.version = ReVIEW::VERSION
      opts.on('--yaml=YAML', 'Read configurations from YAML file.') { |yaml| @yamlfile = yaml }
      opts.on('--help', 'Print this message and quit') do
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

    def print_chapter_volume(chap)
      builder = ReVIEW::PLAINTEXTBuilder.new
      builder.bind(ReVIEW::Compiler.new(builder), chap, nil)

      vol = chap.volume
      title = chap.format_number
      unless title.empty?
        title += '  '
      end
      begin
        title += builder.compile_inline(chap.title)
      rescue ReVIEW::ApplicationError => e
        @logger.warn "#{chap.name} : #{e.message.sub(/.+error: /, '')}"
      end

      printf("%3dKB %6dC %5dL %3dP  %s %-s\n",
             vol.kbytes, vol.chars, vol.lines, vol.page,
             "#{chap.name} ".ljust(15, '.'), title)
    end

    def print_volume(vol)
      # total
      printf("%3dKB %6dC %5dL %3dP\n", vol.kbytes, vol.chars, vol.lines, vol.page)
    end
  end
end
