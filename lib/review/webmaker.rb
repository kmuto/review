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
require 'review/template'
require 'review/tocprinter'
require 'review/version'
require 'erb'

module ReVIEW
  class WEBMaker
    include ERB::Util

    attr_accessor :config, :basedir

    def initialize
      @basedir = nil
      @logger = ReVIEW.logger
    end

    def self.execute(*args)
      self.new.execute(*args)
    end

    def parse_opts(args)
      cmd_config = {}
      opts = OptionParser.new

      opts.banner = 'Usage: review-webmaker configfile'
      opts.version = ReVIEW::VERSION
      opts.on('--help', 'Prints this message and quit.') do
        puts opts.help
        exit 0
      end
      opts.on('--ignore-errors', 'Ignore review-compile errors.') { cmd_config['ignore-errors'] = true }

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
      math_dir = "./#{@config['imagedir']}/_review_math"
      FileUtils.rm_rf(math_dir) if @config['imgmath'] && Dir.exist?(math_dir)
      FileUtils.rm_rf(path)
    end

    def execute(*args)
      @config = ReVIEW::Configure.values
      @config.maker = 'webmaker'
      cmd_config, yamlfile = parse_opts(args)

      @config.merge!(YAML.load_file(yamlfile))
      # YAML configs will be overridden by command line options.
      @config.merge!(cmd_config)
      @config['htmlext'] = 'html'
      I18n.setup(@config['language'])
      generate_html_files(yamlfile)
    end

    def generate_html_files(yamlfile)
      @basedir = File.dirname(yamlfile)
      @path = build_path
      remove_old_files(@path)
      Dir.mkdir(@path)

      @book = ReVIEW::Book.load(@basedir)
      @book.config = @config

      copy_stylesheet(@path)
      copy_frontmatter(@path)
      build_body(@path, yamlfile)
      copy_backmatter(@path)

      copy_images(@config['imagedir'], "#{@path}/#{@config['imagedir']}")

      copy_resources('covers', "#{@path}/#{@config['imagedir']}")
      copy_resources('adv', "#{@path}/#{@config['imagedir']}")
      copy_resources(@config['fontdir'], "#{@path}/fonts", @config['font_ext'])
    end

    def build_body(basetmpdir, _yamlfile)
      base_path = Pathname.new(@basedir)
      builder = ReVIEW::HTMLBuilder.new
      @converter = ReVIEW::Converter.new(@book, builder)
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
    end

    def build_part(part, basetmpdir, htmlfile)
      File.open("#{basetmpdir}/#{htmlfile}", 'w') do |f|
        @body = ''
        @body << %Q(<div class="part">\n)
        @body << %Q(<h1 class="part-number">#{ReVIEW::I18n.t('part', part.number)}</h1>\n)
        @body << %Q(<h2 class="part-title">#{part.name.strip}</h2>\n) if part.name.strip.present?
        @body << "</div>\n"

        @language = @config['language']
        @stylesheets = @config['stylesheet']
        tmplfile = File.expand_path(template_name, ReVIEW::Template::TEMPLATE_DIR)
        f.write ReVIEW::Template.load(tmplfile).result(binding)
      end
    end

    def template_name
      if @config['htmlversion'].to_i == 5
        'web/html/layout-html5.html.erb'
      else
        'web/html/layout-xhtml1.html.erb'
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

      htmlfile = "#{id}.#{@config['htmlext']}"

      if @config['params'].present?
        @logger.warn %Q('params:' in config.yml is obsoleted.)
      end

      begin
        @converter.convert(filename, File.join(basetmpdir, htmlfile))
      rescue => e
        @logger.warn "compile error in #{filename} (#{e.class})"
        @logger.warn e.message
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
      allow_exts = @config['image_ext'] if allow_exts.nil?
      FileUtils.mkdir_p(destdir)
      recursive_copy_files(resdir, destdir, allow_exts)
    end

    def recursive_copy_files(resdir, destdir, allow_exts)
      Dir.open(resdir) do |dir|
        dir.each do |fname|
          next if fname.start_with?('.')
          if FileTest.directory?("#{resdir}/#{fname}")
            recursive_copy_files("#{resdir}/#{fname}", "#{destdir}/#{fname}", allow_exts)
          elsif fname =~ /\.(#{allow_exts.join('|')})\Z/i
            FileUtils.mkdir_p(destdir)
            FileUtils.cp("#{resdir}/#{fname}", destdir)
          end
        end
      end
    end

    def copy_stylesheet(basetmpdir)
      @config['stylesheet'].each { |sfile| FileUtils.cp(sfile, basetmpdir) } if @config['stylesheet'].size > 0
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
        tmplfile = File.expand_path(template_name, ReVIEW::Template::TEMPLATE_DIR)
        f.write ReVIEW::Template.load(tmplfile).result(binding)
      end
    end

    def build_titlepage(basetmpdir, htmlfile)
      File.open("#{basetmpdir}/#{htmlfile}", 'w') do |f|
        @body = ''
        @body << %Q(<div class="titlepage">)
        @body << %Q(<h1 class="tp-title">#{CGI.escapeHTML(@config.name_of('booktitle'))}</h1>)
        @body << %Q(<h2 class="tp-author">#{join_with_separator(@config.names_of('aut'), ReVIEW::I18n.t('names_splitter'))}</h2>) if @config['aut']
        @body << %Q(<h3 class="tp-publisher">#{join_with_separator(@config.names_of('prt'), ReVIEW::I18n.t('names_splitter'))}</h3>) if @config['prt']
        @body << '</div>'

        @language = @config['language']
        @stylesheets = @config['stylesheet']
        tmplfile = File.expand_path(template_name, ReVIEW::Template::TEMPLATE_DIR)
        f.write ReVIEW::Template.load(tmplfile).result(binding)
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
      FileUtils.cp(@config[name], File.join(basetmpdir, target_file))
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
