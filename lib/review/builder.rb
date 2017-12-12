# Copyright (c) 2002-2017 Minero Aoki, Kenshi Muto
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
require 'stringio'
require 'cgi'

module ReVIEW
  class Builder
    include TextUtils

    CAPTION_TITLES = %w[note memo tip info warning important caution notice].freeze

    def pre_paragraph
      nil
    end

    def post_paragraph
      nil
    end

    def initialize(strict = false, *args)
      @strict = strict
      @output = nil
      @logger = ReVIEW.logger
      builder_init(*args)
    end

    def builder_init(*args)
    end
    private :builder_init

    def bind(compiler, chapter, location)
      @compiler = compiler
      @chapter = chapter
      @location = location
      @output = StringIO.new
      @book = @chapter.book if @chapter.present?
      @tabwidth = nil
      @tsize = nil
      @tabwidth = @book.config['tabwidth'] if @book && @book.config && @book.config['tabwidth']
      builder_init_file
    end

    def builder_init_file
      @sec_counter = SecCounter.new(5, @chapter)
    end
    private :builder_init_file

    def result
      @output.string
    end

    alias_method :raw_result, :result

    def print(*s)
      @output.print(*s)
    end

    def puts(*s)
      @output.puts(*s)
    end

    def target_name
      self.class.to_s.gsub(/ReVIEW::/, '').gsub(/Builder/, '').downcase
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
        list_header id, caption, lang
      rescue KeyError
        error "no such list: #{id}"
      end
      list_body id, lines, lang
    end

    def listnum(lines, id, caption, lang = nil)
      begin
        list_header id, caption, lang
      rescue KeyError
        error "no such list: #{id}"
      end
      listnum_body lines, lang
    end

    def source(lines, caption, lang = nil)
      source_header caption
      source_body lines, lang
    end

    def image(lines, id, caption, metric = nil)
      if @chapter.image(id).bound?
        image_image id, caption, metric
      else
        warn "image not bound: #{id}" if @strict
        image_dummy id, caption, lines
      end
    end

    def table(lines, id = nil, caption = nil)
      rows = []
      sepidx = nil
      lines.each_with_index do |line, idx|
        if /\A[\=\-]{12}/ =~ line
          # just ignore
          # error "too many table separator" if sepidx
          sepidx ||= idx
          next
        end
        rows.push(line.strip.split(/\t+/).map { |s| s.sub(/\A\./, '') })
      end
      rows = adjust_n_cols(rows)

      begin
        table_header id, caption if caption.present?
      rescue KeyError
        error "no such table: #{id}"
      end
      return if rows.empty?
      table_begin rows.first.size
      if sepidx
        sepidx.times { tr(rows.shift.map { |s| th(s) }) }
        rows.each { |cols| tr(cols.map { |s| td(s) }) }
      else
        rows.each do |cols|
          h, *cs = *cols
          tr([th(h)] + cs.map { |s| td(s) })
        end
      end
      table_end
    end

    def adjust_n_cols(rows)
      rows.each { |cols| cols.pop while cols.last and cols.last.strip.empty? }
      n_maxcols = rows.map(&:size).max
      rows.each { |cols| cols.concat [''] * (n_maxcols - cols.size) }
      rows
    end
    private :adjust_n_cols

    def emtable(lines, caption = nil)
      table(lines, nil, caption)
    end

    # def footnote(id, str)
    #   @footnotes.push [id, str]
    # end
    #
    # def flush_footnote
    #   footnote_begin
    #   @footnotes.each do |id, str|
    #     footnote_item(id, str)
    #   end
    #   footnote_end
    # end

    def compile_inline(s)
      @compiler.text(s)
    end

    def inline_chapref(id)
      compile_inline @book.chapter_index.display_string(id)
    rescue KeyError
      error "unknown chapter: #{id}"
      nofunc_text("[UnknownChapter:#{id}]")
    end

    def inline_chap(id)
      @book.chapter_index.number(id)
    rescue KeyError
      error "unknown chapter: #{id}"
      nofunc_text("[UnknownChapter:#{id}]")
    end

    def inline_title(id)
      compile_inline @book.chapter_index.title(id)
    rescue KeyError
      error "unknown chapter: #{id}"
      nofunc_text("[UnknownChapter:#{id}]")
    end

    def inline_list(id)
      "#{I18n.t('list')}#{@chapter.list(id).number}"
    rescue KeyError
      error "unknown list: #{id}"
      nofunc_text("[UnknownList:#{id}]")
    end

    def inline_img(id)
      "#{I18n.t('image')}#{@chapter.image(id).number}"
    rescue KeyError
      error "unknown image: #{id}"
      nofunc_text("[UnknownImage:#{id}]")
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
      "#{I18n.t('table')}#{@chapter.table(id).number}"
    rescue KeyError
      error "unknown table: #{id}"
      nofunc_text("[UnknownTable:#{id}]")
    end

    def inline_fn(id)
      @chapter.footnote(id).content
    rescue KeyError
      error "unknown footnote: #{id}"
      nofunc_text("[UnknownFootnote:#{id}]")
    end

    def inline_bou(str)
      text(str)
    end

    def inline_ruby(arg)
      base, *ruby = *arg.scan(/(?:(?:(?:\\\\)*\\,)|[^,\\]+)+/)
      base = base.gsub(/\\,/, ',') if base
      ruby = ruby.join(',').gsub(/\\,/, ',') if ruby
      compile_ruby(base, ruby)
    end

    def inline_kw(arg)
      word, alt = *arg.split(',', 2)
      compile_kw(word, alt)
    end

    def inline_href(arg)
      url, label = *arg.scan(/(?:(?:(?:\\\\)*\\,)|[^,\\]+)+/).map(&:lstrip)
      url = url.gsub(/\\,/, ',').strip
      label = label.gsub(/\\,/, ',').strip if label
      compile_href(url, label)
    end

    def text(str)
      str
    end

    def bibpaper(lines, id, caption)
      bibpaper_header id, caption
      unless lines.empty?
        puts
        bibpaper_bibpaper id, caption, lines
      end
      puts
    end

    def inline_hd(id)
      m = /\A([^|]+)\|(.+)/.match(id)
      chapter = @book.contents.detect { |chap| chap.id == m[1] } if m && m[1]
      if chapter
        inline_hd_chap(chapter, m[2])
      else
        inline_hd_chap(@chapter, id)
      end
    rescue KeyError
      error "unknown hd: #{id}"
      nofunc_text("[UnknownHeader:#{id}]")
    end

    def inline_column(id)
      m = /\A([^|]+)\|(.+)/.match(id)
      chapter = @book.chapters.detect { |chap| chap.id == m[1] } if m && m[1]
      if chapter
        inline_column_chap(chapter, m[2])
      else
        inline_column_chap(@chapter, id)
      end
    rescue KeyError
      error "unknown column: #{id}"
      nofunc_text("[UnknownColumn:#{id}]")
    end

    def inline_column_chap(chapter, id)
      chapter.column(id).caption
    end

    def inline_pageref(id)
      "[link:#{id}]"
    end

    def inline_tcy(arg)
      "#{arg}[rotate 90 degree]"
    end

    def raw(str)
      if matched = str.match(/\|(.*?)\|(.*)/)
        builders = matched[1].split(',').map { |i| i.gsub(/\s/, '') }
        c = target_name
        print matched[2].gsub('\\n', "\n") if builders.include?(c)
      else
        print str.gsub('\\n', "\n")
      end
    end

    def embed(lines, arg = nil)
      if arg
        builders = arg.gsub(/^\s*\|/, '').gsub(/\|\s*$/, '').gsub(/\s/, '').split(',')
        c = target_name
        print lines.join if builders.include?(c)
      else
        print lines.join
      end
    end

    def warn(msg)
      @logger.warn "#{@location}: #{msg}"
    end

    def error(msg)
      raise ApplicationError, msg if msg =~ /:\d+: error: /
      raise ApplicationError, "#{@location}: error: #{msg}"
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
        if param =~ /\A.+?::/
          next unless param =~ /\A#{type}::/
          param.sub!(/\A#{type}::/, '')
        end
        param2 = handle_metric(param)
        results.push(param2)
      end
      result_metric(results)
    end

    def get_chap(chapter = @chapter)
      if @book.config['secnolevel'] > 0 && !chapter.number.nil? && !chapter.number.to_s.empty?
        return I18n.t('part_short', chapter.number) if chapter.is_a?(ReVIEW::Book::Part)
        return chapter.format_number(nil)
      end
      nil
    end

    def extract_chapter_id(chap_ref)
      m = /\A([\w+-]+)\|(.+)/.match(chap_ref)
      return [@book.contents.detect { |chap| chap.id == m[1] }, m[2]] if m
      [@chapter, chap_ref]
    end

    def captionblock(_type, _lines, _caption, _specialstyle = nil)
      raise NotImplementedError
    end

    CAPTION_TITLES.each do |name|
      class_eval %Q(
        def #{name}(lines, caption = nil)
          captionblock("#{name}", lines, caption)
        end
      )
    end

    def graph(lines, id, command, caption = nil)
      c = target_name
      dir = File.join(@book.basedir, @book.image_dir, c)
      Dir.mkdir(dir) unless File.exist?(dir)
      file = "#{id}.#{image_ext}"
      file_path = File.join(dir, file)

      line = self.unescape(lines.join("\n"))
      cmds = {
        graphviz: "echo '#{line}' | dot -T#{image_ext} -o#{file_path}",
        gnuplot: %Q(echo 'set terminal ) +
        "#{image_ext == 'eps' ? 'postscript eps' : image_ext}\n" +
        %Q(" set output "#{file_path}"\n#{line}' | gnuplot),
        blockdiag: "echo '#{line}' " +
        "| blockdiag -a -T #{image_ext} -o #{file_path} /dev/stdin",
        aafigure: "echo '#{line}' | aafigure -t#{image_ext} -o#{file_path}"
      }
      cmd = cmds[command.to_sym]
      warn cmd
      system cmd
      @chapter.image_index.image_finder.add_entry(file_path)

      image(lines, id, caption)
    end

    def image_ext
      raise NotImplementedError
    end

    def inline_include(file_name)
      compile_inline File.read(file_name)
    end

    def include(file_name)
      File.foreach(file_name) { |line| paragraph([line]) }
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
        @tsize = matched[2] if builders.include?(c)
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

    ## override TextUtils::detab
    def detab(str, num = nil)
      if num
        super(str, num)
      elsif @tabwidth
        super(str, @tabwidth)
      else
        super(str)
      end
    end
  end
end # module ReVIEW
