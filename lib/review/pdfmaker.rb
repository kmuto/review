# Copyright (c) 2010-2024 Kenshi Muto and Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
#
require 'optparse'
require 'yaml'
require 'fileutils'
require 'erb'
require 'tmpdir'
require 'open3'
require 'shellwords'

require 'review/i18n'
require 'review/book'
require 'review/configure'
require 'review/converter'
require 'review/latexbuilder'
require 'review/yamlloader'
require 'review/version'
require 'review/makerhelper'
require 'review/template'
require 'review/latexbox'
require 'review/call_hook'
require 'review/loggable'
require 'review/img_graph'

module ReVIEW
  class PDFMaker
    include ReVIEW::LaTeXUtils
    include Loggable
    include ReVIEW::CallHook

    attr_accessor :config, :basedir

    def initialize
      @basedir = nil
      @logger = ReVIEW.logger
      @input_files = Hash.new { |h, key| h[key] = '' }
      @mastertex = '__REVIEW_BOOK__'
      @compile_errors = nil
    end

    def system_with_info(*args)
      @logger.info args.join(' ')
      out, status = Open3.capture2e(*args)
      unless status.success?
        error "execution error\n\nError log:\n#{out}"
      end
    end

    def system_or_raise(*args)
      @logger.info args.join(' ')
      out, status = Open3.capture2e(*args)
      unless status.success?
        error! "failed to run command: #{args.join(' ')}\n\nError log:\n#{out}"
      end
    end

    def pdf_filepath
      File.join(@basedir, @config['bookname'] + '.pdf')
    end

    def remove_old_file
      FileUtils.rm_f(pdf_filepath)
    end

    def build_path
      if @config['debug']
        path = "#{@config['bookname']}-pdf"
        FileUtils.rm_rf(path, secure: true)
        Dir.mkdir(path)
        path
      else
        Dir.mktmpdir("#{@config['bookname']}-pdf-")
      end
    end

    def check_compile_status(ignore_errors)
      return unless @compile_errors

      if ignore_errors
        @logger.info 'compile error, but try to generate PDF file'
      else
        error! 'compile error, No PDF file output.'
      end
    end

    def self.execute(*args)
      self.new.execute(*args)
    end

    def parse_opts(args)
      cmd_config = {}
      opts = OptionParser.new
      @buildonly = nil

      opts.banner = 'Usage: review-pdfmaker configfile'
      opts.version = ReVIEW::VERSION
      opts.on('--help', 'Prints this message and quit.') do
        puts opts.help
        exit 0
      end
      opts.on('--[no-]debug', 'Keep temporary files.') { |debug| cmd_config['debug'] = debug }
      opts.on('--ignore-errors', 'Ignore review-compile errors.') { cmd_config['ignore-errors'] = true }
      opts.on('-y', '--only file1,file2,...', 'Build only specified files.') { |v| @buildonly = v.split(/\s*,\s*/).map { |m| m.strip.sub(/\.re\Z/, '') } }

      opts.parse!(args)
      if args.size != 1
        puts opts.help
        exit 0
      end

      [cmd_config, args[0]]
    end

    def execute(*args)
      cmd_config, yamlfile = parse_opts(args)
      error! "#{yamlfile} not found." unless File.exist?(yamlfile)

      begin
        @config = ReVIEW::Configure.create(maker: 'pdfmaker',
                                           yamlfile: yamlfile,
                                           config: cmd_config)
      rescue ReVIEW::ConfigError => e
        error! e.message
      end

      I18n.setup(@config['language'])
      @basedir = File.absolute_path(File.dirname(yamlfile))

      begin
        @config.check_version(ReVIEW::VERSION)
      rescue ReVIEW::ConfigError => e
        warn e.message
      end

      # version 2 compatibility
      unless @config['texdocumentclass']
        @config['texdocumentclass'] = if @config.check_version(2, exception: false)
                                        ['jsbook', 'uplatex,oneside']
                                      else
                                        @config['_texdocumentclass']
                                      end
      end

      begin
        generate_pdf
      rescue ApplicationError => e
        raise if @config['debug']

        error! e.message
      end
    end

    def make_input_files(book)
      input_files = Hash.new { |h, key| h[key] = +'' }
      book.parts.each do |part|
        if part.name.present?
          @config['use_part'] = true
          if part.file?
            if @buildonly && !@buildonly.include?(part.name)
              warn "skip #{part.name}.re"
              input_files['CHAPS'] << %Q(\\part{}\n)
            else
              output_chaps(part.name)
              input_files['CHAPS'] << %Q(\\input{#{part.name}.tex}\n)
            end
          else
            input_files['CHAPS'] << %Q(\\part{#{part.name}}\n)
          end
        end

        part.chapters.each do |chap|
          filename = File.basename(chap.path, '.*')
          entry = "\\input{#{filename}.tex}\n"
          if @buildonly && !@buildonly.include?(filename)
            warn "skip #{filename}.re"
            entry = "\\chapter{}\n"
          else
            output_chaps(filename)
          end

          input_files['PREDEF'] << entry if chap.on_predef?
          input_files['CHAPS'] << entry if chap.on_chaps?
          input_files['APPENDIX'] << entry if chap.on_appendix?
          input_files['POSTDEF'] << entry if chap.on_postdef?
        end
      end

      input_files
    end

    def build_pdf
      template = template_content
      Dir.chdir(@path) do
        File.write("./#{@mastertex}.tex", template)

        call_hook('hook_beforetexcompile', Dir.pwd, @basedir, base_dir: @basedir)

        ## do compile
        if ENV['REVIEW_SAFE_MODE'].to_i & 4 > 0
          warn 'command configuration is prohibited in safe mode. ignored.'
          texcommand = ReVIEW::Configure.values['texcommand']
          dvicommand = ReVIEW::Configure.values['dvicommand']
          dvioptions = ReVIEW::Configure.values['dvioptions'].shellsplit
          texoptions = ReVIEW::Configure.values['texoptions'].shellsplit
          makeindex_command = ReVIEW::Configure.values['pdfmaker']['makeindex_command']
          makeindex_options = ReVIEW::Configure.values['pdfmaker']['makeindex_options'].shellsplit
          makeindex_sty = ReVIEW::Configure.values['pdfmaker']['makeindex_sty']
          makeindex_dic = ReVIEW::Configure.values['pdfmaker']['makeindex_dic']
        else
          unless @config['texcommand'].present?
            error! "texcommand isn't defined."
          end
          texcommand = @config['texcommand']
          dvicommand = @config['dvicommand']
          @config['dvioptions'] = '' unless @config['dvioptions']
          dvioptions = @config['dvioptions'].shellsplit
          @config['texoptions'] = '' unless @config['texoptions']
          texoptions = @config['texoptions'].shellsplit
          makeindex_command = @config['pdfmaker']['makeindex_command']
          @config['pdfmaker']['makeindex_options'] = '' unless @config['pdfmaker']['makeindex_options']
          makeindex_options = @config['pdfmaker']['makeindex_options'].shellsplit
          makeindex_sty = @config['pdfmaker']['makeindex_sty']
          makeindex_dic = @config['pdfmaker']['makeindex_dic']
        end

        if makeindex_sty.present?
          makeindex_sty = File.absolute_path(makeindex_sty, @basedir)
          makeindex_options += ['-s', makeindex_sty] if File.exist?(makeindex_sty)
        end
        if makeindex_dic.present?
          makeindex_dic = File.absolute_path(makeindex_dic, @basedir)
          makeindex_options += ['-d', makeindex_dic] if File.exist?(makeindex_dic)
        end

        2.times do
          system_or_raise(*[texcommand, texoptions, "#{@mastertex}.tex"].flatten.compact)
        end

        call_hook('hook_beforemakeindex', Dir.pwd, @basedir, base_dir: @basedir)
        if @config['pdfmaker']['makeindex'] && File.size?("#{@mastertex}.idx")
          system_or_raise(*[makeindex_command, makeindex_options, @mastertex].flatten.compact)
          call_hook('hook_aftermakeindex', Dir.pwd, @basedir, base_dir: @basedir)
          system_or_raise(*[texcommand, texoptions, "#{@mastertex}.tex"].flatten.compact)
        end

        system_or_raise(*[texcommand, texoptions, "#{@mastertex}.tex"].flatten.compact)
        call_hook('hook_aftertexcompile', Dir.pwd, @basedir, base_dir: @basedir)

        if File.exist?("#{@mastertex}.dvi") && dvicommand.present?
          system_or_raise(*[dvicommand, dvioptions, "#{@mastertex}.dvi"].flatten.compact)
          call_hook('hook_afterdvipdf', Dir.pwd, @basedir, base_dir: @basedir)
        end
      end
    end

    def generate_pdf
      remove_old_file
      @path = build_path
      @img_graph = ReVIEW::ImgGraph.new(@config, 'latex', path_name: '_review_graph')

      begin
        @compile_errors = nil

        book = ReVIEW::Book::Base.new(@basedir, config: @config)
        @converter = ReVIEW::Converter.new(book, ReVIEW::LATEXBuilder.new(img_graph: @img_graph))
        erb_config

        @input_files = make_input_files(book)

        check_compile_status(@config['ignore-errors'])

        begin
          @img_graph.make_mermaid_images
        rescue ApplicationError => e
          error! e.message
        end
        @img_graph.cleanup_graphimg

        # for backward compatibility
        @config['usepackage'] = ''
        @config['usepackage'] = "\\usepackage{#{@config['texstyle']}}" if @config['texstyle']

        if @config['pdfmaker']['use_symlink']
          logger.info 'use symlink'
        end
        copy_images(@config['imagedir'], File.join(@path, @config['imagedir']))
        copy_sty(File.join(Dir.pwd, 'sty'), @path)
        copy_sty(File.join(Dir.pwd, 'sty'), @path, 'fd')
        copy_sty(File.join(Dir.pwd, 'sty'), @path, 'cls')
        copy_sty(File.join(Dir.pwd, 'sty'), @path, 'erb')
        copy_sty(File.join(Dir.pwd, 'sty'), @path, 'tex')
        copy_sty(Dir.pwd, @path, 'tex')

        build_pdf

        FileUtils.cp(File.join(@path, "#{@mastertex}.pdf"), pdf_filepath)
        @logger.success("built #{File.basename(pdf_filepath)}")
      ensure
        FileUtils.remove_entry_secure(@path) unless @config['debug']
      end
    end

    def output_chaps(filename)
      @logger.info "compiling #{filename}.tex"
      begin
        @converter.convert(filename + '.re', File.join(@path, filename + '.tex'))
      rescue StandardError => e
        @compile_errors = true
        error "compile error in #{filename}.tex (#{e.class})"
        error e.message
      end
    end

    # PDFMaker#copy_images should copy image files
    #
    def copy_images(from, to)
      return unless File.exist?(from)

      Dir.mkdir(to)
      if @config['pdfmaker']['use_symlink']
        ReVIEW::MakerHelper.copy_images_to_dir(from, to, use_symlink: true)
      else
        ReVIEW::MakerHelper.copy_images_to_dir(from, to)
      end
    end

    def make_custom_page(file)
      if file.nil?
        return nil
      end

      file_sty = file.to_s.sub(/\.[^.]+\Z/, '.tex')
      if File.exist?(file_sty)
        File.read(file_sty)
      else
        warn "File #{file_sty} is not found."
        nil
      end
    end

    def join_with_separator(value, sep)
      if value.is_a?(Array)
        value.join(sep)
      else
        value
      end
    end

    def make_colophon_role(role)
      if @config[role].present?
        initialize_metachars(@config['texcommand'])
        "#{ReVIEW::I18n.t(role)} & #{escape_latex(join_with_separator(@config.names_of(role), ReVIEW::I18n.t('names_splitter')))} \\\\\n"
      else
        ''
      end
    end

    def make_colophon
      colophon = ''
      @config['colophon_order'].each { |role| colophon += make_colophon_role(role) }
      colophon
    end

    def make_authors
      authors = ''
      if @config['aut'].present?
        author_names = join_with_separator(@config.names_of('aut').map { |s| escape_latex(s) }, ReVIEW::I18n.t('names_splitter'))
        authors = ReVIEW::I18n.t('author_with_label', author_names)
      end
      if @config['csl'].present?
        csl_names = join_with_separator(@config.names_of('csl').map { |s| escape_latex(s) }, ReVIEW::I18n.t('names_splitter'))
        authors += " \\\\\n" + ReVIEW::I18n.t('supervisor_with_label', csl_names)
      end
      if @config['trl'].present?
        trl_names = join_with_separator(@config.names_of('trl').map { |s| escape_latex(s) }, ReVIEW::I18n.t('names_splitter'))
        authors += " \\\\\n" + ReVIEW::I18n.t('translator_with_label', trl_names)
      end
      authors
    end

    def make_history_list
      buf = []
      if @config['history']
        @config['history'].each_with_index do |items, edit|
          items.each_with_index do |item, rev|
            editstr = edit == 0 ? ReVIEW::I18n.t('first_edition') : ReVIEW::I18n.t('nth_edition', (edit + 1).to_s)
            revstr = ReVIEW::I18n.t('nth_impression', (rev + 1).to_s)
            if /\A\d+-\d+-\d+\Z/.match?(item)
              buf << ReVIEW::I18n.t('published_by1', [date_to_s(item), editstr + revstr])
            elsif /\A(\d+-\d+-\d+)[\s　](.+)/.match?(item)
              # custom date with string
              item.match(/\A(\d+-\d+-\d+)[\s　](.+)/) { |m| buf << ReVIEW::I18n.t('published_by3', [date_to_s(m[1]), m[2]]) }
            else
              # free format
              buf << item
            end
          end
        end
      elsif @config['date']
        buf << ReVIEW::I18n.t('published_by2', date_to_s(@config['date']))
      end
      buf
    end

    def date_to_s(date)
      require 'date'
      d = Date.parse(date)
      d.strftime(ReVIEW::I18n.t('date_format'))
    end

    def erb_config
      @texcompiler = File.basename(@config['texcommand'], '.*')
      dclass = @config['texdocumentclass'] || []
      @documentclass = dclass[0] || 'review-jsbook'
      @documentclassoption = dclass[1] || ''
      if @config['dvicommand'] =~ /dvipdfmx/ && @documentclassoption !~ /dvipdfmx/
        @documentclassoption = "dvipdfmx,#{@documentclassoption}".sub(/,\Z/, '')
      end

      @okuduke = make_colophon
      @authors = make_authors

      @custom_coverpage = make_custom_page(@config['cover']) || make_custom_page(@config['coverfile'])
      @custom_titlepage = make_custom_page(@config['titlefile'])
      @custom_originaltitlepage = make_custom_page(@config['originaltitlefile'])
      @custom_creditpage = make_custom_page(@config['creditfile'])

      @custom_profilepage = make_custom_page(@config['profile'])
      @custom_advfilepage = make_custom_page(@config['advfile'])
      if @config['colophon'] && @config['colophon'].is_a?(String)
        @custom_colophonpage = make_custom_page(@config['colophon'])
      end
      @custom_backcoverpage = make_custom_page(@config['backcover'])

      if @config['pubhistory']
        warn 'pubhistory is oboleted. use history.'
      else
        @config['pubhistory'] = make_history_list.join("\n")
      end

      @coverimageoption =
        if @documentclass == 'ubook' || @documentclass == 'utbook'
          'keepaspectratio,angle=90'
        else
          'keepaspectratio'
        end

      if @config.check_version('2', exception: false)
        @coverimageoption =
          if @documentclass == 'ubook' || @documentclass == 'utbook'
            'width=\\textheight,height=\\textwidth,keepaspectratio,angle=90'
          else
            'width=\\textwidth,height=\\textheight,keepaspectratio'
          end
      end

      if @config['coverimage'] && !File.exist?(File.join(@config['imagedir'], @config['coverimage']))
        raise ReVIEW::ConfigError, "coverimage #{@config['coverimage']} is not found."
      end

      @locale_latex = {}
      part_tuple = I18n.get('part').split(/%[A-Za-z]{1,3}/, 2)
      chapter_tuple = I18n.get('chapter').split(/%[A-Za-z]{1,3}/, 2)
      appendix_tuple = I18n.get('appendix').split(/%[A-Za-z]{1,3}/, 2)
      @locale_latex['prepartname'] = part_tuple[0].to_s
      @locale_latex['postpartname'] = part_tuple[1].to_s
      @locale_latex['prechaptername'] = chapter_tuple[0].to_s
      @locale_latex['postchaptername'] = chapter_tuple[1].to_s
      @locale_latex['preappendixname'] = appendix_tuple[0].to_s
      @locale_latex['postappendixname'] = appendix_tuple[1].to_s

      if @config['pdfmaker']['boxsetting']
        begin
          @boxsetting = ReVIEW::LaTeXBox.new.tcbox(@config)
        rescue ReVIEW::ConfigError => e
          error! e
        end
      end
    end

    def latex_config
      result = +ReVIEW::Template.generate(path: './latex/config.erb', mode: '-', binding: binding)
      local_config_file = File.join(@basedir, 'layouts', 'config-local.tex.erb')
      if File.exist?(local_config_file)
        result << "%% BEGIN: config-local.tex.erb\n"
        result << ReVIEW::Template.generate(path: 'layouts/config-local.tex.erb', mode: '-', binding: binding, template_dir: @basedir)
        result << "%% END: config-local.tex.erb\n"
      end
      result
    end

    def template_content
      template_dir = ReVIEW::Template::TEMPLATE_DIR
      template_path = if @config.check_version('2', exception: false)
                        './latex-compat2/layout.tex.erb'
                      else
                        './latex/layout.tex.erb'
                      end
      layout_file = File.join(@basedir, 'layouts', 'layout.tex.erb')
      if File.exist?(layout_file)
        template_dir = @basedir
        template_path = 'layouts/layout.tex.erb'
      end

      if @config['cover'] && !File.exist?(@config['cover'])
        error! "File #{@config['cover']} is not found."
      end

      if @config['titlepage'] && @config['titlefile'] && !File.exist?(@config['titlefile'])
        error! "File #{@config['titlefile']} is not found."
      end

      ReVIEW::Template.generate(path: template_path, mode: '-', binding: binding, template_dir: template_dir)
    rescue StandardError => e
      if defined?(e.full_message)
        error! "template or configuration error: #{e.full_message(highlight: false)}"
      else
        # <= Ruby 2.4
        error! "template or configuration error: #{e.message}"
      end
    end

    def copy_sty(dirname, copybase, extname = 'sty')
      unless File.directory?(dirname)
        warn "No such directory - #{dirname}"
        return
      end

      Dir.open(dirname) do |dir|
        dir.sort.each do |fname|
          next unless File.extname(fname).downcase == '.' + extname

          FileUtils.mkdir_p(copybase)
          if extname == 'erb'
            File.open(File.join(copybase, fname.sub(/\.erb\Z/, '')), 'w') do |f|
              f.print erb_content(File.join(dirname, fname))
            end
          elsif @config['pdfmaker']['use_symlink']
            FileUtils.ln_s(File.join(dirname, fname), copybase)
          else
            FileUtils.cp(File.join(dirname, fname), copybase)
          end
        end
      end
    end
  end
end
