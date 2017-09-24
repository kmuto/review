# Copyright (c) 2010-2017 Kenshi Muto and Masayoshi Takahashi
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

    attr_accessor :config, :basedir, :basehookdir

    def initialize
      @basedir = nil
      @basehookdir = nil
      @logger = ReVIEW.logger
      @input_files = Hash.new { |h, key| h[key] = '' }
    end

    def system_or_raise(*args)
      Kernel.system(*args) or raise("failed to run command: #{args.join(' ')}")
    end

    def error(msg)
      @logger.error "#{File.basename($PROGRAM_NAME, '.*')}: #{msg}"
      exit 1
    end

    def warn(msg)
      @logger.warn "#{File.basename($PROGRAM_NAME, '.*')}: #{msg}"
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
        FileUtils.rm_rf(path, secure: true) if File.exist?(path)
        Dir.mkdir(path)
        path
      else
        Dir.mktmpdir("#{@config['bookname']}-pdf-")
      end
    end

    def check_compile_status(ignore_errors)
      return unless @compile_errors

      if ignore_errors
        $stderr.puts 'compile error, but try to generate PDF file'
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

      opts.banner = 'Usage: review-pdfmaker configfile'
      opts.version = ReVIEW::VERSION
      opts.on('--help', 'Prints this message and quit.') do
        puts opts.help
        exit 0
      end
      opts.on('--[no-]debug', 'Keep temporary files.') { |debug| cmd_config['debug'] = debug }
      opts.on('--ignore-errors', 'Ignore review-compile errors.') { cmd_config['ignore-errors'] = true }

      opts.parse!(args)
      if args.size != 1
        puts opts.help
        exit 0
      end

      [cmd_config, args[0]]
    end

    def execute(*args)
      @config = ReVIEW::Configure.values
      @config.maker = 'pdfmaker'
      cmd_config, yamlfile = parse_opts(args)
      loader = ReVIEW::YAMLLoader.new
      @config.deep_merge!(loader.load_file(yamlfile))
      # YAML configs will be overridden by command line options.
      @config.merge!(cmd_config)
      I18n.setup(@config['language'])
      @basedir = File.dirname(yamlfile)
      @basehookdir = File.absolute_path(File.dirname(yamlfile))

      begin
        @config.check_version(ReVIEW::VERSION)
      rescue ReVIEW::ConfigError => e
        warn e.message
      end
      generate_pdf(yamlfile)
    end

    def make_input_files(book, yamlfile)
      input_files = Hash.new { |h, key| h[key] = '' }
      book.parts.each do |part|
        if part.name.present?
          if part.file?
            output_chaps(part.name, yamlfile)
            input_files['CHAPS'] << %Q(\\input{#{part.name}.tex}\n)
          else
            input_files['CHAPS'] << %Q(\\part{#{part.name}}\n)
          end
        end

        part.chapters.each do |chap|
          filename = File.basename(chap.path, '.*')
          output_chaps(filename, yamlfile)
          input_files['PREDEF'] << "\\input{#{filename}.tex}\n" if chap.on_predef?
          input_files['CHAPS'] << "\\input{#{filename}.tex}\n" if chap.on_chaps?
          input_files['APPENDIX'] << "\\input{#{filename}.tex}\n" if chap.on_appendix?
          input_files['POSTDEF'] << "\\input{#{filename}.tex}\n" if chap.on_postdef?
        end
      end

      input_files
    end

    def build_pdf
      template = template_content
      Dir.chdir(@path) do
        File.open('./book.tex', 'wb') { |f| f.write(template) }

        call_hook('hook_beforetexcompile')

        ## do compile
        if ENV['REVIEW_SAFE_MODE'].to_i & 4 > 0
          warn 'command configuration is prohibited in safe mode. ignored.'
          texcommand = ReVIEW::Configure.values['texcommand']
          dvicommand = ReVIEW::Configure.values['dvicommand']
          dvioptions = ReVIEW::Configure.values['dvioptions']
          texoptions = ReVIEW::Configure.values['texoptions']
          makeindex_command = ReVIEW::Configure.values['pdfmaker']['makeindex_command']
          makeindex_options = ReVIEW::Configure.values['pdfmaker']['makeindex_options']
          makeindex_sty = ReVIEW::Configure.values['pdfmaker']['makeindex_sty']
          makeindex_dic = ReVIEW::Configure.values['pdfmaker']['makeindex_dic']
        else
          texcommand = @config['texcommand'] if @config['texcommand']
          dvicommand = @config['dvicommand'] if @config['dvicommand']
          dvioptions = @config['dvioptions'] if @config['dvioptions']
          texoptions = @config['texoptions'] if @config['texoptions']
          makeindex_command = @config['pdfmaker']['makeindex_command']
          makeindex_options = @config['pdfmaker']['makeindex_options']
          makeindex_sty = @config['pdfmaker']['makeindex_sty']
          makeindex_dic = @config['pdfmaker']['makeindex_dic']
        end

        if makeindex_sty.present?
          makeindex_sty = File.absolute_path(makeindex_sty, @basedir)
          makeindex_options += " -s #{makeindex_sty}" if File.exist?(makeindex_sty)
        end
        if makeindex_dic.present?
          makeindex_dic = File.absolute_path(makeindex_dic, @basedir)
          makeindex_options += " -d #{makeindex_dic}" if File.exist?(makeindex_dic)
        end

        2.times do
          system_or_raise("#{texcommand} #{texoptions} book.tex")
        end

        call_hook('hook_beforemakeindex')
        system_or_raise("#{makeindex_command} #{makeindex_options} book") if @config['pdfmaker']['makeindex'] && File.exist?('book.idx')
        call_hook('hook_aftermakeindex')

        system_or_raise("#{texcommand} #{texoptions} book.tex")
        call_hook('hook_aftertexcompile')

        if File.exist?('book.dvi')
          system_or_raise("#{dvicommand} #{dvioptions} book.dvi")
          call_hook('hook_afterdvipdf')
        end
      end
    end

    def generate_pdf(yamlfile)
      remove_old_file
      @path = build_path
      begin
        @compile_errors = nil

        book = ReVIEW::Book.load(@basedir)
        book.config = @config
        @converter = ReVIEW::Converter.new(book, ReVIEW::LATEXBuilder.new)

        @input_files = make_input_files(book, yamlfile)

        check_compile_status(@config['ignore-errors'])

        @config['usepackage'] = ''
        @config['usepackage'] = "\\usepackage{#{@config['texstyle']}}" if @config['texstyle']

        copy_images(@config['imagedir'], File.join(@path, @config['imagedir']))
        copy_sty(File.join(Dir.pwd, 'sty'), @path)
        copy_sty(File.join(Dir.pwd, 'sty'), @path, 'fd')
        copy_sty(File.join(Dir.pwd, 'sty'), @path, 'cls')
        copy_sty(Dir.pwd, @path, 'tex')

        build_pdf

        FileUtils.cp(File.join(@path, 'book.pdf'), pdf_filepath)
      ensure
        remove_entry_secure @path unless @config['debug']
      end
    end

    def output_chaps(filename, _yamlfile)
      $stderr.puts "compiling #{filename}.tex"
      begin
        @converter.convert(filename + '.re', File.join(@path, filename + '.tex'))
      rescue => e
        @compile_errors = true
        warn "compile error in #{filename}.tex (#{e.class})"
        warn e.message
      end
    end

    # PDFMaker#copy_images should copy image files _AND_ execute extractbb (or ebb).
    #
    def copy_images(from, to)
      return unless File.exist?(from)
      Dir.mkdir(to)
      ReVIEW::MakerHelper.copy_images_to_dir(from, to)
      Dir.chdir(to) do
        images = Dir.glob('**/*').find_all { |f| File.file?(f) and f =~ /\.(jpg|jpeg|png|pdf|ai|eps|tif)\z/ }
        break if images.empty?
        system('extractbb', *images)
        system_or_raise('ebb', *images) unless system('extractbb', '-m', *images)
      end
    end

    def make_custom_page(file)
      file_sty = file.to_s.sub(/\.[^.]+\Z/, '.tex')
      return File.read(file_sty) if File.exist?(file_sty)
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
            if item =~ /\A\d+\-\d+\-\d+\Z/
              buf << ReVIEW::I18n.t('published_by1', [date_to_s(item), editstr + revstr])
            elsif item =~ /\A(\d+\-\d+\-\d+)[\s　](.+)/
              # custom date with string
              item.match(/\A(\d+\-\d+\-\d+)[\s　](.+)/) { |m| buf << ReVIEW::I18n.t('published_by3', [date_to_s(m[1]), m[2]]) }
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

    def template_content
      dclass = @config['texdocumentclass'] || []
      @documentclass = dclass[0] || 'jsbook'
      @documentclassoption = dclass[1] || 'uplatex,oneside'

      @okuduke = make_colophon
      @authors = make_authors

      @custom_titlepage = make_custom_page(@config['cover']) || make_custom_page(@config['coverfile'])
      @custom_originaltitlepage = make_custom_page(@config['originaltitlefile'])
      @custom_creditpage = make_custom_page(@config['creditfile'])

      @custom_profilepage = make_custom_page(@config['profile'])
      @custom_advfilepage = make_custom_page(@config['advfile'])
      @custom_colophonpage = make_custom_page(@config['colophon']) if @config['colophon'] && @config['colophon'].is_a?(String)
      @custom_backcoverpage = make_custom_page(@config['backcover'])

      if @config['pubhistory']
        warn 'pubhistory is oboleted. use history.'
      else
        @config['pubhistory'] = make_history_list.join("\n")
      end

      @coverimageoption =
        if @documentclass == 'ubook' || @documentclass == 'utbook'
          'width=\\textheight,height=\\textwidth,keepaspectratio,angle=90'
        else
          'width=\\textwidth,height=\\textheight,keepaspectratio'
        end

      @locale_latex = {}
      part_tuple = I18n.get('part').split(/\%[A-Za-z]{1,3}/, 2)
      chapter_tuple = I18n.get('chapter').split(/\%[A-Za-z]{1,3}/, 2)
      appendix_tuple = I18n.get('appendix').split(/\%[A-Za-z]{1,3}/, 2)
      @locale_latex['prepartname'] = part_tuple[0]
      @locale_latex['postpartname'] = part_tuple[1]
      @locale_latex['prechaptername'] = chapter_tuple[0]
      @locale_latex['postchaptername'] = chapter_tuple[1]
      @locale_latex['preappendixname'] = appendix_tuple[0]
      @locale_latex['postappendixname'] = appendix_tuple[1]

      template = File.expand_path('./latex/layout.tex.erb', ReVIEW::Template::TEMPLATE_DIR)
      layout_file = File.join(@basedir, 'layouts', 'layout.tex.erb')
      template = layout_file if File.exist?(layout_file)

      @texcompiler = File.basename(@config['texcommand'], '.*')

      erb = ReVIEW::Template.load(template, '-')
      erb.result(binding)
    end

    def copy_sty(dirname, copybase, extname = 'sty')
      unless File.directory?(dirname)
        warn "No such directory - #{dirname}"
        return
      end

      Dir.open(dirname) do |dir|
        dir.each do |fname|
          if File.extname(fname).downcase == '.' + extname
            FileUtils.mkdir_p(copybase)
            FileUtils.cp File.join(dirname, fname), copybase
          end
        end
      end
    end

    def call_hook(hookname)
      return if !@config['pdfmaker'].is_a?(Hash) || @config['pdfmaker'][hookname].nil?
      hook = File.absolute_path(@config['pdfmaker'][hookname], @basehookdir)
      if ENV['REVIEW_SAFE_MODE'].to_i & 1 > 0
        warn 'hook configuration is prohibited in safe mode. ignored.'
      else
        system_or_raise("#{hook} #{Dir.pwd} #{@basehookdir}")
      end
    end
  end
end
