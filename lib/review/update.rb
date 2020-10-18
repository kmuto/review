#
# Copyright (c) 2018-2020 Kenshi Muto
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
    TARGET_VERSION = '5.0'
    EPUB_VERSION = '3'
    HTML_VERSION = '5'
    TEX_DOCUMENTCLASS = ['review-jsbook', 'review-jlreq']
    TEX_DOCUMENTCLASS_BAD = ['jsbook', nil]
    TEX_DOCUMENTCLASS_OPTS = 'media=print,paper=a5'
    TEX_COMMAND = 'uplatex'
    TEX_OPTIONS = '-interaction=nonstopmode -file-line-error -halt-on-error'
    DVI_COMMAND = 'dvipdfmx'
    DVI_OPTIONS = '-d 5 -z 9'

    attr_reader :config_ymls, :locale_ymls, :catalog_ymls, :tex_ymls, :epub_ymls
    attr_accessor :force, :specified_template

    def initialize
      @template = '__DEFAULT__'
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
    end

    def execute(*args)
      parse_options(args)
      dir = Dir.pwd

      parse_ymls(dir)
      check_old_catalogs(dir)

      show_version

      if @config_ymls.empty?
        @logger.error t("!! No *.yml file with 'review_version' was found. Aborted. !!")
        raise ApplicationError
      end

      check_own_files(dir)
      update_version
      update_rakefile(dir)
      update_epub_version
      update_locale
      update_tex_parameters

      if @template
        if @template == '__DEFAULT__'
          @template = TEX_DOCUMENTCLASS[0]
        end
        update_tex_stys(@template, dir)
      end

      update_tex_command
      update_dvi_command

      puts t('Finished.')
    rescue ApplicationError
      exit 1
    end

    def t(message, args = [])
      unless I18n.get(message)
        I18n.set(message, message) # just copy
      end
      I18n.t(message, args)
    end

    def confirm(message, args = [], default = true)
      if @force
        @logger.info t(message, args)
        if default
          @logger.info ' yes'
          return true
        else
          @logger.info 'no'
          return nil
        end
      end

      loop do
        print t(message, args)
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
          return default
        end
      end
    end

    def rewrite_yml(yml, key, val)
      content = File.read(yml)
      content.gsub!(/^(\s*)#{key}:.*$/, '\1' + "#{key}: #{val}")
      if @backup
        FileUtils.mv(yml, "#{yml}-old")
      end
      File.write(yml, content)
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

      begin
        opts.parse!(args)
      rescue OptionParser::ParseError => e
        @logger.error e.message
        $stderr.puts opts.help
        raise ApplicationError
      end

      if @specified_template
        tdir = File.join(@review_dir, 'templates/latex', @specified_template)
        unless File.exist?(tdir)
          @logger.error "!! #{tdir} not found. Aborted. !!"
          raise ApplicationError
        end
      end
    end

    def parse_ymls(dir)
      language = 'en'

      Dir.glob(File.join(dir, '*.yml')).sort.each do |yml|
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
          @logger.error "!! #{yml} is broken. Ignored. !!"
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
        @logger.error t("!! %s file(s) is obsoleted. Run 'review-catalog-converter' to convert to 'catalog.yml' and remove old files. Aborted. !!", files.join(', '))
        raise ApplicationError
      end
    end

    def show_version
      puts t('** review-update updates your project to %s **', ReVIEW::VERSION)
    end

    def check_own_files(dir)
      if File.exist?(File.join(dir, 'layouts/layout.tex.erb'))
        unless confirm('** There is custom layouts/layout.tex.erb file. Updating may break to make PDF until you fix layout.tex.erb. Do you really proceed to update? **', [], nil)
          raise ApplicationError
        end
      end

      if File.exist?(File.join(dir, 'review-ext.rb'))
        @logger.info t('** There is review-ext.rb file. You need to update it by yourself. **')
      end
    end

    def update_version
      @config_ymls.each do |yml|
        config = YAML.load_file(yml)
        if config['review_version'].to_f.round(1) == TARGET_VERSION.to_f.round(1)
          next
        end

        flag = true
        if config['review_version'].to_f > TARGET_VERSION.to_f
          flag = nil
        end

        if confirm("%s: Update '%s' to '%s'?", [File.basename(yml), 'review_version', TARGET_VERSION], flag)
          rewrite_yml(yml, 'review_version', TARGET_VERSION)
        end
      end
    end

    def update_rakefile(dir)
      taskdir = File.join(dir, 'lib/tasks')
      unless File.exist?(taskdir)
        FileUtils.mkdir_p(taskdir)
      end

      master_rakefile = File.join(@review_dir, 'samples/sample-book/src/Rakefile')

      target_rakefile = File.join(dir, 'Rakefile')
      if File.exist?(target_rakefile)
        if Digest::SHA256.hexdigest(File.read(target_rakefile)) != Digest::SHA256.hexdigest(File.read(master_rakefile))
          if confirm('%s will be overridden with Re:VIEW version (%s). Do you really proceed?', ['Rakefile', master_rakefile])
            FileUtils.mv(target_rakefile, "#{target_rakefile}-old")
            FileUtils.cp(master_rakefile, target_rakefile)
          end
        end
      else
        @logger.info t('new file %s is created.', [target_rakefile]) unless @force
        FileUtils.cp(master_rakefile, target_rakefile)
      end

      master_rakefile = File.join(@review_dir, 'samples/sample-book/src/lib/tasks/review.rake')
      target_rakefile = File.join(taskdir, 'review.rake')
      if File.exist?(target_rakefile)
        if Digest::SHA256.hexdigest(File.read(target_rakefile)) != Digest::SHA256.hexdigest(File.read(master_rakefile))
          if confirm('%s will be overridden with Re:VIEW version (%s). Do you really proceed?', ['lib/tasks/review.rake', master_rakefile])
            FileUtils.mv(target_rakefile, "#{target_rakefile}-old")
            FileUtils.cp(master_rakefile, target_rakefile)
          end
        end
      else
        @logger.info t('new file %s is created.', [target_rakefile]) unless @force
        FileUtils.cp(master_rakefile, target_rakefile)
      end
    end

    def update_epub_version
      @epub_ymls.each do |yml|
        config = YAML.load_file(yml)
        if config['epubversion'].present? && config['epubversion'].to_f < EPUB_VERSION.to_f
          if confirm("%s: Update '%s' to '%s' from '%s'?", [File.basename(yml), 'epubversion', EPUB_VERSION, config['epubversion']])
            rewrite_yml(yml, 'epubversion', EPUB_VERSION)
          end
        end
        if !config['htmlversion'].present? || config['htmlversion'].to_f >= HTML_VERSION.to_f
          next
        end
        if confirm("%s: Update '%s' to '%s' from '%s'?", [File.basename(yml), 'htmlversion', HTML_VERSION, config['htmlversion']])
          rewrite_yml(yml, 'htmlversion', HTML_VERSION)
        end
      end
    end

    def update_locale
      @locale_ymls.each do |yml|
        config = YAML.load_file(yml)
        if !config['chapter_quote'].present? || config['chapter_quote'].scan('%s').size != 1
          next
        end
        v = config['chapter_quote'].sub('%s', '%s %s')
        if confirm("%s: 'chapter_quote' now takes 2 values. Update '%s' to '%s'?", [File.basename(yml), config['chapter_quote'], v])
          rewrite_yml(yml, 'chapter_quote', v)
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
          if @specified_template.present? && config['texdocumentclass'][0] != @specified_template
            # want to use other template?
            @logger.error t("%s: !! 'texdocumentclass' uses new class '%s' already, but you specified '%s'. This tool can't handle such migration. Ignored. !!", [File.basename(yml), config['texdocumentclass'][0], @specified_template])
            @template = nil
          else
            @template = config['texdocumentclass'][0]

            if @template == 'review-jsbook'
              update_review_jsbook_opts(yml, config['texdocumentclass'][1])
            end
          end

          # no need to update
          next
        end

        if TEX_DOCUMENTCLASS_BAD.include?(config['texdocumentclass'][0])
          cno = TEX_DOCUMENTCLASS_BAD.index(config['texdocumentclass'][0])

          if @specified_template && @specified_template != TEX_DOCUMENTCLASS[cno]
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
          rewrite_documentclass_opts_by_flag(flag, yml, config['texdocumentclass'][1], modified_opts)
        else
          @template = nil
          @logger.error t("%s: ** 'texdocumentclass' specifies '%s'. Because this is unknown class for this tool, you need to update it by yourself if it won't work. **", [File.basename(yml), config['texdocumentclass'][0]])
        end
      end
    end

    def rewrite_documentclass_opts_by_flag(flag, yml, old_opts, modified_opts)
      if flag # successfully converted
        @logger.info t("%s: previous 'texdocumentclass' option '%s' is safely replaced with '%s'.", [File.basename(yml), old_opts, modified_opts])
      else # something wrong
        unless confirm("%s: previous 'texdocumentclass' option '%s' couldn't be converted fully. '%s' is suggested. Do you really proceed?", [File.basename(yml), old_opts, modified_opts], nil)
          @template = nil
          return nil
        end
      end

      rewrite_yml(yml, 'texdocumentclass', %Q(["#{@template}", "#{modified_opts}"]))
    end

    def update_review_jsbook_opts(yml, old_opts)
      modified_opts = old_opts.gsub(/Q=([^,]+)/, 'fontsize=\1Q').
                      gsub(/W=([^,]+)/, 'line_length=\1zw').
                      gsub(/L=([^,]+)/, 'number_of_lines=\1').
                      gsub(/H=([^,]+)/, 'baselineskip=\1H').
                      gsub(/head=([^,]+)/, 'head_space=\1')

      if modified_opts == old_opts
        return nil
      end

      rewrite_documentclass_opts_by_flag(true, yml, old_opts, modified_opts)
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
            opts << "fontsize=#{v.sub('j', '')}"
          when /[\d.]+pt/
            opts << "fontsize=#{v}"
          when /[\d.]+Q/
            opts << "fontsize=#{v}"
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
        opts << 'media=print'
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
        opts << 'media=print'
        opts << 'cover=false'
      else
        flag = nil
        @logger.error t("%s: ** '%s' is unknown class. Ignored. **", [File.basename(yml), cls])
      end
      return flag, opts.join(',')
    end

    def update_tex_stys(template, dir)
      texmacrodir = File.join(dir, 'sty')
      unless File.exist?(texmacrodir)
        FileUtils.mkdir(texmacrodir)
      end

      tdir = File.join(@review_dir, 'templates/latex', template)
      Dir.glob(File.join(tdir, '*.*')).each do |master_styfile|
        target_styfile = File.join(texmacrodir, File.basename(master_styfile))

        unless File.exist?(target_styfile)
          # just copy
          @logger.info t('new file %s is created.', [target_styfile]) unless @force
          FileUtils.cp(master_styfile, target_styfile)
          next
        end
        if File.basename(target_styfile) == 'review-custom.sty'
          next
        end

        if Digest::SHA256.hexdigest(File.read(target_styfile)) == Digest::SHA256.hexdigest(File.read(master_styfile))
          # same
          next
        end

        if confirm('%s will be overridden with Re:VIEW version (%s). Do you really proceed?', [target_styfile, master_styfile])
          FileUtils.mv(target_styfile, "#{target_styfile}-old")
          FileUtils.cp(master_styfile, target_styfile)
        end
      end

      if template == 'review-jsbook'
        unless File.exist?(File.join(texmacrodir, 'jsbook.cls'))
          @logger.info t('new file %s is created.', [File.join(texmacrodir, 'jsbook.cls')]) unless @force
          FileUtils.cp(File.join(@review_dir, 'vendor/jsclasses/jsbook.cls'), File.join(texmacrodir, 'jsbook.cls'))
        end

        unless File.exist?(File.join(texmacrodir, 'gentombow.sty'))
          @logger.info t('new file %s is created.', [File.join(texmacrodir, 'gentombow.sty')]) unless @force
          FileUtils.cp(File.join(@review_dir, 'vendor/gentombow/gentombow.sty'), File.join(texmacrodir, 'gentombow.sty'))
        end
      end
    end

    def update_tex_command
      @tex_ymls.each do |yml|
        config = YAML.load_file(yml)
        if !config['texcommand'] || config['texcommand'] !~ /\s+-/
          next
        end
        # option should be moved to texoptions
        cmd, opts = config['texcommand'].split(/\s+-/, 2)
        opts = "-#{opts}"

        unless confirm("%s: 'texcommand' has options ('%s'). Move it to 'texoptions'?", [File.basename(yml), opts])
          next
        end

        if config['texoptions'].present?
          config['texoptions'] += " #{opts}"
          rewrite_yml(yml, 'texcommand', %Q("#{cmd}"))
          rewrite_yml(yml, 'texoptions', %Q("#{config['texoptions']}"))
        else
          rewrite_yml(yml, 'texcommand', %Q("#{cmd}"\ntexoptions: "#{TEX_OPTIONS} #{opts}"))
        end
      end
    end

    def update_dvi_command
      @tex_ymls.each do |yml|
        config = YAML.load_file(yml)
        if !config['dvicommand'] || config['dvicommand'] !~ /\s+-/
          next
        end

        # option should be moved to dvioptions
        cmd, opts = config['dvicommand'].split(/\s+-/, 2)
        opts = "-#{opts}"

        unless confirm("%s: 'dvicommand' has options ('%s'). Move it to 'dvioptions'?", [File.basename(yml), opts])
          next
        end

        if config['dvioptions'].present?
          config['dvioptions'] += " #{opts}"
          rewrite_yml(yml, 'dvicommand', %Q("#{cmd}"))
          rewrite_yml(yml, 'dvioptions', %Q("#{config['dvioptions']}"))
        else
          rewrite_yml(yml, 'dvicommand', %Q("#{cmd}"\ndvioptions: "#{DVI_OPTIONS} #{opts}"))
        end
      end
    end
  end
end
