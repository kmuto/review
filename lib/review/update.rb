#
# Copyright (c) 2018 Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".

require 'fileutils'
require 'optparse'
require 'review'
require 'review/i18n'
require 'yaml'
require 'digest'

module ReVIEW
  class Update
    def self.execute(*args)
      new.execute(*args)
    end

    # should be
    TARGET_VERSION = '3.0'
    EPUB_VERSION = '3'
    HTML_VERSION = '5'
    TEX_DOCUMENTCLASS = ['review-jsbook', 'review-jlreq']
    TEX_DOCUMENTCLASS_BAD = ['jsbook', nil]
    TEX_DOCUMENTCLASS_OPTS = 'cameraready=print,paper=a5'
    TEX_COMMAND = 'uplatex'
    TEX_OPTIONS = '-interaction=nonstopmode -file-line-error'

    def initialize
      @template = nil
      @specified_template = nil
      @force = nil
      @logger = ReVIEW.logger
      @review_dir = File.dirname(File.expand_path('..', __dir__))
      @config_ymls = []
      @locale_ymls = []
      @catalog_ymls = []
      @tex_ymls = []
      @epub_ymls = []

      @backup = true
      @ownlayout_tex = nil
    end

    def execute(*args)
      parse_options(args)
      dir = Dir.pwd

      parse_ymls(dir)
      check_old_catalogs(dir)

      show_version

      if @config_ymls.empty?
        @logger.error _("!! No *.yml file with 'review_version' was found. Aborted. !!")
        exit 1
      end

      check_own_files(dir)
      update_version
      update_rakefile
      update_epub_version
      update_tex_parameters
      if @template
        update_tex_stys(@template, dir)
      end
    end

    def _(message, args = [])
      unless I18n.get(message)
        I18n.set(message, message) # just copy
      end
      I18n.t(message, args)
    end

    def confirm(message, args = [], default = true)
      if @force
        print _(message, args)
        if default
          puts ' yes'
          return true
        else
          puts 'no'
          return nil
        end
      end

      loop do
        print _(message, args)
        if default
          print ' [y]/n '
        else
          print ' y/[n] '
        end
        case gets.chomp.downcase
        when 'yes', 'y'
          return true
        when 'no', 'n'
          return nil
        when ''
          default
        end
      end
    end

    def rewrite_yml(yml, key, val)
      content = File.read(yml)
      content.gsub!(/^#{key}:.*$/, "#{key}: #{val}")
      if @backup
        FileUtils.mv yml, "#{yml}-old"
      end
      File.open(yml, 'w') { |f| f.write(content) }
    end

    def parse_options(args)
      opts = OptionParser.new
      opts.version = ReVIEW::VERSION
      opts.banner = "Usage: #{File.basename($PROGRAM_NAME)} [option]"
      opts.on('-h', '--help', 'print this message and quit.') do
        puts opts.help
        exit 0
      end
      opts.on('--latex-template name', 'specify LaTeX template name. (default: review-jsbook)') do |tname|
        @specified_template = tname
      end
      opts.on('-y', '--yes', 'override files without asking.') do
        @force = true
      end

      begin
        opts.parse!(args)
      rescue OptionParser::ParseError => err
        @logger.error err.message
        $stderr.puts opts.help
        exit 1
      end

      if @specified_template
        tdir = File.join(@review_dir, 'templates/latex', @specified_template)
        unless File.exist?(tdir)
          @logger.error "!! #{tdir} not found. Aborted. !!"
          exit 1
        end
      end
    end

    def parse_ymls(dir)
      language = 'ja'

      Dir.glob(File.join(dir, '*.yml')) do |yml|
        begin
          config = YAML.load_file(yml)
          if config['language'].present?
            language = config['language']
          end

          if config['review_version'].present?
            @config_ymls.push(yml)
          end
          if config['texdocumentclass'].present? ||
             config['texcommand'].present? ||
             config['texoptions'].present? ||
             config['dvicommand'].present? ||
             config['dvioptions'].present? ||
             config['pdfmaker'].present?
            @tex_ymls.push(yml)
          end
          if config['epubmaker'].present? || config['epubversion'].present? ||
             config['htmlversion'].present?
            @epub_ymls.push(yml)
          end
          if config['locale'].present?
            @locale_ymls.push(yml)
          end
          if config['PREDEF'].present? || config['CHAPS'].present? ||
             config['APPENDIX'].present? || config['POSTDEF'].present?
            @catalog_ymls.push(yml)
          end
        rescue Psych::SyntaxError
          puts "!! #{yml} is broken. Ignored. !!"
        end
      end
      I18n.setup(language)

      @config_ymls.uniq!
      @locale_ymls.uniq!
      @catalog_ymls.uniq!
      @tex_ymls.uniq!
      @epub_ymls.uniq!
    end

    def check_old_catalogs(dir)
      files = Dir.glob(File.join(dir, '*')).map do |fname|
        if %w[PREDEF CHAPS POSTDEF PART].include?(File.basename(fname))
          File.basename(fname)
        else
          return nil
        end
      end.compact

      unless files.empty?
        @logger.error _("!! %s file(s) is obsoleted. Run 'review-catalog-converter' to convert to 'catalog.yml' and remove old files. Aborted. !!", files.join(', '))
        exit 1
      end
    end

    def show_version
      puts _('** review-update updates your project to %s **', ReVIEW::VERSION)
    end

    def check_own_files(dir)
      if File.exist?(File.join(dir, 'layouts/layout.tex.erb'))
        unless confirm('** There is custom layouts/layout.tex.erb file. Updating may break to make PDF until you fix layout.tex.erb. Do you really proceed to update? **', [], nil)
          exit 1
        end
      end

      if File.exist?(File.join(dir, 'review-ext.rb'))
        puts _('** There is review-ext.rb file. You need to update it by yourself. **')
      end
    end

    def update_version
      @config_ymls.each do |yml|
        config = YAML.load_file(yml)
        if config['review_version'].to_f >= TARGET_VERSION.to_f
          next
        end

        if confirm("%s: Update 'review_version' to '%s'?", [File.basename(yml), TARGET_VERSION])
          rewrite_yml(yml, 'review_version', TARGET_VERSION)
        end
      end
    end

    def update_rakefile(dir)
      taskdir = File.join(dir, 'lib/tasks')
      unless File.exist?(taskdir)
        FileUtils.mkdir_p taskdir
      end

      masterrakefile = File.join(@review_dir, 'samples/sample-book/src/Rakefile')
      if Digest::SHA256.hexdigest(File.join(dir, 'Rakefile')) != Digest::SHA256.hexdigest(masterrakefile)
        if confirm('%s will be overridden with Re:VIEW version (%s). Do you really proceed?', ['Rakefile', masterrakefile])
          FileUtils.mv File.join(dir, 'Rakefile'), File.join(dir, 'Rakefile-old')
          FileUtils.cp materrakefile, File.join(dir, 'Rakefile')
        end
      end

      masterrakefile = File.join(@review_dir, 'samples/sample-book/src/lib/tasks/review.rake')
      if Digest::SHA256.hexdigest(File.join(taskdir, 'review.rake')) != Digest::SHA256.hexdigest(masterrakefile)
        if confirm('%s will be overridden with Re:VIEW version (%s). Do you really proceed?', ['lib/tasks/review.rake', masterrakefile])
          FileUtils.mv File.join(taskdir, 'review.rake'), File.join(taskdir, 'review.rake-old')
          FileUtils.cp materrakefile, File.join(taskdir, 'review.rake')
        end
      end
    end

    def update_epub_version
      @epub_ymls.each do |yml|
        config = YAML.load_file(yml)
        if config['epubversion'].present? && config['epubversion'].to_f < EPUB_VERSION.to_f
          if confirm("%s: Update 'epubversion' to '%s'?", [File.basename(yml), EPUB_VERSION])
            rewrite_yml(yml, 'epubversion', EPUB_VERSION)
          end
        end
        if !config['htmlversion'].present? || config['htmlversion'].to_f >= HTML_VERSION.to_f
          next
        end
        if confirm("%s: Update 'htmlversion' to '%s'?", [File.basename(yml), HTML_VERSION])
          rewrite_yml(yml, 'htmlversion', HTML_VERSION)
        end
      end
    end

    def update_tex_parameters
      @tex_ymls.each do |yml|
        config = YAML.load_file(yml)
        unless config['texdocumentclass']
          next
        end

        if TEX_DOCUMENTCLASS.include?(config['texdocumentclass'][0])
          if config['texdocumentclass'][0] != @specified_template
            # want to use other template?
            # FIXME
          end
        else
          @template = config['texdocumentclass'][0]
        end

        if TEX_DOCUMENTCLASS_BAD.include?(config['texdocumentclass'][0])
          cno = TEX_DOCUMENTCLASS_BAD.index(config['texdocumentclass'][0])

          if @specified_template != TEX_DOCUMENTCLASS[cno]
            # not default, manually selected
            unless confirm("%s: 'texdocumentclass' uses the old class '%s'. By default it is migrated to '%s', but you specify '%s'. Do you really migrate 'texdocumentclass' to '%s'?",
                           [File.basename(yml), TEX_DOCUMENTCLASS_BAD[cno],
                            TEX_DOCUMENTCLASS[cno],
                            @specified_template, @specified_template])
              @template = nil
              next
            end
            @template = @specified_template
          else
            # default migration
            @template = TEX_DOCUMENTCLASS[cno]
            unless confirm("%s: 'texdocumentclass' uses the old class '%s'. By default it is migrated to '%s'. Do you really migrate 'texdocumentclass' to '%s'?", [File.basename(yml), TEX_DOCUMENTCLASS_BAD[cno], @template, @template])
              @template = nil
              next
            end
          end

          flag, modified_opts = convert_documentclass_opts(yml, @template, config['texdocumentclass'][1])
          if flag # successfully converted
            puts _("%s: previous 'texdocumentclass' option '%s' is safely replaced with '%s'.", [File.basename(yml), config['texdocumentclass'][1], modified_opts])
          else # something wrong
            unless confirm("%s: previous 'texdocumentclass' option '%s' couldn't be converted fully. '%s' is suggested. Do you really proceed?", [File.basename(yml), config['texdocumentclass'][1], modified_opts], nil)
              @template = nil
              next
            end
          end

          rewrite_yml(yml, 'texdocumentclass', %Q(["#{@template}", "#{modfied_opts}"]))
        else
          @template = nil
          @logger.error _("%s: ** 'texdocumentclass' specifies '%s'. Because this is unknown class for this tool, you need to update it by yourself if it won't work. **", [File.basename(yml), config['texdocumentclass']])
        end
      end
    end

    def convert_documentclass_opts(yml, cls, prev_opts)
      # XXX: at this time, review-jsbook and review-jlreq uses same parameters
      opts = []
      flag = true
      case cls
      when 'review-jsbook' # at this time, it ignores keyval
        prev_opts.split(/\s*,\s*/).each do |v|
          case v
          when 'a4j', 'a5j', 'b4j', 'b5j', 'a3paper', 'a4paper', 'a5paper', 'a6paper', 'b4paper', 'b5paper', 'b6paper', 'letterpaper', 'legalpaper', 'executivepaper'
            opts << "paper=#{v.sub('j', '').sub('paper', '')}"
          when /[\d.]+ptj/ # not cared...
            q = sprintf('%.2f', v.sub('pt', '').to_f * 1.4056)
            opts << "Q=#{q}"
          when /[\d.]+pt/
            q = sprintf('%.2f', v.sub('pt', '').to_f * 1.4056)
            opts << "Q=#{q}"
          when /[\d.]+Q/
            opts << "Q=#{v.sub('Q', '')}"
          when 'landscape', 'oneside', 'twoside', 'vartwoside', 'onecolumn',
               'twocolumn', 'titlepage', 'notitlepage', 'openright',
               'openany', 'leqno', 'fleqn', 'disablejfam', 'draft', 'final',
               'mingoth', 'winjis', 'jis', 'papersize', 'english', 'report',
               'jslogo', 'nojslogo'
            # pass-through
            opts << v
          when 'uplatex', 'nomag', 'usemag', 'nomag*', 'tombow', 'tombo', 'mentuke', 'autodetect-engine'
            # can be ignored
            next
          else
            flag = nil
          end
        end
        opts << 'cameraready=print'
        opts << 'cover=false'
      when 'review-jlreq'
        # at this time, only think about jsbook->jlreq
        prev_opts.split(/\s*,\s*/).each do |v|
          case v
          when 'a4j', 'a5j', 'b4j', 'b5j', 'a3paper', 'a4paper', 'a5paper', 'a6paper', 'b4paper', 'b5paper', 'b6paper', 'letterpaper', 'legalpaper', 'executivepaper'
            opts << "paper=#{v.sub('j', '').sub('paper', '')}"
          when /[\d.]+ptj/ # not cared...
            opts << "fontsize=#{v.sub('j', '')}"
          when /[\d.]+pt/
            opts << "fontsize=#{v}"
          when /[\d.]+Q/
            opts << "fontsize=#{v}"
          when 'landscape', 'oneside', 'twoside', 'onecolumn', 'twocolumn', 'titlepage', 'notitlepage', 'openright', 'openany', 'leqno', 'fleqn', 'draft', 'final', 'report'
            # pass-through
            opts << v
          when 'uplatex', 'nomag', 'usemag', 'nomag*', 'tombow', 'tombo', 'mentuke', 'autodetect-engine'
            # can be ignored
            next
          else
            # 'vartwoside', 'disablejfam', 'mingoth', 'winjis', 'jis', 'papersize', 'english', 'jslogo', 'nojslogo'
            flag = nil
          end
        end
        opts << 'cameraready=print'
        opts << 'cover=false'
      else
        flag = nil
        @logger.error _("%s: ** '%s' is unknown class. Ignored. **", [File.basename(yml), cls])
      end
      return flag, opts.join(',')
    end

    def update_tex_stys(template, dir)
      texmacrodir = File.join(dir, 'sty')
      unless File.exist?(texmacrodir)
        FileUtils.mkdir texmacrodir
      end

      tdir = File.join(@review_dir, 'templates/latex', template)
      Dir.glob(File.join(tdir, '*.*')).each do |fname|
        if fname == 'review-custom.sty'
          next
        end
        unless File.exist?(File.join(texmacrodir, fname))
          # just copy
          FileUtils.cp File.join(tdir, fname), texmacrodir
          next
        end

        if Digest::SHA256.hexdigest(File.join(tdir, fname)) == Digest::SHA256.hexdigest(File.join(texmacrodir, fname))
          # same
          next
        end

        if confirm('%s will be overridden with Re:VIEW version (%s). Do you really proceed?', [File.join('sty', fname), File.join(tdir, fname)])
          FileUtils.mv File.join(texmacrodir, fname), File.join(texmacrodir, "#{fname}-old")
          FileUtils.cp File.join(tdir, fname), texmacrodir
        end
      end

      if template == 'review-jsbook'
        # provide gentombow from vendor/. current version is 2018/08/30 v0.9j
        unless File.exist?(File.join(texmacrodir, 'gentombow09j.sty'))
          FileUtils.cp File.join(@review_dir, 'vendor/gentombow/gentombow.sty'), File.join(texmacrodir, 'gentombow09j.sty')
        end
      end
    end
  end
end
