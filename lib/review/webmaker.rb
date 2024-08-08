# Copyright (c) 2016-2022 Masayoshi Takahashi, Masanori Kado, Kenshi Muto
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

require 'review/i18n'
require 'review/converter'
require 'review/configure'
require 'review/book'
require 'review/htmlbuilder'
require 'review/yamlloader'
require 'review/template'
require 'review/tocprinter'
require 'review/version'
require 'review/makerhelper'
require 'review/img_math'
require 'review/loggable'

module ReVIEW
  class WEBMaker
    include ERB::Util
    include MakerHelper
    include Loggable

    attr_accessor :config, :basedir

    def initialize
      @basedir = nil
      @logger = ReVIEW.logger
      @img_math = nil
      @compile_errors = nil
    end

    def self.execute(*args)
      self.new.execute(*args)
    end

    def parse_opts(args)
      cmd_config = {}
      opts = OptionParser.new
      @buildonly = nil

      opts.banner = 'Usage: review-webmaker [option] configfile'
      opts.version = ReVIEW::VERSION
      opts.on('--help', 'Prints this message and quit.') do
        puts opts.help
        exit 0
      end
      opts.on('--ignore-errors', 'Ignore review-compile errors.') { cmd_config['ignore-errors'] = true }
      opts.on('-y', '--only file1,file2,...', 'Build only specified files.') { |v| @buildonly = v.split(/\s*,\s*/).map { |m| m.strip.sub(/\.re\Z/, '') } }

      opts.parse!(args)
      if args.size != 1
        puts opts.help
        exit 0
      end

      [cmd_config, args[0]]
    end

    def build_path
      @config['docroot'] || 'webroot'
    end

    def remove_old_files(path)
      @img_math.cleanup_mathimg
      FileUtils.rm_rf(path)
    end

    def execute(*args)
      cmd_config, yamlfile = parse_opts(args)
      error! "#{yamlfile} not found." unless File.exist?(yamlfile)

      begin
        @config = ReVIEW::Configure.create(maker: 'webmaker',
                                           yamlfile: yamlfile,
                                           config: cmd_config)
      rescue ReVIEW::ConfigError => e
        error! e.message
      end

      @config['htmlext'] = 'html'
      @img_math = ReVIEW::ImgMath.new(@config)

      I18n.setup(@config['language'])
      begin
        generate_html_files(yamlfile)
        @logger.success("built #{build_path}")
      rescue ApplicationError => e
        raise if @config['debug']

        error! e.message
      end
    end

    def generate_html_files(yamlfile)
      @basedir = File.dirname(yamlfile)
      @path = build_path
      remove_old_files(@path)
      Dir.mkdir(@path)

      @book = ReVIEW::Book::Base.new(@basedir, config: @config)
      @converter = ReVIEW::Converter.new(@book, ReVIEW::HTMLBuilder.new(img_math: @img_math))

      copy_stylesheet(@path)
      copy_frontmatter(@path)
      build_body(@path, yamlfile)
      copy_backmatter(@path)

      if @config['math_format'] == 'imgmath'
        @img_math.make_math_images
      end

      copy_images(@config['imagedir'], "#{@path}/#{@config['imagedir']}")

      copy_resources('covers', "#{@path}/#{@config['imagedir']}")
      copy_resources('adv', "#{@path}/#{@config['imagedir']}")
      copy_resources(@config['fontdir'], "#{@path}/fonts", @config['font_ext'])
    end

    def build_body(basetmpdir, _yamlfile)
      base_path = Pathname.new(@basedir)
      @compile_errors = nil
      @book.parts.each do |part|
        if part.name.present?
          if part.file?
            build_chap(part, base_path, basetmpdir, true)
          else
            htmlfile = "part_#{part.number}.#{@config['htmlext']}"
            build_part(part, basetmpdir, htmlfile)
            # title = ReVIEW::I18n.t('part', part.number)
            # title += ReVIEW::I18n.t('chapter_postfix') + part.name.strip unless part.name.strip.empty?
          end
        end

        part.chapters.each { |chap| build_chap(chap, base_path, basetmpdir, false) }
      end
      if @compile_errors
        app_error 'compile error, No web files output.'
      end
    end

    def build_part(part, basetmpdir, htmlfile)
      @title = h("#{ReVIEW::I18n.t('part', part.number)} #{part.name.strip}")
      File.open("#{basetmpdir}/#{htmlfile}", 'w') do |f|
        @part_number = part.number
        @part_title = part.name.strip
        @body = ReVIEW::Template.generate(path: template_name(localfile: '_part_body.html.erb', systemfile: 'html/_part_body.html.erb'), binding: binding)
        @language = @config['language']
        @stylesheets = @config['stylesheet']
        f.write ReVIEW::Template.generate(path: template_name, binding: binding)
      end
    end

    def template_name(localfile: 'layout-web.html.erb', systemfile: nil)
      if @basedir
        layoutfile = File.join(@basedir, 'layouts', localfile)
        if File.exist?(layoutfile)
          return layoutfile
        end
      end

      if systemfile
        return systemfile
      end

      if @config['htmlversion'].to_i == 5
        'web/html/layout-html5.html.erb'
      else
        'web/html/layout-xhtml1.html.erb'
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

      htmlfile = "#{id}.#{@config['htmlext']}"

      if @config['params'].present?
        warn %Q('params:' in config.yml is obsoleted.)
      end

      begin
        @converter.convert(filename, File.join(basetmpdir, htmlfile))
      rescue ApplicationError => e
        @compile_errors = true
        error "compile error in #{filename} (#{e.class})"
        error e.message
      end
    end

    def copy_images(resdir, destdir)
      return nil unless File.exist?(resdir)

      allow_exts = @config['image_ext']
      FileUtils.mkdir_p(destdir)
      recursive_copy_files(resdir, destdir, allow_exts)
    end

    def copy_resources(resdir, destdir, allow_exts = nil)
      return nil if !resdir || !File.exist?(resdir)

      allow_exts ||= @config['image_ext']
      FileUtils.mkdir_p(destdir)
      recursive_copy_files(resdir, destdir, allow_exts)
    end

    def recursive_copy_files(resdir, destdir, allow_exts)
      Dir.open(resdir) do |dir|
        dir.each do |fname|
          next if fname.start_with?('.')

          if FileTest.directory?("#{resdir}/#{fname}")
            recursive_copy_files("#{resdir}/#{fname}", "#{destdir}/#{fname}", allow_exts)
          elsif /\.(#{allow_exts.join('|')})\Z/i.match?(fname)
            FileUtils.mkdir_p(destdir)
            FileUtils.cp("#{resdir}/#{fname}", destdir)
          end
        end
      end
    end

    def copy_stylesheet(basetmpdir)
      if @config['stylesheet'].size > 0
        @config['stylesheet'].each do |sfile|
          FileUtils.cp(sfile, basetmpdir)
        end
      end
    end

    def copy_frontmatter(basetmpdir)
      build_indexpage(basetmpdir)

      if @config['titlepage']
        if @config['titlefile']
          FileUtils.cp(@config['titlefile'], "#{basetmpdir}/titlepage.#{@config['htmlext']}")
        else
          build_titlepage(basetmpdir, "titlepage.#{@config['htmlext']}")
        end
      end

      copy_file_with_param('creditfile')
      copy_file_with_param('originaltitlefile')
    end

    def build_indexpage(basetmpdir)
      @title = h('index')
      File.open("#{basetmpdir}/index.html", 'w') do |f|
        if @config['coverimage']
          file = File.join(@config['imagedir'], @config['coverimage'])
          @body = <<-EOT
  <div id="cover-image" class="cover-image">
    <img src="#{file}" class="max"/>
  </div>
        EOT
        else
          @body = ''
        end
        @language = @config['language']
        @stylesheets = @config['stylesheet']
        @toc = ReVIEW::WEBTOCPrinter.book_to_string(@book)
        @next = @book.chapters[0]
        @next_title = @next ? @next.title : ''
        f.write ReVIEW::Template.generate(path: template_name, binding: binding)
      end
    end

    def build_titlepage(basetmpdir, htmlfile)
      @title = h('titlepage')
      File.open(File.join(basetmpdir, htmlfile), 'w') do |f|
        @body = ReVIEW::Template.generate(path: template_name(localfile: '_titlepage.html.erb', systemfile: 'html/_titlepage.html.erb'), binding: binding)
        @language = @config['language']
        @stylesheets = @config['stylesheet']
        f.write ReVIEW::Template.generate(path: template_name, binding: binding)
      end
    end

    def copy_backmatter(_basetmpdir)
      copy_file_with_param('profile')
      copy_file_with_param('advfile')
      if @config['colophon'] && @config['colophon'].is_a?(String)
        copy_file_with_param('colophon', "colophon.#{@config['htmlext']}")
      end
      copy_file_with_param('backcover')
    end

    def copy_file_with_param(name, target_file = nil)
      return if @config[name].nil? || !File.exist?(@config[name])

      target_file ||= File.basename(@config[name])
      FileUtils.cp(@config[name], File.join(@path, target_file))
    end

    def join_with_separator(value, sep)
      if value.is_a?(Array)
        value.join(sep)
      else
        value
      end
    end
  end
end
