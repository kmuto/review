# Copyright (c) 2010-2017 Kenshi Muto and Masayoshi Takahashi
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
require 'review/yamlloader'
require 'review/version'
require 'review/htmltoc'
require 'review/htmlbuilder'

require 'review/yamlloader'
require 'rexml/document'
require 'rexml/streamlistener'
require 'epubmaker'

module ReVIEW
  class EPUBMaker
    include ::EPUBMaker
    include REXML

    def initialize
      @producer = nil
      @htmltoc = nil
      @buildlogtxt = 'build-log.txt'
      @logger = ReVIEW.logger
    end

    def error(msg)
      @logger.error "#{File.basename($PROGRAM_NAME, '.*')}: #{msg}"
      exit 1
    end

    def warn(msg)
      @logger.warn "#{File.basename($PROGRAM_NAME, '.*')}: #{msg}"
    end

    def log(s)
      puts s if @config['debug'].present?
    end

    def load_yaml(yamlfile)
      loader = ReVIEW::YAMLLoader.new
      @config = ReVIEW::Configure.values.deep_merge(loader.load_file(yamlfile))
      @producer = Producer.new(@config)
      @producer.load(yamlfile)
      @config = @producer.config
      @config.maker = 'epubmaker'
    end

    def build_path
      if @config['debug']
        path = File.expand_path("#{@config['bookname']}-epub", Dir.pwd)
        FileUtils.rm_rf(path, secure: true) if File.exist?(path)
        Dir.mkdir(path)
        path
      else
        Dir.mktmpdir("#{@config['bookname']}-epub-")
      end
    end

    def produce(yamlfile, bookname = nil)
      load_yaml(yamlfile)
      I18n.setup(@config['language'])
      bookname = @config['bookname'] if bookname.nil?
      booktmpname = "#{bookname}-epub"

      begin
        @config.check_version(ReVIEW::VERSION)
      rescue ReVIEW::ConfigError => e
        warn e.message
      end
      log("Loaded yaml file (#{yamlfile}). I will produce #{bookname}.epub.")

      FileUtils.rm_f("#{bookname}.epub")
      FileUtils.rm_rf(booktmpname) if @config['debug']
      math_dir = "./#{@config['imagedir']}/_review_math"
      FileUtils.rm_rf(math_dir) if @config['imgmath'] && Dir.exist?(math_dir)

      basetmpdir = build_path
      begin
        log("Created first temporary directory as #{basetmpdir}.")

        call_hook('hook_beforeprocess', basetmpdir)

        @htmltoc = ReVIEW::HTMLToc.new(basetmpdir)
        ## copy all files into basetmpdir
        copy_stylesheet(basetmpdir)

        copy_frontmatter(basetmpdir)
        call_hook('hook_afterfrontmatter', basetmpdir)

        build_body(basetmpdir, yamlfile)
        call_hook('hook_afterbody', basetmpdir)

        copy_backmatter(basetmpdir)
        call_hook('hook_afterbackmatter', basetmpdir)

        ## push contents in basetmpdir into @producer
        push_contents(basetmpdir)

        if @config['epubmaker']['verify_target_images'].present?
          verify_target_images(basetmpdir)
          copy_images(@config['imagedir'], basetmpdir)
        else
          copy_images(@config['imagedir'], "#{basetmpdir}/#{@config['imagedir']}")
        end

        copy_resources('covers', "#{basetmpdir}/#{@config['imagedir']}")
        copy_resources('adv', "#{basetmpdir}/#{@config['imagedir']}")
        copy_resources(@config['fontdir'], "#{basetmpdir}/fonts", @config['font_ext'])

        call_hook('hook_aftercopyimage', basetmpdir)

        @producer.import_imageinfo("#{basetmpdir}/#{@config['imagedir']}", basetmpdir)
        @producer.import_imageinfo("#{basetmpdir}/fonts", basetmpdir, @config['font_ext'])

        check_image_size(basetmpdir, @config['image_maxpixels'], @config['image_ext'])

        epubtmpdir = nil
        if @config['debug'].present?
          epubtmpdir = "#{basetmpdir}/#{booktmpname}"
          Dir.mkdir(epubtmpdir)
        end
        log('Call ePUB producer.')
        @producer.produce("#{bookname}.epub", basetmpdir, epubtmpdir)
        log('Finished.')
      ensure
        FileUtils.remove_entry_secure basetmpdir unless @config['debug']
      end
    end

    def call_hook(hook_name, *params)
      filename = @config['epubmaker'][hook_name]
      log("Call #{hook_name}. (#{filename})")
      if filename.present? && File.exist?(filename) && FileTest.executable?(filename)
        if ENV['REVIEW_SAFE_MODE'].to_i & 1 > 0
          warn 'hook is prohibited in safe mode. ignored.'
        else
          system(filename, *params)
        end
      end
    end

    def verify_target_images(basetmpdir)
      @producer.contents.each do |content|
        if content.media == 'application/xhtml+xml'
          File.open("#{basetmpdir}/#{content.file}") do |f|
            Document.new(File.new(f)).each_element('//img') do |e|
              @config['epubmaker']['force_include_images'].push(e.attributes['src'])
              content.properties.push('svg') if e.attributes['src'] =~ /svg\Z/i
            end
          end
        elsif content.media == 'text/css'
          File.open("#{basetmpdir}/#{content.file}") do |f|
            f.each_line do |l|
              l.scan(/url\((.+?)\)/) { |_m| @config['epubmaker']['force_include_images'].push($1.strip) }
            end
          end
        end
      end
      @config['epubmaker']['force_include_images'] = @config['epubmaker']['force_include_images'].compact.sort.uniq
    end

    def copy_images(resdir, destdir, allow_exts = nil)
      return nil unless File.exist?(resdir)
      allow_exts = @config['image_ext'] if allow_exts.nil?
      FileUtils.mkdir_p(destdir)
      if @config['epubmaker']['verify_target_images'].present?
        @config['epubmaker']['force_include_images'].each do |file|
          unless File.exist?(file)
            warn "#{file} is not found, skip." if file !~ /\Ahttp[s]?:/
            next
          end
          basedir = File.dirname(file)
          FileUtils.mkdir_p("#{destdir}/#{basedir}")
          log("Copy #{file} to the temporary directory.")
          FileUtils.cp(file, "#{destdir}/#{basedir}")
        end
      else
        recursive_copy_files(resdir, destdir, allow_exts)
      end
    end

    def copy_resources(resdir, destdir, allow_exts = nil)
      return nil unless File.exist?(resdir)
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
            log("Copy #{resdir}/#{fname} to the temporary directory.")
            FileUtils.cp("#{resdir}/#{fname}", destdir)
          end
        end
      end
    end

    def check_compile_status
      return unless @compile_errors

      $stderr.puts 'compile error, No EPUB file output.'
      exit 1
    end

    def build_body(basetmpdir, yamlfile)
      @precount = 0
      @bodycount = 0
      @postcount = 0

      @manifeststr = ''
      @ncxstr = ''
      @tocdesc = []

      basedir = File.dirname(yamlfile)
      base_path = Pathname.new(basedir)
      book = ReVIEW::Book.load(basedir)
      book.config = @config
      @converter = ReVIEW::Converter.new(book, ReVIEW::HTMLBuilder.new)
      @compile_errors = nil
      book.parts.each do |part|
        if part.name.present?
          if part.file?
            build_chap(part, base_path, basetmpdir, true)
          else
            htmlfile = "part_#{part.number}.#{@config['htmlext']}"
            build_part(part, basetmpdir, htmlfile)
            title = ReVIEW::I18n.t('part', part.number)
            title += ReVIEW::I18n.t('chapter_postfix') + part.name.strip if part.name.strip.present?
            @htmltoc.add_item(0, htmlfile, title, chaptype: 'part')
            write_buildlogtxt(basetmpdir, htmlfile, '')
          end
        end

        part.chapters.each do |chap|
          build_chap(chap, base_path, basetmpdir, false)
        end
      end
      check_compile_status
    end

    def build_part(part, basetmpdir, htmlfile)
      log("Create #{htmlfile} from a template.")
      File.open("#{basetmpdir}/#{htmlfile}", 'w') do |f|
        @body = ''
        @body << %Q(<div class="part">\n)
        @body << %Q(<h1 class="part-number">#{CGI.escapeHTML(ReVIEW::I18n.t('part', part.number))}</h1>\n)
        if part.name.strip.present?
          @body << %Q(<h2 class="part-title">#{CGI.escapeHTML(part.name.strip)}</h2>\n)
        end
        @body << %Q(</div>\n)

        @language = @producer.config['language']
        @stylesheets = @producer.config['stylesheet']
        tmplfile = File.expand_path(template_name, ReVIEW::Template::TEMPLATE_DIR)
        tmpl = ReVIEW::Template.load(tmplfile)
        f.write tmpl.result(binding)
      end
    end

    def template_name
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
        chaptype = 'post'
      end

      filename =
        if ispart.present?
          chap.path
        else
          Pathname.new(chap.path).relative_path_from(base_path).to_s
        end

      id = filename.sub(/\.re\Z/, '')

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

      htmlfile = "#{id}.#{@config['htmlext']}"
      write_buildlogtxt(basetmpdir, htmlfile, filename)
      log("Create #{htmlfile} from #{filename}.")

      if @config['params'].present?
        warn %Q('params:' in config.yml is obsoleted.)
        if @config['params'] =~ /stylesheet=/
          warn %Q(stylesheets should be defined in 'stylesheet:', not in 'params:')
        end
      end
      begin
        @converter.convert(filename, File.join(basetmpdir, htmlfile))
        write_info_body(basetmpdir, id, htmlfile, ispart, chaptype)
        remove_hidden_title(basetmpdir, htmlfile)
      rescue => e
        @compile_errors = true
        warn "compile error in #{filename} (#{e.class})"
        warn e.message
      end
    end

    def remove_hidden_title(basetmpdir, htmlfile)
      File.open("#{basetmpdir}/#{htmlfile}", 'r+') do |f|
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

    def write_info_body(basetmpdir, _id, filename, ispart = nil, chaptype = nil)
      headlines = []
      path = File.join(basetmpdir, filename)
      Document.parse_stream(File.new(path), ReVIEWHeaderListener.new(headlines))
      properties = detect_properties(path)
      prop_str = ''
      prop_str = ',properties=' + properties.join(' ') if properties.present?
      first = true
      headlines.each do |headline|
        headline['level'] = 0 if ispart.present? && headline['level'] == 1
        if first.nil?
          @htmltoc.add_item(headline['level'], filename + '#' + headline['id'], headline['title'], { chaptype: chaptype, notoc: headline['notoc'] })
        else
          @htmltoc.add_item(headline['level'], filename, headline['title'], { force_include: true, chaptype: chaptype + prop_str, notoc: headline['notoc'] })
          first = nil
        end
      end
    end

    def push_contents(_basetmpdir)
      @htmltoc.each_item do |level, file, title, args|
        next if level.to_i > @config['toclevel'] && args[:force_include].nil?
        log("Push #{file} to ePUB contents.")

        hash = { 'file' => file, 'level' => level.to_i, 'title' => title, 'chaptype' => args[:chaptype] }
        hash['id'] = args[:id] if args[:id].present?
        hash['properties'] = args[:properties].split(' ') if args[:properties].present?
        hash['notoc'] = args[:notoc] if args[:notoc].present?
        @producer.contents.push(Content.new(hash))
      end
    end

    def copy_stylesheet(basetmpdir)
      return if @config['stylesheet'].empty?
      @config['stylesheet'].each do |sfile|
        FileUtils.cp(sfile, basetmpdir)
        @producer.contents.push(Content.new('file' => sfile))
      end
    end

    def copy_frontmatter(basetmpdir)
      FileUtils.cp(@config['cover'], "#{basetmpdir}/#{File.basename(@config['cover'])}") if @config['cover'].present? && File.exist?(@config['cover'])

      if @config['titlepage']
        if @config['titlefile'].nil?
          build_titlepage(basetmpdir, "titlepage.#{@config['htmlext']}")
        else
          FileUtils.cp(@config['titlefile'], "#{basetmpdir}/titlepage.#{@config['htmlext']}")
        end
        @htmltoc.add_item(1, "titlepage.#{@config['htmlext']}", @producer.res.v('titlepagetitle'), chaptype: 'pre')
      end

      if @config['originaltitlefile'].present? && File.exist?(@config['originaltitlefile'])
        FileUtils.cp(@config['originaltitlefile'], "#{basetmpdir}/#{File.basename(@config['originaltitlefile'])}")
        @htmltoc.add_item(1, File.basename(@config['originaltitlefile']), @producer.res.v('originaltitle'), chaptype: 'pre')
      end

      if @config['creditfile'].present? && File.exist?(@config['creditfile'])
        FileUtils.cp(@config['creditfile'], "#{basetmpdir}/#{File.basename(@config['creditfile'])}")
        @htmltoc.add_item(1, File.basename(@config['creditfile']), @producer.res.v('credittitle'), chaptype: 'pre')
      end

      true
    end

    def build_titlepage(basetmpdir, htmlfile)
      # TODO: should be created via epubcommon
      @title = CGI.escapeHTML(@config.name_of('booktitle'))
      File.open("#{basetmpdir}/#{htmlfile}", 'w') do |f|
        @body = ''
        @body << %Q(<div class="titlepage">\n)
        @body << %Q(<h1 class="tp-title">#{CGI.escapeHTML(@config.name_of('booktitle'))}</h1>\n)
        @body << %Q(<h2 class="tp-subtitle">#{CGI.escapeHTML(@config.name_of('subtitle'))}</h2>\n) if @config['subtitle']
        @body << %Q(<h2 class="tp-author">#{CGI.escapeHTML(@config.names_of('aut').join(ReVIEW::I18n.t('names_splitter')))}</h2>\n) if @config['aut']
        @body << %Q(<h3 class="tp-publisher">#{CGI.escapeHTML(@config.names_of('prt').join(ReVIEW::I18n.t('names_splitter')))}</h3>\n) if @config['prt']
        @body << '</div>'

        @language = @producer.config['language']
        @stylesheets = @producer.config['stylesheet']
        tmplfile = File.expand_path(template_name, ReVIEW::Template::TEMPLATE_DIR)
        tmpl = ReVIEW::Template.load(tmplfile)
        f.write tmpl.result(binding)
      end
    end

    def copy_backmatter(basetmpdir)
      if @config['profile']
        FileUtils.cp(@config['profile'], "#{basetmpdir}/#{File.basename(@config['profile'])}")
        @htmltoc.add_item(1, File.basename(@config['profile']), @producer.res.v('profiletitle'), chaptype: 'post')
      end

      if @config['advfile']
        FileUtils.cp(@config['advfile'], "#{basetmpdir}/#{File.basename(@config['advfile'])}")
        @htmltoc.add_item(1, File.basename(@config['advfile']), @producer.res.v('advtitle'), chaptype: 'post')
      end

      if @config['colophon']
        if @config['colophon'].is_a?(String) # FIXME: should let obsolete this style?
          FileUtils.cp(@config['colophon'], "#{basetmpdir}/colophon.#{@config['htmlext']}")
        else
          File.open("#{basetmpdir}/colophon.#{@config['htmlext']}", 'w') { |f| @producer.colophon(f) }
        end
        @htmltoc.add_item(1, "colophon.#{@config['htmlext']}", @producer.res.v('colophontitle'), chaptype: 'post')
      end

      if @config['backcover']
        FileUtils.cp(@config['backcover'], "#{basetmpdir}/#{File.basename(@config['backcover'])}")
        @htmltoc.add_item(1, File.basename(@config['backcover']), @producer.res.v('backcovertitle'), chaptype: 'post')
      end

      true
    end

    def write_buildlogtxt(basetmpdir, htmlfile, reviewfile)
      File.open("#{basetmpdir}/#{@buildlogtxt}", 'a') { |f| f.puts "#{htmlfile},#{reviewfile}" }
    end

    def check_image_size(basetmpdir, maxpixels, allow_exts = nil)
      begin
        require 'image_size'
      rescue LoadError
        return nil
      end
      require 'find'
      allow_exts ||= @config['image_ext']

      extre = Regexp.new('\\.(' + allow_exts.delete_if { |t| %w[ttf woff otf].include?(t) }.join('|') + ')', Regexp::IGNORECASE)
      Find.find(basetmpdir) do |fname|
        next unless fname.match(extre)
        img = ImageSize.path(fname)
        next if img.width.nil? || img.width * img.height <= maxpixels
        h = Math.sqrt(img.height * maxpixels / img.width)
        w = maxpixels / h
        fname.sub!("#{basetmpdir}/", '')
        warn "#{fname}: #{img.width}x#{img.height} exceeds a limit. suggeted value is #{w.to_i}x#{h.to_i}"
      end

      true
    end

    class ReVIEWHeaderListener
      include REXML::StreamListener
      def initialize(headlines)
        @level = nil
        @content = ''
        @headlines = headlines
      end

      def tag_start(name, attrs)
        if name =~ /\Ah(\d+)/
          raise "#{name}, #{attrs}" if @level.present?
          @level = $1.to_i
          @id = attrs['id'] if attrs['id'].present?
          @notoc = attrs['notoc'] if attrs['notoc'].present?
        elsif !@level.nil?
          if name == 'img' && attrs['alt'].present?
            @content << attrs['alt']
          elsif name == 'a' && attrs['id'].present?
            @id = attrs['id']
          end
        end
      end

      def tag_end(name)
        if name =~ /\Ah\d+/
          @headlines.push({ 'level' => @level, 'id' => @id, 'title' => @content, 'notoc' => @notoc }) if @id.present?
          @content = ''
          @level = nil
          @id = nil
          @notoc = nil
        end

        true
      end

      def text(text)
        @content << text.gsub("\t", '　') if @level.present?
      end
    end
  end
end
