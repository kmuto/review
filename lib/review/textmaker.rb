# frozen_string_literal: true

# Copyright (c) 2018-2023 Kenshi Muto
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
require 'review/makerhelper'
require 'review/img_math'
require 'review/img_graph'
require 'review/loggable'

module ReVIEW
  class TEXTMaker
    include MakerHelper
    include Loggable

    attr_accessor :config, :basedir

    def initialize
      @basedir = nil
      @logger = ReVIEW.logger
      @plaintext = nil
      @img_math = nil
      @img_graph = nil
      @compile_errors = nil
    end

    def self.execute(*args)
      self.new.execute(*args)
    end

    def parse_opts(args)
      cmd_config = {}
      opts = OptionParser.new
      @buildonly = nil

      opts.banner = 'Usage: review-textmaker [-n] configfile'
      opts.version = ReVIEW::VERSION
      opts.on('-n', 'No decoration.') { @plaintext = true }
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
      "#{@config['bookname']}-text"
    end

    def remove_old_files(path)
      @img_math.cleanup_mathimg
      @img_graph.cleanup_graphimg
      FileUtils.rm_rf(path)
    end

    def execute(*args)
      cmd_config, yamlfile = parse_opts(args)
      error! "#{yamlfile} not found." unless File.exist?(yamlfile)

      begin
        @config = ReVIEW::Configure.create(maker: 'textmaker',
                                           yamlfile: yamlfile,
                                           config: cmd_config)
      rescue ReVIEW::ConfigError => e
        error! e.message
      end

      @img_math = ReVIEW::ImgMath.new(@config, path_name: '_review_math_text')
      @img_graph = ReVIEW::ImgGraph.new(@config, 'top', path_name: '_review_graph')

      I18n.setup(@config['language'])
      begin
        generate_text_files(yamlfile)
        @logger.success("built #{build_path}")
      rescue ApplicationError => e
        raise if @config['debug']

        error! e.message
      end

      if @config['math_format'] == 'imgmath'
        @img_math.make_math_images
      end

      begin
        @img_graph.make_mermaid_images
      rescue ApplicationError => e
        error! e.message
      end
      @img_graph.cleanup_graphimg
    end

    def generate_text_files(yamlfile)
      @basedir = File.dirname(yamlfile)
      @path = build_path
      remove_old_files(@path)
      Dir.mkdir(@path)

      @book = ReVIEW::Book::Base.new(@basedir, config: @config)

      build_body(@path, yamlfile)

      if @compile_errors
        app_error 'compile error, No TEXT file output.'
      end
    end

    def build_body(basetmpdir, _yamlfile)
      base_path = Pathname.new(@basedir)
      builder = if @plaintext
                  ReVIEW::PLAINTEXTBuilder.new(img_math: @img_math, img_graph: @img_graph)
                else
                  ReVIEW::TOPBuilder.new(img_math: @img_math, img_graph: @img_graph)
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
      File.open(File.join(basetmpdir, textfile), 'w') do |f|
        f.print '■H1■' unless @plaintext
        f.print ReVIEW::I18n.t('part', part.number)
        f.print "　#{part.name.strip}" if part.name.strip.present?
        f.puts
      end
    end

    def build_chap(chap, base_path, basetmpdir, ispart)
      filename = if ispart.present?
                   chap.path
                 else
                   Pathname.new(chap.path).relative_path_from(base_path).to_s
                 end
      id = File.basename(filename).sub(/\.re\Z/, '')
      if @buildonly && !@buildonly.include?(id)
        warn "skip #{id}.re"
        return
      end

      textfile = "#{id}.txt"

      begin
        @converter.convert(filename, File.join(basetmpdir, textfile))
      rescue StandardError => e
        @compile_errors = true
        error "compile error in #{filename} (#{e.class})"
        error e.message
      end
    end
  end
end
