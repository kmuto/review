# frozen_string_literal: true

# Copyright (c) 2010-2024 Kenshi Muto and Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
#

require 'tmpdir'

require 'review/i18n'
require 'review/book'
require 'review/configure'
require 'review/converter'
require 'review/latexbuilder'
require 'review/version'
require 'review/htmltoc'
require 'review/htmlbuilder'
require 'review/img_math'
require 'review/img_graph'

require 'rexml/document'
require 'rexml/streamlistener'
require 'review/call_hook'
require 'review/epubmaker/producer'
require 'review/epubmaker/content'
require 'review/epubmaker/epubv2'
require 'review/epubmaker/epubv3'
require 'review/epubmaker/reviewheaderlistener'
require 'review/makerhelper'
require 'review/loggable'

module ReVIEW
  class EPUBMaker
    include MakerHelper
    include Loggable
    include ReVIEW::CallHook

    def initialize
      @producer = nil
      @htmltoc = nil
      @buildlogtxt = 'build-log.txt'
      @logger = ReVIEW.logger
      @img_math = nil
      @img_graph = nil
      @basedir = nil
    end

    def self.execute(*args)
      self.new.execute(*args)
    end

    def parse_opts(args)
      cmd_config = {}
      opts = OptionParser.new
      @buildonly = nil

      opts.banner = 'Usage: review-epubmaker [options] configfile [export_filename]'
      opts.version = ReVIEW::VERSION
      opts.on('--help', 'Prints this message and quit.') do
        puts opts.help
        exit 0
      end
      opts.on('--[no-]debug', 'Keep temporary files.') { |debug| cmd_config['debug'] = debug }
      opts.on('-y', '--only file1,file2,...', 'Build only specified files.') { |v| @buildonly = v.split(/\s*,\s*/).map { |m| m.strip.sub(/\.re\Z/, '') } }

      opts.parse!(args)
      if args.size < 1 || args.size > 2
        puts opts.help
        exit 0
      end

      [cmd_config, args[0], args[1]]
    end

    def execute(*args)
      cmd_config, yamlfile, exportfile = parse_opts(args)
      error! "#{yamlfile} not found." unless File.exist?(yamlfile)

      begin
        @config = ReVIEW::Configure.create(maker: 'epubmaker',
                                           yamlfile: yamlfile,
                                           config: cmd_config)
      rescue ReVIEW::ConfigError => e
        error! e.message
      end
      @producer = ReVIEW::EPUBMaker::Producer.new(@config)
      update_log_level
      debug("Loaded yaml file (#{yamlfile}).")
      @basedir = File.absolute_path(File.dirname(yamlfile))

      produce(yamlfile, exportfile)
    end

    def update_log_level
      if @config['debug']
        if @logger.ttylogger?
          ReVIEW.logger = nil
          @logger = ReVIEW.logger(level: 'debug')
        else
          @logger.level = Logger::DEBUG
        end
      elsif !@logger.ttylogger?
        @logger.level = Logger::INFO
      end
    end

    def build_path
      if @config['debug']
        path = File.expand_path("#{@config['bookname']}-epub", Dir.pwd)
        FileUtils.rm_rf(path, secure: true)
        Dir.mkdir(path)
        path
      else
        Dir.mktmpdir("#{@config['bookname']}-epub-")
      end
    end

    def produce(yamlfile, bookname = nil)
      I18n.setup(@config['language'])
      bookname ||= @config['bookname']
      booktmpname = "#{bookname}-epub"

      @img_math = ReVIEW::ImgMath.new(@config)
      begin
        @config.check_version(ReVIEW::VERSION, exception: true)
      rescue ReVIEW::ConfigError => e
        warn e.message
      end
      debug("#{bookname}.epub will be created.")

      FileUtils.rm_f("#{bookname}.epub")
      if @config['debug']
        FileUtils.rm_rf(booktmpname)
      end

      @img_math.cleanup_mathimg

      basetmpdir = build_path
      begin
        debug("Created first temporary directory as #{basetmpdir}.")

        call_hook('hook_beforeprocess', basetmpdir, base_dir: @basedir)

        @htmltoc = ReVIEW::HTMLToc.new(basetmpdir)
        ## copy all files into basetmpdir
        copy_stylesheet(basetmpdir)

        copy_frontmatter(basetmpdir)
        call_hook('hook_afterfrontmatter', basetmpdir, base_dir: @basedir)

        build_body(basetmpdir, yamlfile)
        call_hook('hook_afterbody', basetmpdir, base_dir: @basedir)

        copy_backmatter(basetmpdir)

        if @config['math_format'] == 'imgmath'
          @img_math.make_math_images
        end
        call_hook('hook_afterbackmatter', basetmpdir, base_dir: @basedir)

        ## push contents in basetmpdir into @producer
        push_contents(basetmpdir)

        if @config['epubmaker']['verify_target_images'].present?
          verify_target_images(basetmpdir)
          copy_images(@config['imagedir'], basetmpdir)
        else
          copy_images(@config['imagedir'], File.join(basetmpdir, @config['imagedir']))
        end

        copy_resources('covers', File.join(basetmpdir, @config['imagedir']))
        copy_resources('adv', File.join(basetmpdir, @config['imagedir']))
        copy_resources(@config['fontdir'], File.join(basetmpdir, 'fonts'), @config['font_ext'])

        call_hook('hook_aftercopyimage', basetmpdir, base_dir: @basedir)

        @producer.import_imageinfo(File.join(basetmpdir, @config['imagedir']), basetmpdir)
        @producer.import_imageinfo(File.join(basetmpdir, 'fonts'), basetmpdir, @config['font_ext'])

        check_image_size(basetmpdir, @config['image_maxpixels'], @config['image_ext'])

        epubtmpdir = nil
        if @config['debug'].present?
          epubtmpdir = File.join(basetmpdir, booktmpname)
          Dir.mkdir(epubtmpdir)
        end
        debug('Call ePUB producer.')
        @producer.produce("#{bookname}.epub", basetmpdir, epubtmpdir, base_dir: @basedir)
        debug('Finished.')
        @logger.success("built #{bookname}.epub")
      rescue ApplicationError => e
        raise if @config['debug']

        error! e.message
      ensure
        FileUtils.remove_entry_secure(basetmpdir) unless @config['debug']
      end
    end

    def verify_target_images(basetmpdir)
      @producer.contents.each do |content|
        case content.media
        when 'application/xhtml+xml'
          unless File.exist?(File.join(basetmpdir, content.file))
            next
          end

          File.open(File.join(basetmpdir, content.file)) do |f|
            REXML::Document.new(File.new(f)).each_element('//img') do |e|
              @config['epubmaker']['force_include_images'].push(e.attributes['src'])
              if e.attributes['src'] =~ /svg\Z/i
                content.properties.push('svg')
              end
            end
          end
        when 'text/css'
          unless File.exist?(File.join(basetmpdir, content.file))
            next
          end

          File.open(File.join(basetmpdir, content.file)) do |f|
            f.each_line do |l|
              l.scan(/url\((.+?)\)/) do |_m|
                @config['epubmaker']['force_include_images'].push($1.strip.gsub(/\A(['"])(.*)\1\Z/, '\2'))
              end
            end
          end
        end
      end

      if @config['coverimage']
        @config['epubmaker']['force_include_images'].push(File.join(@config['imagedir'], @config['coverimage']))
      end

      @config['epubmaker']['force_include_images'] = @config['epubmaker']['force_include_images'].compact.sort.uniq
    end

    def copy_images(resdir, destdir, allow_exts = nil)
      return nil unless File.exist?(resdir)

      allow_exts ||= @config['image_ext']
      FileUtils.mkdir_p(destdir)
      if @config['epubmaker']['verify_target_images'].present?
        @config['epubmaker']['force_include_images'].each do |file|
          unless File.exist?(file)
            unless /\Ahttps?:/.match?(file)
              warn "#{file} is not found, skip."
            end
            next
          end
          basedir = File.dirname(file)
          FileUtils.mkdir_p(File.join(destdir, basedir))
          debug("Copy #{file} to the temporary directory.")
          FileUtils.cp(file, File.join(destdir, basedir), preserve: true)
        end
      else
        recursive_copy_files(resdir, destdir, allow_exts)
      end
    end

    def copy_resources(resdir, destdir, allow_exts = nil)
      return nil unless File.exist?(resdir)

      allow_exts ||= @config['image_ext']
      FileUtils.mkdir_p(destdir)
      recursive_copy_files(resdir, destdir, allow_exts)
    end

    def recursive_copy_files(resdir, destdir, allow_exts)
      Dir.open(resdir) do |dir|
        dir.each do |fname|
          next if fname.start_with?('.')

          if FileTest.directory?(File.join(resdir, fname))
            recursive_copy_files(File.join(resdir, fname), File.join(destdir, fname), allow_exts)
          elsif /\.(#{allow_exts.join('|')})\Z/i.match?(fname)
            FileUtils.mkdir_p(destdir)
            debug("Copy #{resdir}/#{fname} to the temporary directory.")
            FileUtils.cp(File.join(resdir, fname), destdir, preserve: true)
          end
        end
      end
    end

    def check_compile_status
      return unless @compile_errors

      error! 'compile error, No EPUB file output.'
    end

    def build_body(basetmpdir, yamlfile)
      @precount = 0
      @bodycount = 0
      @postcount = 0

      @manifeststr = ''
      @ncxstr = ''
      @tocdesc = []
      @img_graph = ReVIEW::ImgGraph.new(@config, 'html', path_name: '_review_graph')

      basedir = File.dirname(yamlfile)
      base_path = Pathname.new(basedir)
      book = ReVIEW::Book::Base.new(basedir, config: @config)
      @converter = ReVIEW::Converter.new(book, ReVIEW::HTMLBuilder.new(img_math: @img_math, img_graph: @img_graph))
      @compile_errors = nil

      book.parts.each do |part|
        if part.name.present?
          if part.file?
            build_chap(part, base_path, basetmpdir, true)
          else
            htmlfile = "part_#{part.number}.#{@config['htmlext']}"
            build_part(part, basetmpdir, htmlfile)
            title = ReVIEW::I18n.t('part', part.number)
            if part.name.strip.present?
              title += ReVIEW::I18n.t('chapter_postfix') + part.name.strip
            end
            @htmltoc.add_item(0, htmlfile, title, chaptype: 'part')
            write_buildlogtxt(basetmpdir, htmlfile, '')
          end
        end

        part.chapters.each do |chap|
          build_chap(chap, base_path, basetmpdir, false)
        end
      end
      check_compile_status

      begin
        @img_graph.make_mermaid_images
      rescue ApplicationError => e
        error! e.message
      end
      @img_graph.cleanup_graphimg
    end

    def build_part(part, basetmpdir, htmlfile)
      debug("Create #{htmlfile} from a template.")
      File.open(File.join(basetmpdir, htmlfile), 'w') do |f|
        @part_number = part.number
        @part_title = part.name.strip
        @title = @part_title
        @body = ReVIEW::Template.generate(path: template_name(localfile: '_part_body.html.erb', systemfile: 'html/_part_body.html.erb'), binding: binding)
        @language = @producer.config['language']
        @stylesheets = @producer.config['stylesheet']
        f.write ReVIEW::Template.generate(path: template_name, binding: binding)
      end
    end

    def template_name(localfile: 'layout.html.erb', systemfile: nil)
      if @basedir
        layoutfile = File.join(@basedir, 'layouts', localfile)
        if File.exist?(layoutfile)
          return layoutfile
        end
      end

      if systemfile
        return systemfile
      end

      if @producer.config['htmlversion'].to_i == 5
        './html/layout-html5.html.erb'
      else
        './html/layout-xhtml1.html.erb'
      end
    end

    def build_chap(chap, base_path, basetmpdir, ispart)
      chaptype = 'body'
      if ispart
        chaptype = 'part'
      elsif chap.on_predef?
        chaptype = 'pre'
      elsif chap.on_appendix?
        chaptype = 'appendix'
      elsif chap.on_postdef?
        chaptype = 'post'
      end

      filename =
        if ispart.present?
          chap.path
        else
          Pathname.new(chap.path).relative_path_from(base_path).to_s
        end

      id = File.basename(filename).sub(/\.re\Z/, '')

      if @config['epubmaker']['rename_for_legacy'] && ispart.nil?
        if chap.on_predef?
          @precount += 1
          id = sprintf('pre%02d', @precount)
        elsif chap.on_appendix?
          @postcount += 1
          id = sprintf('post%02d', @postcount)
        else
          @bodycount += 1
          id = sprintf('chap%02d', @bodycount)
        end
      end

      if @buildonly && !@buildonly.include?(id)
        warn "skip #{id}.re"
        return
      end

      htmlfile = "#{id}.#{@config['htmlext']}"
      write_buildlogtxt(basetmpdir, htmlfile, filename)
      debug("Create #{htmlfile} from #{filename}.")

      if @config['params'].present?
        warn %Q('params:' in config.yml is obsoleted.)
        if /stylesheet=/.match?(@config['params'])
          warn %Q(stylesheets should be defined in 'stylesheet:', not in 'params:')
        end
      end
      begin
        @converter.convert(filename, File.join(basetmpdir, htmlfile))
        write_info_body(basetmpdir, id, htmlfile, ispart, chaptype)
        remove_hidden_title(basetmpdir, htmlfile)
      rescue StandardError => e
        @compile_errors = true
        error "compile error in #{filename} (#{e.class})"
        error e.message
      end
    end

    def remove_hidden_title(basetmpdir, htmlfile)
      File.open(File.join(basetmpdir, htmlfile), 'r+') do |f|
        body = f.read.
               gsub(%r{<h\d .*?hidden=['"]true['"].*?>.*?</h\d>\n}, '').
               gsub(%r{(<h\d .*?)\s*notoc=['"]true['"]\s*(.*?>.*?</h\d>\n)}, '\1\2')
        f.rewind
        f.print body
        f.truncate(f.tell)
      end
    end

    def detect_properties(path)
      properties = []
      File.open(path) do |f|
        doc = REXML::Document.new(f)
        if REXML::XPath.first(doc, '//m:math', 'm' => 'http://www.w3.org/1998/Math/MathML')
          properties << 'mathml'
        end
        if REXML::XPath.first(doc, '//s:svg', 's' => 'http://www.w3.org/2000/svg')
          properties << 'svg'
        end
      end
      properties
    end

    def parse_headlines(path)
      headlines = []

      File.open(path) do |htmlio|
        REXML::Document.parse_stream(htmlio, ReVIEWHeaderListener.new(headlines))
      end

      headlines
    end

    def write_info_body(basetmpdir, _id, filename, ispart = nil, chaptype = nil)
      path = File.join(basetmpdir, filename)
      headlines = parse_headlines(path)

      if headlines.empty?
        warn "#{filename} is discarded because there is no heading. Use `=[notoc]' or `=[nodisp]' to exclude headlines from the table of contents."
        return
      end

      properties = detect_properties(path)
      prop_str = if properties.present?
                   ',properties=' + properties.join(' ')
                 else
                   ''
                 end
      first = true
      headlines.each do |headline|
        if ispart.present? && headline['level'] == 1
          headline['level'] = 0
        end
        if first.nil?
          @htmltoc.add_item(headline['level'],
                            filename + '#' + headline['id'],
                            headline['title'],
                            { chaptype: chaptype,
                              notoc: headline['notoc'] })
        else
          @htmltoc.add_item(headline['level'],
                            filename,
                            headline['title'],
                            { force_include: true,
                              chaptype: chaptype + prop_str,
                              notoc: headline['notoc'] })
          first = nil
        end
      end
    end

    def push_contents(_basetmpdir)
      @htmltoc.each_item do |level, file, title, args|
        next if level.to_i > @config['toclevel'] && args[:force_include].nil?

        debug("Push #{file} to ePUB contents.")

        params = { file: file,
                   level: level.to_i,
                   title: title,
                   chaptype: args[:chaptype] }
        if args[:id].present?
          params[:id] = args[:id]
        end
        if args[:properties].present?
          params[:properties] = args[:properties].split(' ') # rubocop:disable Style/RedundantArgument
        end
        if args[:notoc].present?
          params[:notoc] = args[:notoc]
        end
        @producer.contents.push(ReVIEW::EPUBMaker::Content.new(**params))
      end
    end

    def copy_stylesheet(basetmpdir)
      return if @config['stylesheet'].empty?

      @config['stylesheet'].each do |sfile|
        unless File.exist?(sfile)
          error! "stylesheet: #{sfile} is not found."
        end
        FileUtils.cp(sfile, basetmpdir, preserve: true)
        @producer.contents.push(ReVIEW::EPUBMaker::Content.new(file: sfile))
      end
    end

    def copy_static_file(configname, destdir, destfilename: nil)
      destfilename ||= File.basename(@config[configname])
      unless File.exist?(@config[configname])
        error! "#{configname}: #{@config[configname]} is not found."
      end
      FileUtils.cp(@config[configname],
                   File.join(destdir, destfilename), preserve: true)
    end

    def copy_frontmatter(basetmpdir)
      if @config['cover'].present? && File.exist?(@config['cover'])
        copy_static_file('cover', basetmpdir)
      end

      if @config['titlepage']
        if @config['titlefile'].nil?
          build_titlepage(basetmpdir, "titlepage.#{@config['htmlext']}")
        else
          copy_static_file('titlefile', basetmpdir, destfilename: "titlepage.#{@config['htmlext']}")
        end
        @htmltoc.add_item(1,
                          "titlepage.#{@config['htmlext']}",
                          ReVIEW::I18n.t('titlepagetitle'),
                          chaptype: 'pre')
      end

      if @config['originaltitlefile'].present?
        copy_static_file('originaltitlefile', basetmpdir)
        @htmltoc.add_item(1,
                          File.basename(@config['originaltitlefile']),
                          ReVIEW::I18n.t('originaltitle'),
                          chaptype: 'pre')
      end

      if @config['creditfile'].present?
        copy_static_file('creditfile', basetmpdir)
        @htmltoc.add_item(1,
                          File.basename(@config['creditfile']),
                          ReVIEW::I18n.t('credittitle'),
                          chaptype: 'pre')
      end

      true
    end

    def build_titlepage(basetmpdir, htmlfile)
      @title = h(@config.name_of('booktitle'))
      File.open(File.join(basetmpdir, htmlfile), 'w') do |f|
        @body = ReVIEW::Template.generate(path: template_name(localfile: '_titlepage.html.erb', systemfile: 'html/_titlepage.html.erb'), binding: binding)
        @language = @producer.config['language']
        @stylesheets = @producer.config['stylesheet']

        f.write ReVIEW::Template.generate(path: template_name, binding: binding)
      end
    end

    def copy_backmatter(basetmpdir)
      if @config['profile']
        copy_static_file('profile', basetmpdir)
        @htmltoc.add_item(1,
                          File.basename(@config['profile']),
                          ReVIEW::I18n.t('profiletitle'),
                          chaptype: 'post')
      end

      if @config['advfile']
        copy_static_file('advfile', basetmpdir)
        @htmltoc.add_item(1,
                          File.basename(@config['advfile']),
                          ReVIEW::I18n.t('advtitle'),
                          chaptype: 'post')
      end

      if @config['colophon']
        if @config['colophon'].is_a?(String)
          copy_static_file('colophon', basetmpdir, destfilename: "colophon.#{@config['htmlext']}") # override pre-built colophon
        end
        @htmltoc.add_item(1,
                          "colophon.#{@config['htmlext']}",
                          ReVIEW::I18n.t('colophontitle'),
                          chaptype: 'post')
      end

      if @config['backcover']
        copy_static_file('backcover', basetmpdir)
        @htmltoc.add_item(1,
                          File.basename(@config['backcover']),
                          ReVIEW::I18n.t('backcovertitle'),
                          chaptype: 'post')
      end

      true
    end

    def write_buildlogtxt(basetmpdir, htmlfile, reviewfile)
      File.open(File.join(basetmpdir, @buildlogtxt), 'a') do |f|
        f.puts "#{htmlfile},#{reviewfile}"
      end
    end

    def check_image_size(basetmpdir, maxpixels, allow_exts = nil)
      begin
        require 'image_size'
      rescue LoadError
        return nil
      end
      require 'find'
      allow_exts ||= @config['image_ext']

      pat = '\\.(' + allow_exts.delete_if { |t| %w[ttf woff otf].member?(t.downcase) }.join('|') + ')'
      extre = Regexp.new(pat, Regexp::IGNORECASE)
      Find.find(basetmpdir) do |fname|
        next unless fname.match(extre)

        img = ImageSize.path(fname)
        next if img.width.nil? || img.width * img.height <= maxpixels

        h = Math.sqrt(img.height * maxpixels / img.width)
        w = maxpixels / h
        fname.sub!("#{basetmpdir}/", '')
        warn "#{fname}: #{img.width}x#{img.height} exceeds a limit. suggested value is #{w.to_i}x#{h.to_i}"
      end

      true
    end
  end
end
