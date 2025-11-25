# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'optparse'
require 'tmpdir'
require 'fileutils'
require 'json'
require 'erb'

require 'review/i18n'
require 'review/book'
require 'review/configure'
require 'review/version'
require 'review/makerhelper'
require 'review/loggable'
require 'review/call_hook'
require 'review/template'

require 'review/ast'
require 'review/ast/book_indexer'
require 'review/renderer/html_renderer'

module ReVIEW
  module AST
    module Command
      # VivliostyleMaker - PDF generator using Vivliostyle CLI with AST Renderer
      class VivliostyleMaker
        include ERB::Util
        include MakerHelper
        include Loggable
        include ReVIEW::CallHook

        attr_accessor :config, :basedir

        def initialize
          @basedir = nil
          @logger = ReVIEW.logger
          @compile_errors = nil
          @entry_files = []
          @stylesheets = []
          @javascripts = []
        end

        def self.execute(*args)
          self.new.execute(*args)
        end

        def parse_opts(args)
          cmd_config = {}
          opts = OptionParser.new
          @buildonly = nil

          opts.banner = 'Usage: review-ast-vivliostylemaker [options] configfile'
          opts.version = ReVIEW::VERSION
          opts.on('--help', 'Prints this message and quit.') do
            puts opts.help
            exit 0
          end
          opts.on('--[no-]debug', 'Keep temporary files.') { |debug| cmd_config['debug'] = debug }
          opts.on('--ignore-errors', 'Ignore compile errors.') { cmd_config['ignore-errors'] = true }
          opts.on('-y', '--only file1,file2,...', 'Build only specified files.') do |v|
            @buildonly = v.split(/\s*,\s*/).map { |m| m.strip.sub(/\.re\Z/, '') }
          end

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
            @config = ReVIEW::Configure.create(
              maker: 'vivliostylemaker',
              yamlfile: yamlfile,
              config: cmd_config
            )
          rescue ReVIEW::ConfigError => e
            error! e.message
          end

          update_log_level
          I18n.setup(@config['language'])

          begin
            generate_pdf(yamlfile)
          rescue ApplicationError => e
            raise if @config['debug']

            error! e.message
          end
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
            path = File.expand_path("#{@config['bookname']}-vivliostyle", Dir.pwd)
            FileUtils.rm_rf(path, secure: true)
            Dir.mkdir(path)
            path
          else
            Dir.mktmpdir("#{@config['bookname']}-vivliostyle-")
          end
        end

        def generate_pdf(yamlfile)
          @basedir = File.absolute_path(File.dirname(yamlfile))
          bookname = @config['bookname']

          begin
            @config.check_version(ReVIEW::VERSION, exception: true)
          rescue ReVIEW::ConfigError => e
            warn e.message
          end

          debug("#{bookname}.pdf will be created with Vivliostyle.")

          # Remove old PDF
          FileUtils.rm_f("#{bookname}.pdf")

          @path = build_path
          begin
            debug("Created temporary directory as #{@path}.")

            call_hook('hook_beforeprocess', @path, base_dir: @basedir)

            # Initialize book and build indexes
            @book = ReVIEW::Book::Base.new(@basedir, config: @config)
            ReVIEW::AST::BookIndexer.build(@book)

            # Setup stylesheets and javascripts
            setup_stylesheet
            setup_javascripts

            # Build HTML files
            build_frontmatter
            build_body
            call_hook('hook_afterbody', @path, base_dir: @basedir)
            build_backmatter

            # Copy images
            copy_images(@config['imagedir'], File.join(@path, @config['imagedir']))
            call_hook('hook_aftercopyimage', @path, base_dir: @basedir)

            # Generate vivliostyle.config.json
            generate_vivliostyle_config

            # Run Vivliostyle CLI
            call_hook('hook_beforevivliostyle', @path, base_dir: @basedir)
            run_vivliostyle(bookname)
            call_hook('hook_aftervivliostyle', @path, base_dir: @basedir)

            # Copy output PDF
            finalize_output(bookname)

            @logger.success("built #{bookname}.pdf")
          ensure
            FileUtils.remove_entry_secure(@path) unless @config['debug']
          end
        end

        private

        def setup_stylesheet
          theme = @config['vivliostylemaker']['theme']

          if theme
            # Use npm theme (will be resolved by Vivliostyle CLI)
            debug("Using Vivliostyle theme: #{theme}")
            @stylesheets = []
          else
            # Use bundled theme-review.css
            css_src = find_template_path('vivliostyle/theme-review.css')
            if css_src && File.exist?(css_src)
              FileUtils.cp(css_src, @path)
              @stylesheets = ['theme-review.css']
              debug('Using bundled theme-review.css')
            else
              warn 'theme-review.css not found, no default stylesheet applied'
              @stylesheets = []
            end
          end

          # Copy additional CSS files
          additional_css = @config['vivliostylemaker']['css'] || []
          additional_css.each do |css_file|
            src = File.join(@basedir, css_file)
            if File.exist?(src)
              FileUtils.cp(src, @path)
              @stylesheets << File.basename(css_file)
            else
              warn "CSS file not found: #{css_file}"
            end
          end

          # Copy user stylesheets from config (exclude style.css)
          (@config['stylesheet'] || []).each do |css_file|
            basename = File.basename(css_file)
            next if basename == 'style.css' # Ignore legacy style.css

            src = File.join(@basedir, css_file)
            if File.exist?(src)
              FileUtils.cp(src, @path)
              @stylesheets << basename
            end
          end
        end

        def setup_javascripts
          # Always include MathJax for Vivliostyle (default math rendering, no LaTeX required)
          @javascripts.push(%Q(<script>MathJax = { tex: { inlineMath: [['\\\\(', '\\\\)']] }, svg: { fontCache: 'global' } };</script>))
          @javascripts.push(%Q(<script type="text/javascript" id="MathJax-script" async="true" src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js"></script>))
        end

        def find_template_path(relative_path)
          # Check user's layouts directory first
          if @basedir
            user_path = File.join(@basedir, 'layouts', relative_path)
            return user_path if File.exist?(user_path)
          end

          # Check system templates
          system_path = File.join(ReVIEW::Template::TEMPLATE_DIR, relative_path)
          return system_path if File.exist?(system_path)

          nil
        end

        def build_frontmatter
          # Cover page
          if @config['coverfile'] || @config['coverimage']
            build_cover
          end

          # Title page
          if @config['titlepage']
            build_titlepage
          end

          # Table of contents
          if @config['toc']
            build_toc
          end
        end

        def build_cover
          coverfile = @config['coverfile']
          coverimage = @config['coverimage']

          if coverfile
            build_cover_from_file(coverfile)
          elsif coverimage
            build_cover_from_image(coverimage)
          end
        end

        def build_cover_from_file(coverfile)
          src_path = File.join(@basedir, coverfile)

          unless File.exist?(src_path)
            warn "Cover file not found: #{coverfile}"
            return
          end

          ext = File.extname(coverfile).downcase

          if %w[.png .jpg .jpeg .gif .svg].include?(ext)
            # Image cover - create HTML wrapper
            build_image_cover(src_path, File.basename(coverfile))
          elsif %w[.html .htm .xhtml].include?(ext)
            # HTML cover - copy directly
            build_html_cover(src_path, coverfile)
          elsif %w[.re .md].include?(ext)
            # Re:VIEW/Markdown cover - compile
            build_review_cover(coverfile)
          else
            warn "Unsupported cover file format: #{ext}"
          end
        end

        def build_cover_from_image(coverimage)
          # coverimage is relative to imagedir
          src_path = File.join(@basedir, @config['imagedir'], coverimage)

          unless File.exist?(src_path)
            warn "Cover image not found: #{coverimage}"
            return
          end

          build_image_cover(src_path, coverimage)
        end

        def build_image_cover(src_path, filename)
          # Copy cover image to build directory
          dest_filename = "cover#{File.extname(filename)}"
          FileUtils.cp(src_path, File.join(@path, dest_filename))

          # Generate cover HTML
          @title = @config.name_of('booktitle')
          @body = <<~HTML
            <div class="cover">
              <img src="#{h(dest_filename)}" alt="#{h(@title)}" class="cover-image" />
            </div>
          HTML
          html = wrap_with_layout(@body, @title)
          write_html_file('cover.html', html)
          @entry_files << 'cover.html'
          debug("Generated cover page from image: #{filename}")
        end

        def build_html_cover(src_path, coverfile)
          # Copy HTML cover file
          dest_filename = 'cover.html'
          content = File.read(src_path)

          # If it's a fragment (no DOCTYPE), wrap with layout
          if content.include?('<!DOCTYPE') || content.include?('<html')
            # Full HTML document - copy as-is but ensure stylesheets are linked
            write_html_file(dest_filename, content)
          else
            # HTML fragment - wrap with layout
            @title = @config.name_of('booktitle')
            @body = content
            html = wrap_with_layout(@body, @title)
            write_html_file(dest_filename, html)
          end

          @entry_files << dest_filename
          debug("Copied cover page: #{coverfile}")
        end

        def build_review_cover(coverfile)
          # Find the cover chapter
          cover_path = File.join(@basedir, coverfile)

          begin
            # Create a temporary chapter for the cover
            cover_chapter = ReVIEW::Book::Chapter.new(
              @book, nil, '-', cover_path, nil
            )

            # Compile to AST
            compiler = ReVIEW::AST::Compiler.for_chapter(cover_chapter)
            ast_root = compiler.compile_to_ast(cover_chapter)

            # Render to HTML
            renderer = ReVIEW::Renderer::HtmlRenderer.new(cover_chapter)
            html_body = renderer.visit(ast_root)

            # Wrap with layout
            @title = @config.name_of('booktitle')
            @body = %(<div class="cover">#{html_body}</div>)
            html = wrap_with_layout(@body, @title)

            write_html_file('cover.html', html)
            @entry_files << 'cover.html'
            debug("Compiled cover page: #{coverfile}")
          rescue StandardError => e
            warn "Failed to compile cover file: #{e.message}"
          end
        end

        def build_titlepage
          @title = @config.name_of('booktitle')
          @body = generate_titlepage_body
          html = wrap_with_layout(@body, @title)
          write_html_file('titlepage.html', html)
          @entry_files << 'titlepage.html'
        end

        def generate_titlepage_body
          template_path = find_template_path('vivliostyle/_titlepage.html.erb')
          if template_path && File.exist?(template_path)
            ReVIEW::Template.generate(path: template_path, binding: binding)
          else
            # Fallback simple titlepage
            author_names = join_with_separator(@config.names_of('aut'), I18n.t('names_splitter'))
            <<~HTML
              <div class="titlepage">
                <h1 class="booktitle">#{h(@config.name_of('booktitle'))}</h1>
                <p class="author">#{h(author_names)}</p>
              </div>
            HTML
          end
        end

        def build_toc
          @title = I18n.t('toctitle')
          @body = generate_toc_body
          html = wrap_with_layout(@body, @title)
          write_html_file('toc.html', html)
          @entry_files << 'toc.html'
        end

        def generate_toc_body
          toc_items = []
          @book.parts.each do |part|
            if part.name.present? && !part.file?
              toc_items << %Q(<li class="part">#{h(part.name)}</li>)
            end
            part.chapters.each do |chap|
              toc_items << %Q(<li><a href="#{chap.name}.html">#{h(chap.title)}</a></li>)
            end
          end

          <<~HTML
            <nav class="toc">
              <h1>#{h(I18n.t('toctitle'))}</h1>
              <ol>
                #{toc_items.join("\n")}
              </ol>
            </nav>
          HTML
        end

        def build_body
          @compile_errors = nil

          @book.parts.each do |part|
            if part.name.present? && !part.file?
              build_part_html(part)
            end

            part.chapters.each do |chap|
              build_chapter_html(chap)
            end
          end

          check_compile_status
        end

        def build_part_html(part)
          @title = "#{I18n.t('part', part.number)} #{part.name}"
          @body = <<~HTML
            <div class="part">
              <h1 class="part-number">#{h(I18n.t('part', part.number))}</h1>
              <h2 class="part-title">#{h(part.name)}</h2>
            </div>
          HTML
          html = wrap_with_layout(@body, @title)
          filename = "part_#{part.number}.html"
          write_html_file(filename, html)
          @entry_files << filename
        end

        def build_chapter_html(chapter)
          id = File.basename(chapter.path, '.*')

          if @buildonly && !@buildonly.include?(id)
            warn "skip #{id}.re"
            return
          end

          begin
            # Compile chapter to AST
            compiler = ReVIEW::AST::Compiler.for_chapter(chapter)
            ast_root = compiler.compile_to_ast(chapter)

            # Render to HTML (body only, without layout wrapper)
            renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter)
            html_body = renderer.visit(ast_root)

            # Wrap with layout
            @title = chapter.title
            @body = html_body
            html = wrap_with_layout(@body, @title)

            filename = "#{chapter.name}.html"
            write_html_file(filename, html)
            @entry_files << filename

            debug("Compiled #{chapter.path} -> #{filename}")
          rescue StandardError => e
            @compile_errors = true
            error "compile error in #{chapter.path} (#{e.class})"
            error e.message
            if @config['debug']
              puts e.backtrace.first(10).join("\n")
            end
          end
        end

        def build_backmatter
          if @config['colophon']
            build_colophon
          end
        end

        def build_colophon
          @title = I18n.t('colophontitle')
          @body = generate_colophon_body
          html = wrap_with_layout(@body, @title)
          write_html_file('colophon.html', html)
          @entry_files << 'colophon.html'
        end

        def generate_colophon_body
          template_path = find_template_path('vivliostyle/_colophon.html.erb')
          if template_path && File.exist?(template_path)
            ReVIEW::Template.generate(path: template_path, binding: binding)
          else
            # Fallback simple colophon
            items = []
            (@config['colophon_order'] || []).each do |key|
              value = @config.name_of(key)
              next unless value

              label = I18n.t("colophon_#{key}", nil) || key
              items << "<dt>#{h(label)}</dt><dd>#{h(value)}</dd>"
            end

            <<~HTML
              <div class="colophon">
                <h1>#{h(@config.name_of('booktitle'))}</h1>
                <dl>
                  #{items.join("\n")}
                </dl>
                <p class="date">#{h(@config['date'].to_s)}</p>
              </div>
            HTML
          end
        end

        def wrap_with_layout(body, title)
          @body = body
          @title = title
          @language = @config['language']

          template_path = find_template_path('vivliostyle/layout.html.erb')
          if template_path && File.exist?(template_path)
            ReVIEW::Template.generate(path: template_path, binding: binding)
          else
            # Fallback layout
            javascript_tags = @javascripts.map { |js| "  #{js}" }.join("\n")
            stylesheet_links = @stylesheets.map do |css|
              %Q(  <link rel="stylesheet" href="#{h(css)}">)
            end.join("\n")

            <<~HTML
              <!DOCTYPE html>
              <html lang="#{h(@language)}">
              <head>
                <meta charset="UTF-8">
              #{javascript_tags}
              #{stylesheet_links}
                <title>#{h(@title)}</title>
              </head>
              <body>
              #{@body}
              </body>
              </html>
            HTML
          end
        end

        def write_html_file(filename, content)
          File.write(File.join(@path, filename), content)
        end

        def copy_images(from_dir, to_dir)
          return unless File.exist?(File.join(@basedir, from_dir))

          src_dir = File.join(@basedir, from_dir)
          FileUtils.mkdir_p(to_dir)

          exts = @config['image_ext'] || %w[png gif jpg jpeg svg]
          copy_images_recursive(src_dir, to_dir, exts)
        end

        def copy_images_recursive(src_dir, dest_dir, exts)
          Dir.foreach(src_dir) do |entry|
            next if entry.start_with?('.')

            src_path = File.join(src_dir, entry)
            dest_path = File.join(dest_dir, entry)

            if File.directory?(src_path)
              FileUtils.mkdir_p(dest_path)
              copy_images_recursive(src_path, dest_path, exts)
            elsif exts.any? { |ext| entry.downcase.end_with?(".#{ext}") }
              FileUtils.cp(src_path, dest_path)
            end
          end
        end

        def generate_vivliostyle_config
          author_names = join_with_separator(@config.names_of('aut'), I18n.t('names_splitter'))
          config_data = {
            'title' => @config.name_of('booktitle'),
            'author' => author_names,
            'language' => @config['language'],
            'size' => @config['vivliostylemaker']['size'] || 'JIS-B5',
            'entry' => @entry_files,
            'output' => "#{@config['bookname']}.pdf",
            'workspaceDir' => '.vivliostyle'
          }

          # Add theme if specified
          theme = @config['vivliostylemaker']['theme']
          if theme
            config_data['theme'] = theme
          end

          config_path = File.join(@path, 'vivliostyle.config.json')
          File.write(config_path, JSON.pretty_generate(config_data))
          debug('Generated vivliostyle.config.json')
        end

        def run_vivliostyle(_bookname)
          cmd = build_vivliostyle_command

          debug("Running: #{cmd.join(' ')}")

          # Execute vivliostyle
          Dir.chdir(@path) do
            result = system(*cmd)
            unless result
              error! 'Vivliostyle build failed. Check the output above for details.'
            end
          end
        end

        def build_vivliostyle_command
          cmd = if @config['vivliostylemaker']['use_npx']
                  # Use npx (ignores vivliostyle_path)
                  ['npx', '@vivliostyle/cli', 'build', '-c', 'vivliostyle.config.json']
                else
                  # Use vivliostyle_path
                  vivliostyle_path = resolve_vivliostyle_path
                  [vivliostyle_path, 'build', '-c', 'vivliostyle.config.json']
                end

          # Add press-ready option if specified
          if @config['vivliostylemaker']['press_ready']
            cmd << '--press-ready'
          end

          cmd
        end

        def resolve_vivliostyle_path
          vivliostyle_path = @config['vivliostylemaker']['vivliostyle_path'] || 'vivliostyle'

          # Check if vivliostyle exists
          if system("which #{vivliostyle_path} > /dev/null 2>&1") ||
             File.exist?(File.join(@basedir, vivliostyle_path))
            return vivliostyle_path
          end

          # Try to find in node_modules
          node_path = File.join(@basedir, 'node_modules', '.bin', 'vivliostyle')
          if File.exist?(node_path)
            return node_path
          end

          error! 'Vivliostyle CLI not found. Please install with: npm install @vivliostyle/cli'
        end

        def finalize_output(bookname)
          src_pdf = File.join(@path, "#{bookname}.pdf")
          dest_pdf = File.join(@basedir, "#{bookname}.pdf")

          if File.exist?(src_pdf)
            FileUtils.cp(src_pdf, dest_pdf)
            debug("Output: #{dest_pdf}")
          else
            error! "PDF file was not generated: #{src_pdf}"
          end
        end

        def check_compile_status
          if @compile_errors
            if @config['ignore-errors']
              warn 'compile error exists, but ignored due to --ignore-errors option'
            else
              error! 'compile error, PDF file not generated.'
            end
          end
        end

        def join_with_separator(value, sep)
          if value.is_a?(Array)
            value.join(sep)
          else
            value.to_s
          end
        end
      end
    end
  end
end
