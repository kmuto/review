#
# Copyright (c) 2018-2019 Masanori Kado, Masayoshi Takahashi, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".

require 'fileutils'
require 'optparse'
require 'net/http'
require 'tempfile'
require 'review'

module ReVIEW
  class Init
    def self.execute(*args)
      new.execute(*args)
    end

    def initialize
      @tex_documentclass_opts = {
        'review-jsbook' => 'media=print,paper=a5',
        'review-jlreq' => 'media=print,paper=a5'
      }

      @template = 'review-jsbook'
      @logger = ReVIEW.logger
      @review_dir = File.dirname(File.expand_path('..', __dir__))
    end

    def execute(*args)
      initdir = parse_options(args)

      if @webui
        start_webui
        unless @web_result
          @logger.error 'Aborted.'
          exit 1
        end
        @template = @web_result[0]
        @tex_documentclass_opts[@template] = @web_result[1]
      end

      generate_dir(initdir) do |dir|
        generate_catalog_file(dir)
        generate_sample(dir)
        generate_images_dir(dir)
        generate_cover_image(dir)
        generate_style(dir)
        generate_texmacro(dir)
        generate_config(dir)
        generate_locale(dir) if @locale
        generate_rakefile(dir)
        generate_gemfile(dir)
        generate_doc(dir) unless @without_doc
        download_and_extract_archive(dir, @archive) if @archive
      end
    end

    def parse_options(args)
      @port = 18000
      @bind = '0'

      opts = OptionParser.new
      opts.version = ReVIEW::VERSION
      opts.banner = "Usage: #{File.basename($PROGRAM_NAME)} [option] dirname"
      opts.on('-h', '--help', 'print this message and quit.') do
        puts opts.help
        exit 0
      end
      opts.on('-f', '--force', 'generate files (except *.re) if directory has already existed.') do
        @force = true
      end
      opts.on('-l', '--locale', 'generate locale.yml file.') do
        @locale = true
      end
      opts.on('-t', '--latex-template name', 'specify LaTeX template name. (default: review-jsbook)') do |tname|
        @template = tname
      end
      opts.on('', '--epub-version VERSION', 'define EPUB version.') do |version|
        @epub_version = version
      end
      opts.on('', '--without-doc', "don't generate doc files.") do
        @without_doc = true
      end
      opts.on('-p', '--package archivefile', 'extract from local or network archive.') do |archive|
        @archive = archive
      end
      opts.on('-w', '--wizard', 'launch Web based layout configuration.') do
        @webui = true
      end
      opts.on('', '--port port', 'port to use for Web based layout configuration. (default: 18000)') do |port|
        @port = port
      end
      opts.on('', '--bind bindaddress', 'address to use for Web based layout configuration. (default: 0 (any))') do |bind|
        @bind = bind
      end

      begin
        opts.parse!(args)
      rescue OptionParser::ParseError => e
        @logger.error e.message
        $stderr.puts opts.help
        exit 1
      end

      if args.empty?
        $stderr.puts opts.help
        exit 1
      end

      initdir = File.expand_path(args[0])

      initdir
    end

    def generate_dir(dir)
      if File.exist?(dir) && !@force
        @logger.error "#{dir} already exists."
        exit 1
      end
      FileUtils.mkdir_p(dir)
      yield dir
    end

    def generate_sample(dir)
      unless @force
        File.write(File.join(dir, "#{File.basename(dir)}.re"), '= ')
      end
    end

    def generate_catalog_file(dir)
      File.open(File.join(dir, 'catalog.yml'), 'w') do |file|
        file.write <<-EOS
PREDEF:

CHAPS:
  - #{File.basename(dir)}.re

APPENDIX:

POSTDEF:

EOS
      end
    end

    def generate_images_dir(dir)
      FileUtils.mkdir_p(File.join(dir, 'images'))
    end

    def generate_cover_image(dir)
      FileUtils.cp(File.join(@review_dir, 'samples/sample-book/src/images/cover.jpg'),
                   File.join(dir, 'images'))
      FileUtils.cp(File.join(@review_dir, 'samples/sample-book/src/images/cover-a5.ai'),
                   File.join(dir, 'images'))
    end

    def generate_config(dir)
      today = Time.now.strftime('%Y-%m-%d')
      content = File.read(File.join(@review_dir, 'doc/config.yml.sample'), encoding: 'utf-8')
      content.gsub!(/^#\s*coverimage:.*$/, 'coverimage: cover.jpg')
      content.gsub!(/^  #\s*coverimage:.*$/, '  coverimage: cover-a5.ai')
      content.gsub!(/^#\s*date:.*$/, "date: #{today}")
      content.gsub!(/^#\s*history:.*$/, %Q(history: [["#{today}"]]))
      content.gsub!(/^#\s*texstyle:.*$/, 'texstyle: ["reviewmacro"]')
      content.gsub!(/^(#\s*)?stylesheet:.*$/, %Q(stylesheet: ["style.css"]))
      if @epub_version.to_i == 2
        content.gsub!(/^#.*epubversion:.*$/, 'epubversion: 2')
        content.gsub!(/^#.*htmlversion:.*$/, 'htmlversion: 4')
      end

      if @tex_documentclass_opts[@template]
        content.gsub!(/^#\s*texdocumentclass:.*$/, %Q(texdocumentclass: ["#{@template}", "#{@tex_documentclass_opts[@template]}"]))
      end

      File.open(File.join(dir, 'config.yml'), 'w') { |f| f.write content }
      if @webui && !@web_result[2].empty?
        File.open(File.join(dir, 'config-ebook.yml'), 'w') do |f|
          f.puts <<EOT
# for ebook PDF
# REVIEW_CONFIG_FILE=config.yml rake pdf
inherit: ["config.yml"]
# bookname: book-ebook
texdocumentclass: ["#{@web_result[0]}", "#{@web_result[2]}"]
EOT
        end
      end
    end

    def generate_style(dir)
      FileUtils.cp(File.join(@review_dir, 'samples/sample-book/src/style.css'), dir)
    end

    def generate_texmacro(dir)
      texmacrodir = File.join(dir, 'sty')
      FileUtils.mkdir_p(texmacrodir)
      tdir = File.join(@review_dir, 'templates/latex', @template)
      @logger.error "#{tdir} not found." unless File.exist?(tdir)
      FileUtils.cp(Dir.glob(File.join(tdir, '*.*')), texmacrodir)

      if @template == 'review-jsbook'
        # provide jsbook from vendor/. current version is 2018/06/23
        FileUtils.cp(File.join(@review_dir, 'vendor/jsclasses/jsbook.cls'), File.join(texmacrodir, 'jsbook.cls'))
        # provide gentombow from vendor/. current version is 2018/08/30 v0.9j
        FileUtils.cp(File.join(@review_dir, 'vendor/gentombow/gentombow.sty'), File.join(texmacrodir, 'gentombow.sty'))
      end
    end

    def generate_rakefile(dir)
      FileUtils.mkdir_p(File.join(dir, 'lib/tasks'))

      File.open(File.join(dir, 'Rakefile'), 'w') do |file|
        file.write <<-EOS
Dir.glob('lib/tasks/*.rake').sort.each do |file|
  load(file)
end
EOS
      end

      FileUtils.cp(File.join(@review_dir, 'samples/sample-book/src/lib/tasks/review.rake'),
                   File.join(dir, 'lib/tasks/review.rake'))
    end

    def generate_locale(dir)
      FileUtils.cp(File.join(@review_dir, 'lib/review/i18n.yml'), File.join(dir, 'locale.yml'))
    end

    def generate_gemfile(dir)
      File.open(File.join(dir, 'Gemfile'), 'w') do |file|
        file.write <<-EOS
source 'https://rubygems.org'

gem 'rake'
gem 'review', '#{ReVIEW::VERSION}'
EOS
      end
    end

    def generate_doc(dir)
      docdir = File.join(dir, 'doc')
      FileUtils.mkdir_p(docdir)
      md_files = Dir.glob(File.join(@review_dir, 'doc/*.md')).map.to_a
      FileUtils.cp(md_files, docdir)
    end

    def download_and_extract_archive(dir, filename)
      begin
        require 'zip'
      rescue LoadError
        @logger.error 'extracting needs rubyzip.'
        exit 1
      end

      if filename =~ %r{\Ahttps?://}
        begin
          @logger.info "Downloading from #{filename}"
          zipdata = Net::HTTP.get(URI.parse(filename))
        rescue StandardError => e
          @logger.error "Failed to download #{filename}: #{e.message}"
          exit 1
        end

        Tempfile.create('reviewinit') do |f|
          zipfilename = f.path
          f.write zipdata

          extract_archive(dir, zipfilename, filename)
        end
      else
        unless File.readable?(filename)
          @logger.error "Failed to open #{filename}"
          exit 1
        end
        extract_archive(dir, filename, filename)
      end
    end

    def extract_archive(dir, filename, originalfilename)
      made = nil
      begin
        Zip::File.open(filename) do |zip|
          zip.each do |entry|
            fname = entry.name.gsub('\\', '/')
            if fname =~ /__MACOSX/ || fname =~ /\.DS_Store/
              next
            end

            if fname =~ %r{\A/} || fname =~ /\.\./ # simple fool proof
              made = nil
              break
            end

            # `true' means override
            entry.extract(File.join(dir, fname)) { true }
          end
          made = true
        end
        raise Zip::Error unless made
      rescue Zip::Error => e
        @logger.error "#{originalfilename} seems invalid or broken zip file: #{e.message}"
      end
    end

    def start_webui
      require 'webrick'
      web_config = {
        BindAddress: @bind,
        Port: @port,
        HTTPVersion: WEBrick::HTTPVersion.new('1.1'),
        AccessLog: [[File.open(IO::NULL, 'w'), '']]
      }

      bind_address = (@bind == '0') ? '<thishost>' : @bind
      puts "Please access http://#{bind_address}:#{web_config[:Port]} from Web browser."
      begin
        @web_server = WEBrick::HTTPServer.new(web_config)
      rescue StandardError => e
        @logger.error "Error: #{e}"
        exit 1
      end

      @web_result = nil
      web_mounts

      trap(:INT) { @web_server.shutdown }
      @web_server.start

      # validation
      if @web_result
        @web_result.each do |s|
          if s !~ /\A[a-z0-9=_,\.-]*\Z/i
            @web_result = nil
            return
          end
        end
      end
    end

    def web_mounts
      htmldir = File.join(@review_dir, 'lib', 'review', 'init-web')
      @web_server.mount('/', WEBrick::HTTPServlet::FileHandler, File.join(htmldir, 'index.html'))
      @web_server.mount('/review-layout-design.js', WEBrick::HTTPServlet::FileHandler, File.join(htmldir, 'review-layout-design.js'))

      @web_server.mount_proc('/finish') do |req, res|
        @web_result = [req.query['cls'], req.query['result_print'], req.query['result_ebook']]
        res.content_type = 'text/html'
        res.body = File.read(File.join(htmldir, 'finish.html'))
        @web_server.shutdown
      end
    end
  end
end
