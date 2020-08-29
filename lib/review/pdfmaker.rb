# Copyright (c) 2010-2020 Kenshi Muto and Masayoshi Takahashi
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

module ReVIEW
  class PDFMaker
    include FileUtils
    include ReVIEW::LaTeXUtils

    attr_accessor :config, :basedir

    def initialize
      @basedir = nil
      @logger = ReVIEW.logger
      @input_files = Hash.new { |h, key| h[key] = '' }
      @mastertex = '__REVIEW_BOOK__'
    end

    def system_with_info(*args)
      @logger.info args.join(' ')
      out, status = Open3.capture2e(*args)
      unless status.success?
        @logger.error "execution error\n\nError log:\n" + out
      end
    end

    def system_or_raise(*args)
      @logger.info args.join(' ')
      out, status = Open3.capture2e(*args)
      unless status.success?
        error "failed to run command: #{args.join(' ')}\n\nError log:\n" + out
      end
    end

    def error(msg)
      @logger.error msg
      exit 1
    end

    def warn(msg)
      @logger.warn msg
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
        if File.exist?(path)
          FileUtils.rm_rf(path, secure: true)
        end
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
        error 'compile error, No PDF file output.'
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
      error "#{yamlfile} not found." unless File.exist?(yamlfile)

      @config = ReVIEW::Configure.create(maker: 'pdfmaker',
                                         yamlfile: yamlfile,
                                         config: cmd_config)

      I18n.setup(@config['language'])
      @basedir = File.absolute_path(File.dirname(yamlfile))

      begin
        @config.check_version(ReVIEW::VERSION)
      rescue ReVIEW::ConfigError => e
        warn e.message
      end

      # version 2 compatibility
      unless @config['texdocumentclass']
        if @config.check_version(2, exception: false)
          @config['texdocumentclass'] = ['jsbook', 'uplatex,oneside']
        else
          @config['texdocumentclass'] = @config['_texdocumentclass']
        end
      end

      begin
        generate_pdf
      rescue ApplicationError => e
        raise if @config['debug']
        error(e.message)
      end
    end

    def make_input_files(book)
      input_files = Hash.new { |h, key| h[key] = '' }
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
        File.open("./#{@mastertex}.tex", 'wb') { |f| f.write template }

        call_hook('hook_beforetexcompile')

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
            error "texcommand isn't defined."
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

        call_hook('hook_beforemakeindex')
        if @config['pdfmaker']['makeindex'] && File.size?("#{@mastertex}.idx")
          system_or_raise(*[makeindex_command, makeindex_options, @mastertex].flatten.compact)
          system_or_raise(*[texcommand, texoptions, "#{@mastertex}.tex"].flatten.compact)
        end
        call_hook('hook_aftermakeindex')

        system_or_raise(*[texcommand, texoptions, "#{@mastertex}.tex"].flatten.compact)
        call_hook('hook_aftertexcompile')

        if File.exist?("#{@mastertex}.dvi") && dvicommand.present?
          system_or_raise(*[dvicommand, dvioptions, "#{@mastertex}.dvi"].flatten.compact)
          call_hook('hook_afterdvipdf')
        end
      end
    end

    def generate_pdf
      remove_old_file
      erb_config
      @path = build_path
      begin
        @compile_errors = nil

        book = ReVIEW::Book::Base.load(@basedir, config: @config)
        @converter = ReVIEW::Converter.new(book, ReVIEW::LATEXBuilder.new)

        @input_files = make_input_files(book)

        check_compile_status(@config['ignore-errors'])

        # for backward compatibility
        @config['usepackage'] = ''
        @config['usepackage'] = "\\usepackage{#{@config['texstyle']}}" if @config['texstyle']

        copy_images(@config['imagedir'], File.join(@path, @config['imagedir']))
        copy_sty(File.join(Dir.pwd, 'sty'), @path)
        copy_sty(File.join(Dir.pwd, 'sty'), @path, 'fd')
        copy_sty(File.join(Dir.pwd, 'sty'), @path, 'cls')
        copy_sty(File.join(Dir.pwd, 'sty'), @path, 'erb')
        copy_sty(File.join(Dir.pwd, 'sty'), @path, 'tex')
        copy_sty(Dir.pwd, @path, 'tex')

        build_pdf

        FileUtils.cp(File.join(@path, "#{@mastertex}.pdf"), pdf_filepath)
      ensure
        remove_entry_secure(@path) unless @config['debug']
      end
    end

    def output_chaps(filename)
      @logger.info "compiling #{filename}.tex"
      begin
        @converter.convert(filename + '.re', File.join(@path, filename + '.tex'))
      rescue => e
        @compile_errors = true
        warn "compile error in #{filename}.tex (#{e.class})"
        warn e.message
      end
    end

    # PDFMaker#copy_images should copy image files
    #
    def copy_images(from, to)
      return unless File.exist?(from)
      Dir.mkdir(to)
      ReVIEW::MakerHelper.copy_images_to_dir(from, to)
    end

    def make_custom_page(file)
      file_sty = file.to_s.sub(/\.[^.]+\Z/, '.tex')
      if File.exist?(file_sty)
        return File.read(file_sty)
      end
      nil
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
            if item =~ /\A\d+-\d+-\d+\Z/
              buf << ReVIEW::I18n.t('published_by1', [date_to_s(item), editstr + revstr])
            elsif item =~ /\A(\d+-\d+-\d+)[\s　](.+)/
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
    end

    def erb_content(file)
      @texcompiler = File.basename(@config['texcommand'], '.*')
      erb = ReVIEW::Template.load(file, '-')
      @logger.debug("erb processes #{File.basename(file)}") if @config['debug']
      erb.result(binding)
    end

    def latex_config
      result = erb_content(File.expand_path('./latex/config.erb', ReVIEW::Template::TEMPLATE_DIR))
      local_config_file = File.join(@basedir, 'layouts', 'config-local.tex.erb')
      if File.exist?(local_config_file)
        result << "%% BEGIN: config-local.tex.erb\n"
        result << erb_content(local_config_file)
        result << "%% END: config-local.tex.erb\n"
      end
      result
    end

    def template_content
      template = File.expand_path('./latex/layout.tex.erb', ReVIEW::Template::TEMPLATE_DIR)
      if @config.check_version('2', exception: false)
        template = File.expand_path('./latex-compat2/layout.tex.erb', ReVIEW::Template::TEMPLATE_DIR)
      end
      layout_file = File.join(@basedir, 'layouts', 'layout.tex.erb')
      if File.exist?(layout_file)
        template = layout_file
      end
      erb_content(template)
    end

    def copy_sty(dirname, copybase, extname = 'sty')
      unless File.directory?(dirname)
        warn "No such directory - #{dirname}"
        return
      end

      Dir.open(dirname) do |dir|
        dir.sort.each do |fname|
          next unless File.extname(fname).downcase == '.' + extname
          FileUtils.mkdir_p(copybase) unless Dir.exist?(copybase)
          if extname == 'erb'
            File.open(File.join(copybase, fname.sub(/\.erb\Z/, '')), 'w') do |f|
              f.print erb_content(File.join(dirname, fname))
            end
          else
            FileUtils.cp(File.join(dirname, fname), copybase)
          end
        end
      end
    end

    def call_hook(hookname)
      return if !@config['pdfmaker'].is_a?(Hash) || @config['pdfmaker'][hookname].nil?
      hook = File.absolute_path(@config['pdfmaker'][hookname], @basedir)
      if ENV['REVIEW_SAFE_MODE'].to_i & 1 > 0
        warn 'hook configuration is prohibited in safe mode. ignored.'
      else
        system_or_raise(hook, Dir.pwd, @basedir)
      end
    end
  end
end
