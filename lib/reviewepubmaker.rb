# encoding: utf-8
#
# Copyright (c) 2010-2013 Kenshi Muto and Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
#
require 'review'
require 'rexml/document'
require 'rexml/streamlistener'
require 'epubmaker'

class ReVIEWEPUBMaker
  include EPUBMaker
  include REXML

  def initialize
    @epub = nil
  end

  def load_yaml(yamlfile)
    @params = ReVIEW::Configure.values.merge(YAML.load_file(yamlfile))
    @epub = Producer.new(@params)
    @epub.load(yamlfile)
    @params = @epub.params
  end

  def produce(yamlfile, bookname = nil)
    load_yaml(yamlfile)
    bookname = @params["bookname"] if bookname.nil?

    File.unlink("#{bookname}.epub") if File.exist?("#{bookname}.epub")
    FileUtils.rm_rf(bookname) if @params["debug"] && File.exist?(bookname)
    
    Dir.mktmpdir(bookname, Dir.pwd) do |basetmpdir|

      copy_stylesheet(basetmpdir)
      copy_frontmatter(basetmpdir)

      build_body(basetmpdir, yamlfile)
      # FIXME: pre-hook

      push_body(basetmpdir)
      
      copy_backmatter(basetmpdir)

      copy_images(@params["imagedir"], "#{basetmpdir}/images")
      copy_images("covers", "#{basetmpdir}/images") # FIXME:イレギュラー?
      @epub.import_imageinfo("#{basetmpdir}/images", basetmpdir)

      # FIXME: post-hook

      epubtmpdir = @params["debug"].nil? ? nil : "#{Dir.pwd}/#{bookname}"
      Dir.mkdir(bookname) unless @params["debug"].nil?
      @epub.produce("#{bookname}.epub", basetmpdir, epubtmpdir)

    end
  end

  def copy_images(imagedir, destdir)
    return nil unless File.exist?(imagedir)
    FileUtils.mkdir_p(destdir) unless FileTest.directory?(destdir)
    recursive_copy_images(imagedir, destdir) # FIXME:cp_rでいい?
  end

  def recursive_copy_images(imagedir, destdir)
    Dir.open(imagedir) do |dir|
      dir.each do |fname|
        next if fname =~ /\A\./
        if FileTest.directory?("#{imagedir}/#{fname}")
          recursive_copy_images("#{imagedir}/#{fname}", "#{destdir}/#{fname}")
        else
          if fname =~ /\.(png|gif|jpg|jpeg|svg)\Z/i
            Dir.mkdir(destdir) unless File.exist?(destdir)
            FileUtils.cp("#{imagedir}/#{fname}", destdir)
          end
        end
      end
    end
  end

  def build_body(basetmpdir, yamlfile)
    @manifeststr = ""
    @ncxstr = ""
    @tocdesc = Array.new
    toccount = 2

    basedir = Dir.pwd
    base_path = Pathname.new(basedir)
    ReVIEW::Book.load(basedir).parts.each do |part|
      if part.name.present?
        if part.file?
          # FIXME
        else
          # FIXME
        end
      end

      part.chapters.each do |chap|
        build_chap(chap, base_path, basetmpdir, yamlfile)
      end
      
    end
  end

  def build_chap(chap, base_path, basetmpdir, yamlfile)
    filename = Pathname.new(chap.path).relative_path_from(base_path).to_s
    id = filename.sub(/\.re\Z/, "")
    htmlfile = "#{id}.#{@params["htmlext"]}"
    # FIXME: essential_files check

    fork {
      STDOUT.reopen("#{basetmpdir}/#{htmlfile}")
      level = @params["secnolevel"]
      level = @params["pre_secnolevel"] if chap.on_PREDEF?
      level = @params["post_secnolevel"] if chap.on_POSTDEF?
      
      exec("review-compile --target=html --level=#{level} --htmlversion=#{@params["htmlversion"]} --epubversion=#{@params["epubversion"]} #{@params["params"]} #{filename}")
    }
    Process.waitall

    parse_body(basetmpdir, id, htmlfile)
  end

  def parse_body(basetmpdir, id, filename)
    headlines = []
    # FIXME:part
    # FIXME:nonumを修正する必要あり
    # 最初にtoclevel以下だとリストから抜ける?
    Document.parse_stream(File.new("#{basetmpdir}/#{filename}"), ReVIEWHeaderListener.new(headlines))
    File.open("#{basetmpdir}/toc-html.txt", "a") do |f|
      first = true
      headlines.each do |headline|
        if first.nil?
          f.puts "#{headline["level"]}\t#{filename}##{headline["id"]}\t#{headline["title"]}"
        else
          f.puts "#{headline["level"]}\t#{filename}\t#{headline["title"]}"
          first = nil
        end
      end
    end
  end

  def push_body(basetmpdir)
    File.open("#{basetmpdir}/toc-html.txt") do |f|
      f.each_line do |l|
        level, file, title = l.chomp.split("\t", 3)
        next if level.to_i > @params["toclevel"]
        @epub.contents.push(Content.new("file" => file, "level" => level.to_i, "title" => title))
      end
    end
  end

  def copy_stylesheet(basetmpdir)
    if @params["stylesheet"].size > 0
      @params["stylesheet"].each do |sfile|
        FileUtils.cp(sfile, basetmpdir)
        @epub.contents.push(Content.new("file" => sfile))
      end
    end
  end

  def copy_frontmatter(basetmpdir)
    FileUtils.cp(@params["cover"], "#{basetmpdir}/#{@params["cover"]}") if !@params["cover"].nil? && File.exist?(@params["cover"])
    # FIXME:大扉
    # FIXME:原書大扉
    # FIXME:クレジット

#    if @params["titlepage"] # FIXME
#      FileUtils.cp(@params["titlepage"], "#{basetmpdir}/#{@params["titlepage"]}")
#      @epub.contents.push(Content.new("id" => "title", "file" => @params["titlepage"], "title" => @epub.res.v("titlepagetitle")))
#    end
  end

  def copy_backmatter(basetmpdir)
    # FIXME:著者紹介

    # FIXME: backcover
    if @params["colophon"]
      if @params["colophon"].instance_of?(String)
        FileUtils.cp(@params["colophon"], "#{basetmpdir}/colophon.#{@params["htmlext"]}")
      else
        File.open("#{basetmpdir}/colophon.#{@params["htmlext"]}", "w") {|f| @epub.colophon(f) }
      end
      @epub.contents.push(Content.new("id" => "colophon", "file" => "colophon.#{@params["htmlext"]}", "title" => @epub.res.v("colophontitle")))
    end
  end

  class ReVIEWHeaderListener
    include REXML::StreamListener
    def initialize(headlines)
      @level = nil
      @content = ""
      @headlines = headlines
    end
    
    def tag_start(name, attrs)
      if name =~ /\Ah(\d+)/
        unless @level.nil?
          raise "#{name}, #{attrs}"
        end
        @level = $1.to_i
        @id = attrs["id"] if !attrs["id"].nil?
      elsif !@level.nil?
        if name == "img" && !attrs["alt"].nil?
          @content << attrs["alt"]
        elsif name == "a" && !attrs["id"].nil?
          @id = attrs["id"]
        end
      end
    end
    
    def tag_end(name)
      if name =~ /\Ah\d+/
        @headlines.push({"level" => @level, "id" => @id, "title" => @content}) unless @id.nil?
        @content = ""
        @level = nil
        @id = nil
      end
    end
    
    def text(text)
      unless @level.nil?
        @content << text
      end
    end
  end
end
