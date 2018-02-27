# Copyright (c) 2018 Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
#
require 'optparse'
require 'yaml'
require 'fileutils'

require 'review/converter'
require 'review/configure'
require 'review/book'
require 'review/yamlloader'
require 'review/topbuilder'
require 'review/version'

module ReVIEW
  class TEXTMaker
    attr_accessor :config, :basedir

    def initialize
      @basedir = nil
      @logger = ReVIEW.logger
      @plaintext = nil
    end

    def error(msg)
      @logger.error "#{File.basename($PROGRAM_NAME, '.*')}: #{msg}"
      exit 1
    end

    def warn(msg)
      @logger.warn "#{File.basename($PROGRAM_NAME, '.*')}: #{msg}"
    end

    def self.execute(*args)
      self.new.execute(*args)
    end

    def parse_opts(args)
      cmd_config = {}
      opts = OptionParser.new

      opts.banner = 'Usage: review-textmaker [-n] configfile'
      opts.version = ReVIEW::VERSION
      opts.on('-n', 'No decoration.') { @plaintext = true }
      opts.on('--help', 'Prints this message and quit.') do
        puts opts.help
        exit 0
      end

      opts.parse!(args)
      if args.size != 1
        puts opts.help
        exit 0
      end

      [cmd_config, args[0]]
    end

    def build_path
      "#{@config['bookname']}-text"
    end

    def remove_old_files(path)
      FileUtils.rm_rf(path)
    end

    def execute(*args)
      @config = ReVIEW::Configure.values
      @config.maker = 'textmaker'
      cmd_config, yamlfile = parse_opts(args)
      error "#{yamlfile} not found." unless File.exist?(yamlfile)

      begin
        loader = ReVIEW::YAMLLoader.new
        @config.deep_merge!(loader.load_file(yamlfile))
      rescue => e
        error "yaml error #{e.message}"
      end
      # YAML configs will be overridden by command line options.
      @config.deep_merge!(cmd_config)
      I18n.setup(@config['language'])
      begin
        generate_text_files(yamlfile)
      rescue ApplicationError => e
        raise if @config['debug']
        error(e.message)
      end
    end

    def generate_text_files(yamlfile)
      @basedir = File.dirname(yamlfile)
      @path = build_path
      remove_old_files(@path)
      Dir.mkdir(@path)

      @book = ReVIEW::Book.load(@basedir)
      @book.config = @config

      build_body(@path, yamlfile)
    end

    def build_body(basetmpdir, _yamlfile)
      base_path = Pathname.new(@basedir)
      builder = nil
      if @plaintext
        builder = ReVIEW::PLAINTEXTBuilder.new
      else
        builder = ReVIEW::TOPBuilder.new
      end
      @converter = ReVIEW::Converter.new(@book, builder)
      @book.parts.each do |part|
        if part.name.present?
          if part.file?
            build_chap(part, base_path, basetmpdir, true)
          else
            textfile = "part_#{part.number}.txt"
            build_part(part, basetmpdir, textfile)
          end
        end

        part.chapters.each { |chap| build_chap(chap, base_path, basetmpdir, false) }
      end
    end

    def build_part(part, basetmpdir, textfile)
      File.open("#{basetmpdir}/#{textfile}", 'w') do |f|
        f.print '■H1■' unless @plaintext
        f.print ReVIEW::I18n.t('part', part.number)
        f.print "　#{part.name.strip}" if part.name.strip.present?
        f.puts
      end
    end

    def build_chap(chap, base_path, basetmpdir, ispart)
      filename = ''

      if ispart.present?
        filename = chap.path
      else
        filename = Pathname.new(chap.path).relative_path_from(base_path).to_s
      end
      id = filename.sub(/\.re\Z/, '')

      textfile = "#{id}.txt"

      begin
        @converter.convert(filename, File.join(basetmpdir, textfile))
      rescue => e
        warn "compile error in #{filename} (#{e.class})"
        warn e.message
      end
    end
  end
end
