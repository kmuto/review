# frozen_string_literal: true

# Copyright (c) 2002-2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

require 'review/book/index'
require 'review/exception'
require 'review/textutils'
require 'review/compiler'
require 'review/sec_counter'
require 'review/img_math'
require 'review/img_graph'
require 'review/loggable'
require 'stringio'
require 'fileutils'
require 'tempfile'
require 'csv'

module ReVIEW
  class Builder
    include TextUtils
    include Loggable

    CAPTION_TITLES = Compiler.minicolumn_names

    def pre_paragraph
      nil
    end

    def post_paragraph
      nil
    end

    attr_accessor :doc_status
    attr_reader :location

    def initialize(strict = false, *_args, img_math: nil, img_graph: nil)
      @strict = strict
      @output = nil
      @logger = ReVIEW.logger
      @doc_status = {}
      @dictionary = {}
      @img_math = img_math
      @img_graph = img_graph
      @shown_endnotes = true
    end

    def bind(compiler, chapter, location)
      @compiler = compiler
      @chapter = chapter
      @location = location
      @output = StringIO.new
      if @chapter.present?
        @book = @chapter.book
      end
      @chapter.generate_indexes
      if @book
        @book.generate_indexes
      end
      @tabwidth = nil
      @tsize = nil
      if @book && @book.config
        @img_math ||= ReVIEW::ImgMath.new(@book.config)
        @img_graph ||= ReVIEW::ImgGraph.new(@book.config, target_name)
        if words_file_path = @book.config['words_file']
          words_files = if words_file_path.is_a?(String)
                          [words_file_path]
                        else
                          words_file_path
                        end
          words_files.each do |f|
            load_words(f)
          end
        end
        if @book.config['tabwidth']
          @tabwidth = @book.config['tabwidth']
        end

        if @book.config['join_lines_by_lang']
          begin
            require 'unicode/eaw'
          rescue LoadError
            warn 'not found unicode/eaw. disabled join_lines_by_lang feature.', location: @location
            @book.config['join_lines_by_lang'] = nil
          end
        end
      end
      builder_init_file
    end

    def builder_init_file
      @sec_counter = SecCounter.new(5, @chapter)
      @doc_status = {}
    end
    private :builder_init_file

    def highlight?
      false
    end

    def solve_nest(s)
      check_nest
      s.gsub(/\x01→.+?←\x01/, '')
    end

    def check_nest
      if @children && !@children.empty?
        app_error "#{@location}: //beginchild of #{@children.reverse.join(',')} misses //endchild"
      end
    end

    def check_printendnotes
      if @shown_endnotes.nil?
        app_error "#{@location}: //endnote is found but //printendnotes is not found."
      end
    end

    def result
      check_printendnotes
      solve_nest(@output.string)
    end

    alias_method :raw_result, :result

    def print(*s)
      @output.print(*s)
    end

    def puts(*s)
      @output.puts(*s)
    end

    def target_name
      self.class.to_s.gsub('ReVIEW::', '').gsub('Builder', '').downcase
    end

    def load_words(file)
      if File.exist?(file) && /\.csv\Z/i.match?(file)
        CSV.foreach(file) do |row|
          @dictionary[row[0]] = row[1]
        end
      end
    end

    def headline_prefix(level)
      @sec_counter.inc(level)
      anchor = @sec_counter.anchor(level)
      prefix = @sec_counter.prefix(level, @book.config['secnolevel'])
      [prefix, anchor]
    end
    private :headline_prefix

    ## for //firstlinenum[num]
    def firstlinenum(num)
      @first_line_num = num.to_i
    end

    def line_num
      return 1 unless @first_line_num

      line_n = @first_line_num
      @first_line_num = nil

      line_n
    end

    def list(lines, id, caption, lang = nil)
      begin
        list_header(id, caption, lang) if caption_top?('list')
        list_body(id, lines, lang)
        list_header(id, caption, lang) unless caption_top?('list')
      rescue KeyError
        app_error "no such list: #{id}"
      end
    end

    def listnum(lines, id, caption, lang = nil)
      begin
        list_header(id, caption, lang) if caption_top?('list')
        listnum_body(lines, lang)
        list_header(id, caption, lang) unless caption_top?('list')
      rescue KeyError
        app_error "no such list: #{id}"
      end
    end

    def source(lines, caption = nil, lang = nil)
      source_header(caption) if caption_top?('list')
      source_body(lines, lang)
      source_header(caption) unless caption_top?('list')
    end

    def image(lines, id, caption, metric = nil)
      if @chapter.image_bound?(id)
        image_image(id, caption, metric)
      else
        warn "image not bound: #{id}", location: @location if @strict
        image_dummy(id, caption, lines)
      end
    end

    def table(lines, id = nil, caption = nil)
      sepidx, rows = parse_table_rows(lines)
      begin
        if caption_top?('table') && caption.present?
          table_header(id, caption)
        end
        table_begin(rows.first.size)
        table_rows(sepidx, rows)
        table_end
        if !caption_top?('table') && caption.present?
          table_header(id, caption)
        end
      rescue KeyError
        app_error "no such table: #{id}"
      end
    end

    def table_row_separator_regexp
      case @book.config['table_row_separator']
      when 'tabs'
        Regexp.new('\t+')
      when 'singletab'
        Regexp.new('\t')
      when 'spaces'
        Regexp.new('\s+')
      when 'verticalbar'
        Regexp.new('\s*\\' + escape('|') + '\s*')
      else
        app_error "Unknown value for 'table_row_separator', should be: tabs, singletab, spaces, verticalbar"
      end
    end

    def parse_table_rows(lines)
      sepidx = nil
      rows = []
      lines.each_with_index do |line, idx|
        # {} is for LaTeX
        if /\A[=-]{12}/ =~ line || /\A[={}-]{12}/ =~ line
          sepidx ||= idx
          next
        end
        rows.push(line.strip.split(table_row_separator_regexp).map { |s| s.sub(/\A\./, '') })
      end
      rows = adjust_n_cols(rows)
      app_error 'no rows in the table' if rows.empty?
      [sepidx, rows]
    end

    def table_rows(sepidx, rows)
      if sepidx
        sepidx.times do
          tr(rows.shift.map { |s| th(s) })
        end
        rows.each do |cols|
          tr(cols.map { |s| td(s) })
        end
      else
        rows.each do |cols|
          h, *cs = *cols
          tr([th(h)] + cs.map { |s| td(s) })
        end
      end
    end

    def adjust_n_cols(rows)
      rows.each do |cols|
        while cols.last && cols.last.strip.empty?
          cols.pop
        end
      end
      n_maxcols = rows.map(&:size).max
      rows.each do |cols|
        cols.concat([''] * (n_maxcols - cols.size))
      end
      rows
    end
    private :adjust_n_cols

    def emtable(lines, caption = nil)
      table(lines, nil, caption)
    end

    def printendnotes
      @shown_endnotes = true
      endnote_begin
      @chapter.endnotes.each do |en|
        endnote_item(en.id)
      end
      endnote_end
    end

    def endnote(_id, _str)
      @shown_endnotes = nil
    end

    def endnote_begin
    end

    def endnote_end
    end

    def endnote_item(id)
      puts "(#{@chapter.endnote(id).number}) #{compile_inline(@chapter.endnote(id).content)}"
    end

    def blankline
      puts ''
    end

    def compile_inline(s)
      @compiler.text(s)
    end

    def inline_chapref(id)
      compile_inline(@book.chapter_index.display_string(id))
    rescue KeyError
      app_error "unknown chapter: #{id}"
    end

    def inline_chap(id)
      @book.chapter_index.number(id)
    rescue KeyError
      app_error "unknown chapter: #{id}"
    end

    def inline_title(id)
      compile_inline(@book.chapter_index.title(id))
    rescue KeyError
      app_error "unknown chapter: #{id}"
    end

    def inline_list(id)
      chapter, id = extract_chapter_id(id)
      if get_chap(chapter)
        %Q(#{I18n.t('list')}#{I18n.t('format_number', [get_chap(chapter), chapter.list(id).number])})
      else
        %Q(#{I18n.t('list')}#{I18n.t('format_number_without_chapter', [chapter.list(id).number])})
      end
    rescue KeyError
      app_error "unknown list: #{id}"
    end

    def inline_img(id)
      chapter, id = extract_chapter_id(id)
      if get_chap(chapter)
        %Q(#{I18n.t('image')}#{I18n.t('format_number', [get_chap(chapter), chapter.image(id).number])})
      else
        %Q(#{I18n.t('image')}#{I18n.t('format_number_without_chapter', [chapter.image(id).number])})
      end
    rescue KeyError
      app_error "unknown image: #{id}"
    end

    def inline_imgref(id)
      img = inline_img(id)

      if @chapter.image(id).caption
        "#{img}#{I18n.t('image_quote', @chapter.image(id).caption)}"
      else
        img
      end
    end

    def inline_table(id)
      chapter, id = extract_chapter_id(id)
      if get_chap(chapter)
        %Q(#{I18n.t('table')}#{I18n.t('format_number', [get_chap(chapter), chapter.table(id).number])})
      else
        %Q(#{I18n.t('table')}#{I18n.t('format_number_without_chapter', [chapter.table(id).number])})
      end
    rescue KeyError
      app_error "unknown table: #{id}"
    end

    def inline_eq(id)
      chapter, id = extract_chapter_id(id)
      if get_chap(chapter)
        %Q(#{I18n.t('equation')}#{I18n.t('format_number', [get_chap(chapter), chapter.equation(id).number])})
      else
        %Q(#{I18n.t('equation')}#{I18n.t('format_number_without_chapter', [chapter.equation(id).number])})
      end
    rescue KeyError
      app_error "unknown equation: #{id}"
    end

    def inline_fn(id)
      @chapter.footnote(id).content
    rescue KeyError
      app_error "unknown footnote: #{id}"
    end

    def inline_endnote(id)
      "(#{@chapter.endnote(id).number})"
    rescue KeyError
      app_error "unknown endnote: #{id}"
    end

    def inline_bou(str)
      text(str)
    end

    def inline_ruby(arg)
      base, *ruby = *arg.scan(/(?:(?:(?:\\\\)*\\,)|[^,\\]+)+/)
      if base
        base = base.gsub('\,', ',').strip
      end
      if ruby
        ruby = ruby.join(',').gsub('\,', ',').strip
      end
      compile_ruby(base, ruby)
    end

    def inline_kw(arg)
      word, alt = *arg.split(',', 2)
      compile_kw(word, alt)
    end

    def inline_href(arg)
      url, label = *arg.scan(/(?:(?:(?:\\\\)*\\,)|[^,\\]+)+/).map(&:lstrip)
      url = url.gsub('\,', ',').strip
      if label
        label = label.gsub('\,', ',').strip
      end
      compile_href(url, label)
    end

    def text(str)
      str
    end

    def bibpaper(lines, id, caption)
      bibpaper_header(id, caption)
      unless lines.empty?
        puts
        bibpaper_bibpaper(id, caption, lines)
      end
      puts
    end

    def inline_hd(id)
      m = /\A([^|]+)\|(.+)/.match(id)
      if m && m[1]
        chapter = @book.contents.detect { |chap| chap.id == m[1] }
      end
      if chapter
        inline_hd_chap(chapter, m[2])
      else
        inline_hd_chap(@chapter, id)
      end
    rescue KeyError
      app_error "unknown headline: #{id}"
    end

    alias_method :inline_secref, :inline_hd

    def inline_sec(id)
      chapter, id = extract_chapter_id(id)
      n = chapter.headline_index.number(id)
      if n.present? && chapter.number && over_secnolevel?(n)
        n
      else
        app_error "the target headline doesn't have a number: #{id}"
      end
    rescue KeyError
      app_error "unknown headline: #{id}"
    end

    def inline_sectitle(id)
      chapter, id = extract_chapter_id(id)
      compile_inline(chapter.headline(id).caption)
    rescue KeyError
      app_error "unknown headline: #{id}"
    end

    def inline_column(id)
      m = /\A([^|]+)\|(.+)/.match(id)
      if m && m[1]
        chapter = @book.chapters.detect { |chap| chap.id == m[1] }
      end
      if chapter
        inline_column_chap(chapter, m[2])
      else
        inline_column_chap(@chapter, id)
      end
    rescue KeyError
      app_error "unknown column: #{id}"
    end

    def inline_column_chap(chapter, id)
      I18n.t('column', chapter.column(id).caption)
    end

    def inline_pageref(id)
      "[link:#{id}]"
    end

    def inline_tcy(arg)
      "#{arg}[rotate 90 degree]"
    end

    def inline_balloon(arg)
      "← #{arg}"
    end

    def inline_w(s)
      translated = @dictionary[s]
      if translated
        escape(translated)
      else
        warn "word not bound: #{s}", location: @location
        escape("[missing word: #{s}]")
      end
    end

    def inline_wb(s)
      inline_b(@dictionary[s] || "[missing word: #{s}]")
    end

    def raw(str)
      if matched = str.match(/\|(.*?)\|(.*)/)
        builders = matched[1].split(',').map { |i| i.gsub(/\s/, '') }
        c = target_name
        if builders.include?(c)
          print matched[2].gsub('\\n', "\n")
        end
      else
        print str.gsub('\\n', "\n")
      end
    end

    def embed(lines, arg = nil)
      if arg
        builders = arg.gsub(/^\s*\|/, '').gsub(/\|\s*$/, '').gsub(/\s/, '').split(',')
        c = target_name
        print lines.join("\n") + "\n" if builders.include?(c)
      else
        print lines.join("\n") + "\n"
      end
    end

    def handle_metric(str)
      str
    end

    def result_metric(array)
      array.join(',')
    end

    def parse_metric(type, metric)
      return '' if metric.blank?

      params = metric.split(/,\s*/)
      results = []
      params.each do |param|
        if /\A.+?::/.match?(param)
          next unless /\A#{type}::/.match?(param)

          param.sub!(/\A#{type}::/, '')
        end
        param2 = handle_metric(param)
        results.push(param2)
      end
      result_metric(results)
    end

    def get_chap(chapter = @chapter)
      if @book.config['secnolevel'] > 0 && !chapter.number.nil? && !chapter.number.to_s.empty?
        if chapter.is_a?(ReVIEW::Book::Part)
          return I18n.t('part_short', chapter.number)
        else
          return chapter.format_number(nil)
        end
      end
      nil
    end

    def extract_chapter_id(chap_ref)
      m = /\A([\w+-]+)\|(.+)/.match(chap_ref)
      if m
        ch = @book.contents.detect { |chap| chap.id == m[1] }
        raise KeyError unless ch

        return [ch, m[2]]
      end
      [@chapter, chap_ref]
    end

    def captionblock(_type, _lines, _caption, _specialstyle = nil)
      raise NotImplementedError
    end

    CAPTION_TITLES.each do |name|
      class_eval %Q(
        def #{name}(lines, caption = nil)
          check_nested_minicolumn
          captionblock("#{name}", lines, caption)
        end

        def #{name}_begin(caption = nil)
          check_nested_minicolumn
          @doc_status[:minicolumn] = '#{name}'
          if caption
            puts compile_inline(caption)
          end
        end

        def #{name}_end
          @doc_status[:minicolumn] = nil
        end
      ), __FILE__, __LINE__ - 17
    end

    def check_nested_minicolumn
      if @doc_status[:minicolumn]
        app_error "#{@location}: nested mini-column is not allowed"
      end
    end

    def in_minicolumn?
      @doc_status[:minicolumn]
    end

    def minicolumn_block_name?(name)
      CAPTION_TITLES.include?(name)
    end

    def graph(lines, id, command, caption = '')
      c = target_name
      dir = File.join(@book.imagedir, c)
      FileUtils.mkdir_p(dir)
      file = "#{id}.#{image_ext}"
      file_path = File.join(dir, file)

      content = lines.join("\n") + "\n"

      tf = Tempfile.new('review_graph')
      tf.puts content
      tf.close
      begin
        file_path = send(:"graph_#{command}", id, file_path, content, tf.path)
      ensure
        tf.unlink
      end
      @chapter.image_index.image_finder.add_entry(file_path)

      image(lines, id, caption)
    end

    def system_graph(id, *args)
      @logger.info args.join(' ')
      Kernel.system(*args) or @logger.error("failed to run command for id #{id}: #{args.join(' ')}")
    end

    def graph_graphviz(id, file_path, _line, tf_path)
      system_graph(id, 'dot', "-T#{image_ext}", "-o#{file_path}", tf_path)
      file_path
    end

    def graph_gnuplot(id, file_path, line, tf_path)
      File.open(tf_path, 'w') do |tf|
        tf.puts <<EOTGNUPLOT
set terminal #{image_ext == 'eps' ? 'postscript eps' : image_ext}
set output "#{file_path}"
#{line}
EOTGNUPLOT
      end
      system_graph(id, 'gnuplot', tf_path)
      file_path
    end

    def graph_blockdiag(id, file_path, _line, tf_path)
      system_graph(id, 'blockdiag', '-a', '-T', image_ext, '-o', file_path, tf_path)
      file_path
    end

    def graph_aafigure(id, file_path, _line, tf_path)
      system_graph(id, 'aafigure', '-t', image_ext, '-o', file_path, tf_path)
      file_path
    end

    def graph_plantuml(id, file_path, _line, tf_path)
      ext = image_ext
      if ext == 'pdf'
        ext = 'eps'
        file_path.sub!(/\.pdf\Z/, '.eps')
      end
      plant_path = nil
      if File.exist?('plantuml.jar')
        plant_path = 'plantuml.jar'
      elsif File.exist?('/usr/share/plantuml/plantuml.jar')
        plant_path = '/usr/share/plantuml/plantuml.jar'
      elsif File.exist?('/usr/share/java/plantuml.jar')
        plant_path = '/usr/share/java/plantuml.jar'
      else
        error!('missing plantuml.jar. Please put plantuml.jar at the working folder.')
      end
      system_graph(id, 'java', '-jar', plant_path, "-t#{ext}", '-charset', 'UTF-8', tf_path)
      FileUtils.mv("#{tf_path}.#{ext}", file_path)
      file_path
    end

    def graph_mermaid(id, _file_path, _line, tf_path)
      begin
        require 'playwrightrunner'
      rescue LoadError
        app_error "#{@location}: could not handle Mermaid of //graph in this builder."
      end

      @img_graph.defer_mermaid_image(File.read(tf_path), id)
    end

    def image_ext
      raise NotImplementedError
    end

    def inline_include(file_name)
      compile_inline(File.read(file_name, mode: 'rt:BOM|utf-8').chomp)
    end

    def ul_item_begin(lines)
      ul_item(lines)
    end

    def ul_item_end
    end

    def tsize(str)
      if matched = str.match(/\A\|(.*?)\|(.*)/)
        builders = matched[1].split(',').map { |i| i.gsub(/\s/, '') }
        c = self.class.to_s.gsub('ReVIEW::', '').gsub('Builder', '').downcase
        if builders.include?(c)
          @tsize = matched[2]
        end
      else
        @tsize = str
      end
    end

    def inline_raw(args)
      if matched = args.match(/\|(.*?)\|(.*)/)
        builders = matched[1].split(',').map { |i| i.gsub(/\s/, '') }
        c = self.class.to_s.gsub('ReVIEW::', '').gsub('Builder', '').downcase
        if builders.include?(c)
          matched[2].gsub('\\n', "\n")
        else
          ''
        end
      else
        args.gsub('\\n', "\n")
      end
    end

    def inline_embed(args)
      if matched = args.match(/\|(.*?)\|(.*)/)
        builders = matched[1].split(',').map { |i| i.gsub(/\s/, '') }
        if builders.include?(target_name)
          matched[2]
        else
          ''
        end
      else
        args
      end
    end

    def over_secnolevel?(n)
      @book.config['secnolevel'] >= n.to_s.split('.').size
    end

    ## override TextUtils::detab
    def detab(str, num = nil)
      if num
        super
      elsif @tabwidth
        super(str, @tabwidth)
      else
        super(str)
      end
    end

    def escape(str)
      str
    end

    def previous_list_type
      @compiler.previous_list_type
    end

    def beginchild
      @children ||= []
      unless previous_list_type
        app_error "#{@location}: //beginchild is shown, but previous element isn't ul, ol, or dl"
      end
      puts "\x01→#{previous_list_type}←\x01"
      @children.push(previous_list_type)
    end

    def endchild
      if @children.nil? || @children.empty?
        app_error "#{@location}: //endchild is shown, but any opened //beginchild doesn't exist"
      else
        puts "\x01→/#{@children.pop}←\x01"
      end
    end

    def caption_top?(type)
      unless %w[top bottom].include?(@book.config['caption_position'][type])
        warn "invalid caption_position/#{type} parameter. 'top' is assumed", location: @location
      end
      @book.config['caption_position'][type] != 'bottom'
    end
  end
end # module ReVIEW
