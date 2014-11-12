# encoding: utf-8
#
# Copyright (c) 2010-2014 Kenshi Muto and Masayoshi Takahashi
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


module ReVIEW
  class PDFMaker

    include FileUtils
    include ReVIEW::LaTeXUtils

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

    def check_book(config)
      pdf_file = config["bookname"]+".pdf"
      if File.exist? pdf_file
        error "file already exists:#{pdf_file}"
      end
    end

    def build_path(config)
      "./#{config["bookname"]}-pdf"
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
      config = ReVIEW::Configure.values
      cmd_config, yamlfile = parse_opts(args)

      config.merge!(YAML.load_file(yamlfile))
      # YAML configs will be overridden by command line options.
      config.merge!(cmd_config)
      generate_pdf(config)
    end

    def generate_pdf(config)
      check_book(config)
      @basedir = Dir.pwd
      @path = build_path(config)
      bookname = config["bookname"]
      Dir.mkdir(@path)

      @chaps_fnames = Hash.new{|h, key| h[key] = ""}
      @compile_errors = nil

      ReVIEW::Book.load(@basedir).parts.each do |part|
        if part.name.present?
          if part.file?
            output_parts(part.name, config)
            @chaps_fnames["CHAPS"] << %Q|\\input{#{part.name}.tex}\n|
          else
            @chaps_fnames["CHAPS"] << %Q|\\part{#{part.name}}\n|
          end
        end

        part.chapters.each do |chap|
          filename = "#{File.basename(chap.path, ".*")}.tex"
          output_chaps(filename, config)
          @chaps_fnames["PREDEF"]  << "\\input{#{filename}}\n" if chap.on_PREDEF?
          @chaps_fnames["CHAPS"]   << "\\input{#{filename}}\n" if chap.on_CHAPS?
          @chaps_fnames["APPENDIX"] << "\\input{#{filename}}\n" if chap.on_APPENDIX?
          @chaps_fnames["POSTDEF"] << "\\input{#{filename}}\n" if chap.on_POSTDEF?
        end
      end

      check_compile_status(config["ignore-errors"])

      config["pre_str"]  = @chaps_fnames["PREDEF"]
      config["chap_str"] = @chaps_fnames["CHAPS"]
      config["appendix_str"] = @chaps_fnames["APPENDIX"]
      config["post_str"] = @chaps_fnames["POSTDEF"]

      config["usepackage"] = ""
      if config["texstyle"]
        config["usepackage"] = "\\usepackage{#{config['texstyle']}}"
      end

      copy_images("./images", "#{@path}/images")
      copyStyToDir(Dir.pwd + "/sty", @path)
      copyStyToDir(Dir.pwd, @path, "tex")

      Dir.chdir(@path) {
        template = get_template(config)
        File.open("./book.tex", "wb"){|f| f.write(template)}

        ## do compile
        enc = config["params"].to_s.split(/\s+/).find{|i| i =~ /\A--outencoding=/ }
        kanji = 'utf8'
        if enc
          kanji = enc.split(/\=/).last.gsub(/-/, '').downcase
        end
        texcommand = config["texcommand"] || "platex"
        3.times do
          system_or_raise("#{texcommand} -kanji=#{kanji} book.tex")
        end
        if File.exist?("book.dvi")
          system_or_raise("dvipdfmx -d 5 book.dvi")
        end
      }
      FileUtils.cp("#{@path}/book.pdf", "#{@basedir}/#{bookname}.pdf")

      unless config["debug"]
        remove_entry_secure @path
      end
    end

    def output_chaps(filename, config)
      $stderr.puts "compiling #{filename}"
      cmd = "#{ReVIEW::MakerHelper.bindir}/review-compile --target=latex --level=#{config["secnolevel"]} --toclevel=#{config["toclevel"]} #{config["params"]} #{filename} > #{@path}/#{filename}"
      if system cmd
        # OK
      else
        @compile_errors = true
        warn cmd
      end
    end

    def output_parts(filename, config)
      $stderr.puts "compiling #{filename}.tex"
      cmd = "review-compile --target=latex --level=#{config["secnolevel"]} --toclevel=#{config["toclevel"]} #{config["params"]} #{filename}.re | sed -e s/\\chapter{/\\part{/ > #{@path}/#{filename}.tex"
      if system cmd
        # OK
      else
        @compile_errors = true
        warn cmd
      end
    end


    def copy_images(from, to)
      if File.exist?(from)
        Dir.mkdir(to)
        ReVIEW::MakerHelper.copy_images_to_dir(from, to)
        Dir.chdir(to) do
          images = Dir.glob("**/*").find_all{|f|
            File.file?(f) and f =~ /\.(jpg|jpeg|png|pdf)\z/
          }
          system("extractbb", *images)
          unless system("extractbb", "-m", *images)
            system_or_raise("ebb", *images)
          end
        end
      end
    end

    def make_custom_titlepage(coverfile)
      coverfile_sty = coverfile.to_s.sub(/\.[^.]+$/, ".tex")
      if File.exist?(coverfile_sty)
        File.read(coverfile_sty)
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

    def make_colophon_role(role, config)
      if config[role].present?
        return "#{ReVIEW::I18n.t(role)} & #{escape_latex(join_with_separator(config[role], ReVIEW::I18n.t("names_splitter")))} \\\\\n"
      else
        ""
      end
    end

    def make_colophon(config)
      colophon = ""
      config["colophon_order"].each do |role|
        colophon += make_colophon_role(role, config)
      end
      colophon
    end

    def make_authors(config)
      authors = ""
      if config["aut"].present?
        authors = join_with_separator(config["aut"], ReVIEW::I18n.t("names_splitter")) + ReVIEW::I18n.t("author_postfix")
      end
      if config["csl"].present?
        authors += " \\\\\n"+join_with_separator(config["csl"], ReVIEW::I18n.t("names_splitter")) + ReVIEW::I18n.t("supervisor_postfix")
      end
      if config["trl"].present?
        authors += " \\\\\n"+join_with_separator(config["trl"], ReVIEW::I18n.t("names_splitter")) + ReVIEW::I18n.t("translator_postfix")
      end
      authors
    end

    def get_template(config)
      dclass = config["texdocumentclass"] || []
      documentclass =  dclass[0] || "jsbook"
      documentclassoption =  dclass[1] || "oneside"

      okuduke = make_colophon(config)
      authors = make_authors(config)

      custom_titlepage = make_custom_titlepage(config["coverfile"])

      template = File.expand_path('layout.tex.erb', File.dirname(__FILE__))
      layout_file = File.join(@basedir, "layouts", "layout.tex.erb")
      if File.exist?(layout_file)
        template = layout_file
      end

      erb = ERB.new(File.open(template).read)
      values = config # must be 'values' for legacy files
      erb.result(binding)
    end

    def copyStyToDir(dirname, copybase, extname = "sty")
      unless File.directory?(dirname)
        $stderr.puts "No such directory - #{dirname}"
        return
      end

      Dir.open(dirname) {|dir|
        dir.each {|fname|
          next if fname =~ /^\./
          if fname =~ /\.(#{extname})$/i
            Dir.mkdir(copybase) unless File.exist?(copybase)
            FileUtils.cp "#{dirname}/#{fname}", copybase
          end
        }
      }
    end
  end
end

