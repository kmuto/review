# encoding: utf-8
#
# Copyright (c) 2002-2014 Minero Aoki, Kenshi Muto
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

    CAPTION_TITLES = %w(note memo tip info planning best important security caution term link notice point shoot reference practice expert)

    attr_accessor :output
    attr_accessor :ast

    def pre_paragraph
      nil
    end
    def post_paragraph
      nil
    end

    def initialize(strict = false, *args)
      @strict = strict
      builder_init(*args)
    end

    def builder_init(*args)
    end
    private :builder_init

    def bind(compiler, chapter, location)
      @compiler = compiler
      @chapter = chapter
      @location = location
      @ast = nil
      @output = StringIO.new
      @book = @chapter.book if @chapter.present?
      @tabwidth = nil
      if @book && @book.config && @book.config["tabwidth"]
        @tabwidth = @book.config["tabwidth"]
      end
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
      raise NotImplementedError, "XXX: `print` method is obsoleted. Do not use it."
    end

    def puts(*s)
      raise NotImplementedError, "XXX: `puts` method is obsoleted. Do not use it."
    end

    def target_name
      self.class.to_s.gsub(/ReVIEW::/, '').gsub(/Builder/, '').downcase
    end

    def headline_prefix(level)
      @sec_counter.inc(level)
      anchor = @sec_counter.anchor(level)
      prefix = @sec_counter.prefix(level, @book.config["secnolevel"])
      [prefix, anchor]
    end
    private :headline_prefix

    def list(lines, id, caption = nil, lang = nil)
      buf = ""
      begin
        buf << list_header(id, caption, lang)
      rescue KeyError
        error "no such list: #{id}"
      end
      buf << list_body(id, lines, lang)
      buf
    end

    def listnum(lines, id, caption = nil, lang = nil)
      buf = ""
      begin
        buf << list_header(id, caption, lang)
      rescue KeyError
        error "no such list: #{id}"
      end
      buf << listnum_body(lines, lang)
      buf
    end

    def source(lines, caption = nil)
      buf = ""
      buf << source_header(caption)
      buf << source_body(lines)
      buf
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
      buf = ""
      rows = []
      sepidx = nil
      lines.each_with_index do |line, idx|
        if /\A[\=\-]{12}/ =~ line
          # just ignore
          #error "too many table separator" if sepidx
          sepidx ||= idx
          next
        end
        rows.push line.strip.split(/\t+/).map {|s| s.sub(/\A\./, '') }
      end
      rows = adjust_n_cols(rows)

      begin
        buf << table_header(id, caption) unless caption.nil?
      rescue KeyError
        error "no such table: #{id}"
      end
      return buf if rows.empty?
      buf << table_begin(rows.first.size)
      if sepidx
        sepidx.times do
          buf << tr(rows.shift.map {|s| th(s) })
        end
        rows.each do |cols|
          buf << tr(cols.map {|s| td(s) })
        end
      else
        rows.each do |cols|
          h, *cs = *cols
          buf << tr([th(h)] + cs.map {|s| td(s) })
        end
      end
      buf << table_end
      buf
    end

    def adjust_n_cols(rows)
      rows.each do |cols|
        while cols.last and cols.last.strip.empty?
          cols.pop
        end
      end
      n_maxcols = rows.map {|cols| cols.size }.max
      rows.each do |cols|
        cols.concat [''] * (n_maxcols - cols.size)
      end
      rows
    end
    private :adjust_n_cols

    #def footnote(id, str)
    #  @footnotes.push [id, str]
    #end
    #
    #def flush_footnote
    #  footnote_begin
    #  @footnotes.each do |id, str|
    #    footnote_item(id, str)
    #  end
    #  footnote_end
    #end

#    def compile_inline(s)
#      @compiler.text(s)
#    end

    def inline_chapref(id)
      @book.chapter_index.display_string(id)
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
      "#{I18n.t("list")}#{@chapter.list(id).number}"
    rescue KeyError
      error "unknown list: #{id}"
      nofunc_text("[UnknownList:#{id}]")
    end

    def inline_img(id)
      "#{I18n.t("image")}#{@chapter.image(id).number}"
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
      "#{I18n.t("table")}#{@chapter.table(id).number}"
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

    def inline_ruby(base, ruby)
      compile_ruby(base, ruby)
    end

    def inline_kw(word, alt = nil)
      compile_kw(word, alt)
    end

    def inline_href(url, label = nil)
      url = url.strip
      label = label.strip if label
      compile_href(url, label)
    end

    def text(str)
      str
    end

    def bibpaper(lines, id, caption)
      buf = ""
      buf << bibpaper_header(id, caption)
      unless lines.empty?
        buf << "\n"
        buf << bibpaper_bibpaper(id, caption, lines)
      end
      buf << "\n"
      buf
    end

    def node_inline_hd(nodelist)
      id = nodelist[0].to_raw
      m = /\A([^|]+)\|(.+)/.match(id)
      chapter = @book.chapters.detect{|chap| chap.id == m[1]} if m && m[1]
      return inline_hd_chap(chapter, m[2]) if chapter
      return inline_hd_chap(@chapter, id)
    end

    def inline_column(id)
      @chapter.column(id).caption
    rescue
      error "unknown column: #{id}"
      nofunc_text("[UnknownColumn:#{id}]")
    end

    def raw(str)
      if matched = str.match(/\|(.*?)\|(.*)/)
        builders = matched[1].split(/,/).map{|i| i.gsub(/\s/, '') }
        c = target_name
        if builders.include?(c)
          matched[2].gsub("\\n", "\n")
        else
          ""
        end
      else
        str.gsub("\\n", "\n")
      end
    end

    def warn(msg)
      $stderr.puts "#{@location}: warning: #{msg}"
    end

    def error(msg)
      raise ApplicationError, "error: #{msg} at #{@compiler.show_pos} \n  (#{@compiler.failure_oneline})"
    end

    def handle_metric(str)
      str
    end

    def result_metric(array)
      array.join(',')
    end

    def parse_metric(type, metric)
      return "" if metric.blank?
      params = metric.split(/,\s*/)
      results = []
      params.each do |p|
        if p =~ /\A.+?::/
          if p =~ /\A#{type}::/
              p.sub!(/\A#{type}::/, '')
          else
            next
          end
        end
        p = handle_metric(p)
        results.push(p)
      end
      return result_metric(results)
    end

    def get_chap(chapter = @chapter)
      if @book.config["secnolevel"] > 0 && !chapter.number.nil? && !chapter.number.to_s.empty?
        return "#{chapter.number}"
      end
      return nil
    end

    def extract_chapter_id(chap_ref)
      m = /\A([\w+-]+)\|(.+)/.match(chap_ref)
      if m
        return [@book.chapters.detect{|chap| chap.id == m[1]}, m[2]]
      else
        return [@chapter, chap_ref]
      end
    end

    def captionblock(type, lines, caption, specialstyle = nil)
      raise NotImplementedError
    end

    CAPTION_TITLES.each do |name|
      class_eval %Q{
        def #{name}(lines, caption = nil)
          captionblock("#{name}", lines, caption)
        end
      }
    end

    def graph(lines, id, command, caption = nil)
      c = target_name
      dir = File.join(@book.basedir, @book.image_dir, c)
      Dir.mkdir(dir) unless File.exist?(dir)
      file = "#{id}.#{image_ext}"
      file_path = File.join(dir, file)

      line = self.unescape(lines.join("\n"))
      cmds = {
        :graphviz => "echo '#{line}' | dot -T#{image_ext} -o#{file_path}",
        :gnuplot  => "echo 'set terminal " +
        "#{(image_ext == "eps") ? "postscript eps" : image_ext}\n" +
        " set output \"#{file_path}\"\n#{line}' | gnuplot",
        :blockdiag => "echo '#{line}' "+
        "| blockdiag -a -T #{image_ext} -o #{file_path} /dev/stdin",
        :aafigure => "echo '#{line}' | aafigure -t#{image_ext} -o#{file_path}",
      }
      cmd = cmds[command.to_sym]
      warn cmd
      system cmd
      @chapter.image_index.image_finder.add_entry(file_path)

      image(lines, id, caption ||= "")
    end

    def image_ext
      raise NotImplementedError
    end

    def include(file_name)
      File.foreach(file_name) do |line|
        paragraph([convert_inencoding(line, @book.config["inencoding"])])
      end
    end

    def ul_item_begin(lines)
      ul_item(lines)
    end

    def ul_item_end
      ""
    end

    def inline_raw(args)
      if matched = args.match(/\|(.*?)\|(.*)/)
        builders = matched[1].split(/,/).map{|i| i.gsub(/\s/, '') }
        c = self.class.to_s.gsub(/ReVIEW::/, '').gsub(/Builder/, '').downcase
        if builders.include?(c)
          matched[2].gsub("\\n", "\n")
        else
          ""
        end
      else
        args.gsub("\\n", "\n")
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

end   # module ReVIEW
