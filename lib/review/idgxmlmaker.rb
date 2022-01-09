# Copyright (c) 2019-2021 Kenshi Muto
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
require 'review/idgxmlbuilder'
require 'review/version'
require 'review/makerhelper'
require 'review/loggable'

module ReVIEW
  class IDGXMLMaker
    include MakerHelper
    include Loggable

    attr_accessor :config, :basedir

    def initialize
      @basedir = nil
      @logger = ReVIEW.logger
      @plaintext = nil
      @compile_errors = nil
    end

    def self.execute(*args)
      self.new.execute(*args)
    end

    def parse_opts(args)
      cmd_config = {}
      opts = OptionParser.new
      @table = nil
      @filter = nil
      @buildonly = nil

      opts.banner = 'Usage: review-idgxmlmaker [options] configfile'
      opts.version = ReVIEW::VERSION
      opts.on('-w', '--width widthoftypepage', 'Specify the width of type page for layouting tables (mm).') { |v| @table = v }
      opts.on('-f', '--filter filterprogrampath', 'Specify the filter path.') { |v| @filter = v }
      opts.on('-y', '--only file1,file2,...', 'Build only specified files.') { |v| @buildonly = v.split(/\s*,\s*/).map { |m| m.strip.sub(/\.re\Z/, '') } }
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
      "#{@config['bookname']}-idgxml"
    end

    def remove_old_files(path)
      FileUtils.rm_rf(path)
    end

    def execute(*args)
      cmd_config, yamlfile = parse_opts(args)
      error! "#{yamlfile} not found." unless File.exist?(yamlfile)

      @config = ReVIEW::Configure.create(maker: 'idgxmlmaker',
                                         yamlfile: yamlfile,
                                         config: cmd_config)
      I18n.setup(@config['language'])
      begin
        generate_idgxml_files(yamlfile)
        @logger.success("built #{build_path}")
      rescue ApplicationError => e
        raise if @config['debug']

        error! e.message
      end
    end

    def generate_idgxml_files(yamlfile)
      @basedir = File.dirname(yamlfile)
      @path = build_path
      remove_old_files(@path)
      Dir.mkdir(@path)

      @book = ReVIEW::Book::Base.new(@basedir, config: @config)
      if @table
        @book.config['tableopt'] = @table
      end

      build_body(@path, yamlfile)

      if @compile_errors
        app_error 'compile error, No IDGXML file output.'
      end
    end

    def apply_filter(xmlfile)
      return unless @filter

      # pass filename information to filter by environment variable
      ENV['REVIEW_FNAME'] = File.basename(xmlfile).sub(/.xml\Z/, '.re')
      begin
        o, e, s = Open3.capture3(@filter, stdin_data: File.read(xmlfile))
        unless e.empty?
          warn("filter error for #{xmlfile}: #{e}")
        end
        if s.success?
          File.write(xmlfile, o) # override
        end
      rescue StandardError => e
        warn("filter error for #{xmlfile}: #{e.message}")
      end
    end

    def build_body(basetmpdir, _yamlfile)
      base_path = Pathname.new(@basedir)
      @converter = ReVIEW::Converter.new(@book, ReVIEW::IDGXMLBuilder.new)
      @book.parts.each do |part|
        if part.name.present?
          if part.file?
            build_chap(part, base_path, basetmpdir, true)
          else
            xmlfile = "part_#{part.number}.xml"
            build_part(part, basetmpdir, xmlfile)
          end
        end

        part.chapters.each { |chap| build_chap(chap, base_path, basetmpdir, false) }
      end
    end

    def build_part(part, basetmpdir, xmlfile)
      File.open(File.join(basetmpdir, xmlfile), 'w') do |f|
        title = ReVIEW::I18n.t('part', part.number)
        if part.name.strip.present?
          title << ReVIEW::I18n.t('chapter_postfix')
          title << part.name.strip
        end
        f.puts '<?xml version="1.0" encoding="UTF-8"?>'
        f.print '<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><title aid:pstyle="h1">'
        f.print h(title)
        f.print '</title><?dtp level="1" section="'
        f.print h(title)
        f.puts '"?></doc>'
      end
      apply_filter(File.join(basetmpdir, xmlfile))
    end

    def build_chap(chap, base_path, basetmpdir, ispart)
      filename = ''

      if ispart.present?
        filename = chap.path
      else
        filename = Pathname.new(chap.path).relative_path_from(base_path).to_s
      end
      id = File.basename(filename).sub(/\.re\Z/, '')
      if @buildonly && !@buildonly.include?(id)
        warn "skip #{id}.re"
        return
      end

      xmlfile = "#{id}.xml"

      begin
        @converter.convert(filename, File.join(basetmpdir, xmlfile))
        apply_filter(File.join(basetmpdir, xmlfile))
      rescue StandardError => e
        @compile_errors = true
        error "compile error in #{filename} (#{e.class})"
        error e.message
      end
    end
  end
end
