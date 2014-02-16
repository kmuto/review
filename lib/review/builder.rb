# encoding: utf-8
#
# Copyright (c) 2002-2009 Minero Aoki
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

require 'review/book/index'
require 'review/exception'
require 'review/textutils'
require 'review/compiler'
require 'stringio'
require 'cgi'

module ReVIEW

  class Builder
    include TextUtils

    CAPTION_TITLES = %w(note memo tip info planning best important security caution term link notice point shoot reference practice expert)

    def highlighter
      @highlighter
    end

    def highlighter=(highlighter)
      @highlighter = highlighter
      @highlighter.builder = self
    end

    def pre_paragraph
      nil
    end
    def post_paragraph
      nil
    end

    def initialize(strict = false, *args)
      @strict = strict
      @tabwidth = nil
      if ReVIEW.book.param && ReVIEW.book.param["tabwidth"]
        @tabwidth = ReVIEW.book.param["tabwidth"]
      end
      @highlighter = nil
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
      @book = ReVIEW.book
      builder_init_file
    end

    def builder_init_file
    end
    private :builder_init_file

    def result
      @output.string
    end

    alias :raw_result result

    def print(*s)
      @output.print *s.map{|i|
        convert_outencoding(i, ReVIEW.book.param["outencoding"])
      }
    end

    def puts(*s)
      @output.puts *s.map{|i|
        convert_outencoding(i, ReVIEW.book.param["outencoding"])
      }
    end

    def list(lines, id, caption)
      begin
        list_header id, caption
      rescue KeyError
        error "no such list: #{id}"
      end
      list_body id, lines
    end

    def listnum(lines, id, caption)
      begin
        list_header id, caption
      rescue KeyError
        error "no such list: #{id}"
      end
      listnum_body lines
    end

    def source(lines, caption)
      source_header caption
      source_body lines
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
          #error "too many table separator" if sepidx
          sepidx ||= idx
          next
        end
        rows.push line.strip.split(/\t+/).map {|s| s.sub(/\A\./, '') }
      end
      rows = adjust_n_cols(rows)

      begin
        table_header id, caption unless caption.nil?
      rescue KeyError => err
        error "no such table: #{id}"
      end
      return if rows.empty?
      table_begin rows.first.size
      if sepidx
        sepidx.times do
          tr rows.shift.map {|s| th(s) }
        end
        rows.each do |cols|
          tr cols.map {|s| td(s) }
        end
      else
        rows.each do |cols|
          h, *cs = *cols
          tr [th(h)] + cs.map {|s| td(s) }
        end
      end
      table_end
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

    def compile_inline(s)
      @compiler.text(s)
    end

    def inline_chapref(id)
      @chapter.env.chapter_index.display_string(id)
    rescue KeyError
      error "unknown chapter: #{id}"
      nofunc_text("[UnknownChapter:#{id}]")
    end

    def inline_chap(id)
      @chapter.env.chapter_index.number(id)
    rescue KeyError
      error "unknown chapter: #{id}"
      nofunc_text("[UnknownChapter:#{id}]")
    end

    def inline_title(id)
      @chapter.env.chapter_index.title(id)
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

    def inline_ruby(arg)
      base, *ruby = *arg.scan(/(?:(?:(?:\\\\)*\\,)|[^,\\]+)+/)
      base = base.gsub(/\\,/, ",") if base
      ruby = ruby.join(",").gsub(/\\,/, ",") if ruby
      compile_ruby(base, ruby)
    end

    def inline_kw(arg)
      word, alt = *arg.split(',', 2)
      compile_kw(word, alt)
    end

    def inline_href(arg)
      url, label = *arg.scan(/(?:(?:(?:\\\\)*\\,)|[^,\\]+)+/).map(&:lstrip)
      url = url.gsub(/\\,/, ",").strip
      label = label.gsub(/\\,/, ",").strip if label
      compile_href(url, label)
    end

    def text(str)
      str
    end

    def bibpaper(lines, id, caption)
      bibpaper_header id, caption
      unless lines.empty?
        puts ""
        bibpaper_bibpaper id, caption, lines
      end
      puts ""
    end

    def inline_hd(id)
      m = /\A(\w+)\|(.+)/.match(id)
      chapter = @book.chapters.detect{|chap| chap.id == m[1]} if m && m[1]
      return inline_hd_chap(chapter, m[2]) if chapter
      return inline_hd_chap(@chapter, id)
    end

    def raw(str)
      if matched = str.match(/\|(.*?)\|(.*)/)
        builders = matched[1].split(/,/).map{|i| i.gsub(/\s/, '') }
        c = self.class.to_s.gsub(/ReVIEW::/, '').gsub(/Builder/, '').downcase
        if builders.include?(c)
          print matched[2].gsub("\\n", "\n")
        else
          ""
        end
      else
        print str.gsub("\\n", "\n")
      end
    end

    def find_pathes(id)
      if ReVIEW.book.param["subdirmode"]
        re = /\A#{id}(?i:#{@chapter.name.join('|')})\z/x
        entries().select {|ent| re =~ ent }\
          .sort_by {|ent| @book.image_types.index(File.extname(ent).downcase) }\
          .map {|ent| "#{@book.basedir}/#{@chapter.name}/#{ent}" }
      elsif ReVIEW.book.param["singledirmode"]
        re = /\A#{id}(?i:#{@chapter.name.join('|')})\z/x
        entries().select {|ent| re =~ ent }\
          .sort_by {|ent| @book.image_types.index(File.extname(ent).downcase) }\
          .map {|ent| "#{@book.basedir}/#{ent}" }
      else
        re = /\A#{@chapter.name}-#{id}(?i:#{@book.image_types.join('|')})\z/x
        entries().select {|ent| re =~ ent }\
          .sort_by {|ent| @book.image_types.index(File.extname(ent).downcase) }\
          .map {|ent| "#{@book.basedir}/#{ent}" }
      end
    end

    def entries
      if ReVIEW.book.param["subdirmode"]
        @entries ||= Dir.entries(File.join(@book.basedir + @book.image_dir, @chapter.name))
      else
        @entries ||= Dir.entries(@book.basedir + @book.image_dir)
      end
    rescue Errno::ENOENT
    @entries = []
    end

    def warn(msg)
      $stderr.puts "#{@location}: warning: #{msg}"
    end

    def error(msg)
      raise ApplicationError, "#{@location}: error: #{msg}"
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
      if ReVIEW.book.param["secnolevel"] > 0 && !chapter.number.nil? && !chapter.number.to_s.empty?
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
      dir = @book.basedir + @book.image_dir
      file = "#{@chapter.name}-#{id}.#{image_ext}"
      if ReVIEW.book.param["subdirmode"]
        dir = File.join(dir, @chapter.name)
        file = "#{id}.#{image_ext}"
      elsif ReVIEW.book.param["singledirmode"]
        file = "#{id}.#{image_ext}"
      end
      file_path = File.join(dir, file)

      line = CGI.unescapeHTML(lines.join("\n"))
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

      image(lines, id, caption)
    end

    def image_ext
      raise NotImplementedError
    end

    def inline_include(file_name)
      compile_inline convert_inencoding(File.open(file_name).read,
                                        ReVIEW.book.param["inencoding"])
    end

    def include(file_name)
      File.foreach(file_name) do |line|
        paragraph([convert_inencoding(line, ReVIEW.book.param["inencoding"])])
      end
    end

    def ul_item_begin(lines)
      ul_item(lines)
    end

    def ul_item_end
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
