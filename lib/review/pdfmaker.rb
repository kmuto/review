# encoding: utf-8
#
# Copyright (c) 2010-2015 Kenshi Muto and Masayoshi Takahashi
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

require 'review'
require 'review/i18n'
require 'review/converter'
require 'review/latexbuilder'


module ReVIEW
  class PDFMaker

    include FileUtils
    include ReVIEW::LaTeXUtils

    attr_accessor :config, :basedir

    def initialize
      @basedir = nil
    end

    def system_or_raise(*args)
      Kernel.system(*args) or raise("failed to run command: #{args.join(' ')}")
    end

    def error(msg)
      $stderr.puts "#{File.basename($0, '.*')}: error: #{msg}"
      exit 1
    end

    def warn(msg)
      $stderr.puts "#{File.basename($0, '.*')}: warning: #{msg}"
    end

    def pdf_filepath
      File.join(@basedir, @config["bookname"]+".pdf")
    end

    def remove_old_file
      FileUtils.rm_f(pdf_filepath)
    end

    def build_path
      "./#{@config["bookname"]}-pdf"
    end

    def check_compile_status(ignore_errors)
      return unless @compile_errors

      if ignore_errors
        $stderr.puts "compile error, but try to generate PDF file"
      else
        error "compile error, No PDF file output."
      end
    end

    def self.execute(*args)
      self.new.execute(*args)
    end

    def parse_opts(args)
      cmd_config = Hash.new
      opts = OptionParser.new

      opts.banner = "Usage: review-pdfmaker configfile"
      opts.version = ReVIEW::VERSION
      opts.on('--help', 'Prints this message and quit.') do
        puts opts.help
        exit 0
      end
      opts.on('--[no-]debug', 'Keep temporary files.') do |debug|
        cmd_config["debug"] = debug
      end
      opts.on('--ignore-errors', 'Ignore review-compile errors.') do
        cmd_config["ignore-errors"] = true
      end

      opts.parse!(args)
      if args.size != 1
        puts opts.help
        exit 0
      end

      return cmd_config, args[0]
    end

    def execute(*args)
      @config = ReVIEW::Configure.values
      cmd_config, yamlfile = parse_opts(args)

      @config.merge!(YAML.load_file(yamlfile))
      # YAML configs will be overridden by command line options.
      @config.merge!(cmd_config)
      I18n.setup(@config["language"])
      @basedir = File.dirname(yamlfile)
      generate_pdf(yamlfile)
    end

    def generate_pdf(yamlfile)
      remove_old_file
      @path = build_path()
      Dir.mkdir(@path)

      @chaps_fnames = Hash.new{|h, key| h[key] = ""}
      @compile_errors = nil

      book = ReVIEW::Book.load(@basedir)
      book.config = @config
      @converter = ReVIEW::Converter.new(book, ReVIEW::LATEXBuilder.new)
      book.parts.each do |part|
        if part.name.present?
          if part.file?
            output_chaps(part.name, yamlfile)
            @chaps_fnames["CHAPS"] << %Q|\\input{#{part.name}.tex}\n|
          else
            @chaps_fnames["CHAPS"] << %Q|\\part{#{part.name}}\n|
          end
        end

        part.chapters.each do |chap|
          filename = File.basename(chap.path, ".*")
          output_chaps(filename, yamlfile)
          @chaps_fnames["PREDEF"] << "\\input{#{filename}.tex}\n" if chap.on_PREDEF?
          @chaps_fnames["CHAPS"] << "\\input{#{filename}.tex}\n" if chap.on_CHAPS?
          @chaps_fnames["APPENDIX"] << "\\input{#{filename}.tex}\n" if chap.on_APPENDIX?
          @chaps_fnames["POSTDEF"] << "\\input{#{filename}.tex}\n" if chap.on_POSTDEF?
        end
      end

      check_compile_status(@config["ignore-errors"])

      @config["pre_str"] = @chaps_fnames["PREDEF"]
      @config["chap_str"] = @chaps_fnames["CHAPS"]
      @config["appendix_str"] = @chaps_fnames["APPENDIX"]
      @config["post_str"] = @chaps_fnames["POSTDEF"]

      @config["usepackage"] = ""
      if @config["texstyle"]
        @config["usepackage"] = "\\usepackage{#{@config['texstyle']}}"
      end

      copy_images("./images", File.join(@path, "images"))
      copyStyToDir(File.join(Dir.pwd, "sty"), @path)
      copyStyToDir(File.join(Dir.pwd, "sty"), @path, "fd")
      copyStyToDir(File.join(Dir.pwd, "sty"), @path, "cls")
      copyStyToDir(Dir.pwd, @path, "tex")

      Dir.chdir(@path) do
        template = get_template
        File.open("./book.tex", "wb"){|f| f.write(template)}

        call_hook("hook_beforetexcompile")

        ## do compile
        kanji = 'utf8'
        texcommand = "platex"
        texoptions = "-kanji=#{kanji}"
        dvicommand = "dvipdfmx"
        dvioptions = "-d 5"

        if ENV["REVIEW_SAFE_MODE"].to_i & 4 > 0
          warn "command configuration is prohibited in safe mode. ignored."
        else
          texcommand = @config["texcommand"] if @config["texcommand"]
          dvicommand = @config["dvicommand"] if @config["dvicommand"]
          dvioptions = @config["dvioptions"] if @config["dvioptions"]
          texoptions = @config["texoptions"] if @config["texoptions"]
        end
        3.times do
          system_or_raise("#{texcommand} #{texoptions} book.tex")
        end
        call_hook("hook_aftertexcompile")

        if File.exist?("book.dvi")
          system_or_raise("#{dvicommand} #{dvioptions} book.dvi")
        end
      end
      call_hook("hook_afterdvipdf")

      FileUtils.cp(File.join(@path, "book.pdf"), pdf_filepath)

      unless @config["debug"]
        remove_entry_secure @path
      end
    end

    def output_chaps(filename, yamlfile)
      $stderr.puts "compiling #{filename}.tex"
      begin
        @converter.convert(filename+".re", File.join(@path, filename+".tex"))
      rescue => e
        @compile_errors = true
        warn "compile error in #{filename}.tex (#{e.class})"
        warn e.message
      end
    end

    # PDFMaker#copy_images should copy image files _AND_ execute extractbb (or ebb).
    #
    def copy_images(from, to)
      if File.exist?(from)
        Dir.mkdir(to)
        ReVIEW::MakerHelper.copy_images_to_dir(from, to)
        Dir.chdir(to) do
          images = Dir.glob("**/*").find_all{|f|
            File.file?(f) and f =~ /\.(jpg|jpeg|png|pdf)\z/
          }
          break if images.empty?
          system("extractbb", *images)
          unless system("extractbb", "-m", *images)
            system_or_raise("ebb", *images)
          end
        end
      end
    end

    def make_custom_page(file)
      file_sty = file.to_s.sub(/\.[^.]+$/, ".tex")
      if File.exist?(file_sty)
        File.read(file_sty)
      else
        nil
      end
    end

    def join_with_separator(value, sep)
      if value.kind_of? Array
        value.join(sep)
      else
        value
      end
    end

    def make_colophon_role(role)
      if @config[role].present?
        return "#{ReVIEW::I18n.t(role)} & #{escape_latex(join_with_separator(@config[role], ReVIEW::I18n.t("names_splitter")))} \\\\\n"
      else
        ""
      end
    end

    def make_colophon
      colophon = ""
      @config["colophon_order"].each do |role|
        colophon += make_colophon_role(role)
      end
      colophon
    end

    def make_authors
      authors = ""
      if @config["aut"].present?
        author_names = join_with_separator(@config["aut"], ReVIEW::I18n.t("names_splitter"))
        authors = ReVIEW::I18n.t("author_with_label", author_names)
      end
      if @config["csl"].present?
        csl_names = join_with_separator(@config["csl"], ReVIEW::I18n.t("names_splitter"))
        authors += " \\\\\n"+ ReVIEW::I18n.t("supervisor_with_label", csl_names)
      end
      if @config["trl"].present?
        trl_names = join_with_separator(@config["trl"], ReVIEW::I18n.t("names_splitter"))
        authors += " \\\\\n"+ ReVIEW::I18n.t("translator_with_label", trl_names)
      end
      authors
    end

    def get_template
      dclass = @config["texdocumentclass"] || []
      documentclass = dclass[0] || "jsbook"
      documentclassoption = dclass[1] || "oneside"

      okuduke = make_colophon
      authors = make_authors

      custom_titlepage = make_custom_page(@config["cover"]) || make_custom_page(@config["coverfile"])
      custom_originaltitlepage = make_custom_page(@config["originaltitlefile"])
      custom_creditpage = make_custom_page(@config["creditfile"])

      custom_profilepage = make_custom_page(@config["profile"])
      custom_advfilepage = make_custom_page(@config["advfile"])
      if @config["colophon"] && @config["colophon"].kind_of?(String)
        custom_colophonpage = make_custom_page(@config["colophon"])
      end
      custom_backcoverpage = make_custom_page(@config["backcover"])

      template = File.expand_path('layout.tex.erb', File.dirname(__FILE__))
      layout_file = File.join(@basedir, "layouts", "layout.tex.erb")
      if File.exist?(layout_file)
        template = layout_file
      end

      erb = ERB.new(File.read(template))
      values = @config # must be 'values' for legacy files
      erb.result(binding)
    end

    def copyStyToDir(dirname, copybase, extname = "sty")
      unless File.directory?(dirname)
        warn "No such directory - #{dirname}"
        return
      end

      Dir.open(dirname) do |dir|
        dir.each do |fname|
          if File.extname(fname).downcase == "."+extname
            FileUtils.mkdir_p(copybase)
            FileUtils.cp File.join(dirname, fname), copybase
          end
        end
      end
    end

    def call_hook(hookname)
      if @config["pdfmaker"].instance_of?(Hash) && @config["pdfmaker"][hookname]
        hook = File.absolute_path(@config["pdfmaker"][hookname], @basedir)
        if ENV["REVIEW_SAFE_MODE"].to_i & 1 > 0
          warn "hook configuration is prohibited in safe mode. ignored."
        else
          system_or_raise("#{hook} #{Dir.pwd} #{@basedir}")
        end
      end
    end
  end
end

