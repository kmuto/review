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

      call_hook(@params["hook_afterfrontmatter"], basetmpdir)

      build_body(basetmpdir, yamlfile)
      call_hook(@params["hook_prebody"], basetmpdir)

      push_body(basetmpdir)

      call_hook(@params["hook_afterbody"], basetmpdir)
      
      copy_backmatter(basetmpdir)

      call_hook(@params["hook_afterbackmatter"], basetmpdir)

      copy_images(@params["imagedir"], "#{basetmpdir}/images")
      copy_images("covers", "#{basetmpdir}/images")
      copy_images("adv", "#{basetmpdir}/images")
      @epub.import_imageinfo("#{basetmpdir}/images", basetmpdir)

      epubtmpdir = @params["debug"].nil? ? nil : "#{Dir.pwd}/#{bookname}"
      Dir.mkdir(bookname) unless @params["debug"].nil?
      @epub.produce("#{bookname}.epub", basetmpdir, epubtmpdir)

    end
  end

  def call_hook(filename, *params)
    if !filename.nil? && File.exist?(filename) && FileTest.executable?(filename)
    fork {
      exec(filename, *params)
    }
    Process.waitall
    end
  end

  def copy_images(imagedir, destdir)
    return nil unless File.exist?(imagedir)
    FileUtils.mkdir_p(destdir) unless FileTest.directory?(destdir)
    recursive_copy_images(imagedir, destdir)
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
      htmlfile = nil
      if part.name.present?
        if part.file?
          build_chap(part, base_path, basetmpdir, yamlfile)
        else
          htmlfile = "part_#{part.number}.#{@params["htmlext"]}"
          build_part(part, basetmpdir, htmlfile)
          title = ReVIEW::I18n.t("part", part.number)
          title += ReVIEW::I18n.t("chapter_postfix") + part.name.strip if part.name.strip.present?
          write_info_builtpart(basetmpdir, htmlfile, title)
        end
      end

      part.chapters.each do |chap|
        build_chap(chap, base_path, basetmpdir, yamlfile)
      end
      
    end
  end

  def build_part(part, basetmpdir, htmlfile)
    File.open("#{basetmpdir}/#{htmlfile}", "w") do |f|
      f.puts header(CGI.escapeHTML(@params["booktitle"]))
      f.puts <<EOT
<div class="part">
<h1 class="part-number">#{ReVIEW::I18n.t("part", part.number)}</h1>
EOT
      if part.name.strip.present?
        f.puts <<EOT
<h2 class="part-title">#{part.name.strip}</h2>
EOT
      end
      
      f.puts <<EOT
</div>
EOT
      f.puts footer
    end
  end

  def build_chap(chap, base_path, basetmpdir, yamlfile)
    filename = ""
    if chap.instance_of?(ReVIEW::Book::Part)
      filename = chap.path
    else
      filename = Pathname.new(chap.path).relative_path_from(base_path).to_s
    end
    id = filename.sub(/\.re\Z/, "")
    htmlfile = "#{id}.#{@params["htmlext"]}"

    level = @params["secnolevel"]
    
    if chap.instance_of?(ReVIEW::Book::Part)
      level = @params["part_secnolevel"]
    else
      level = @params["pre_secnolevel"] if chap.on_PREDEF?
      level = @params["post_secnolevel"] if chap.on_POSTDEF?
    end

    fork {
      STDOUT.reopen("#{basetmpdir}/#{htmlfile}")
      exec("review-compile --target=html --level=#{level} --htmlversion=#{@params["htmlversion"]} --epubversion=#{@params["epubversion"]} #{@params["params"]} #{filename}")
    }
    Process.waitall

    write_info_body(basetmpdir, id, htmlfile, chap.instance_of?(ReVIEW::Book::Part))
  end

  def write_info_builtpart(basetmpdir, filename, title)
    File.open("#{basetmpdir}/toc-html.txt", "a") do |f|
      f.puts "0\t#{filename}\t#{title}"
    end
  end

  def write_info_body(basetmpdir, id, filename, part = nil)
    headlines = []
    # FIXME:nonumを修正する必要あり
    # 最初にtoclevel以下だとリストから抜ける?
    Document.parse_stream(File.new("#{basetmpdir}/#{filename}"), ReVIEWHeaderListener.new(headlines))
    File.open("#{basetmpdir}/toc-html.txt", "a") do |f|
      first = true
      headlines.each do |headline|
        headline["level"] = 0 if !part.nil? && headline["level"] == 1
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
    FileUtils.cp(@params["cover"], "#{basetmpdir}/#{File.basename(@params["cover"])}") if !@params["cover"].nil? && File.exist?(@params["cover"])

    if @params["titlepage"]
      if @params["titlepagefile"].nil?
        build_titlepage(basetmpdir, "_titlepage.#{@params["htmlext"]}")
        @epub.contents.push(Content.new("file" => "_titlepage.#{@params["htmlext"]}", "title" => @epub.res.v("titlepagetitle")))
      else
        FileUtils.cp(@params["titlepagefile"], "#{basetmpdir}/#{File.basename(@params["titlepagefile"])}")
        @epub.contents.push(Content.new("id" => "_titlepage", "file" => File.basename(@params["titlepagefile"]), "title" => @epub.res.v("titlepagetitle")))
      end
    end
  end

  def build_titlepage(basetmpdir, htmlfile)
    File.open("#{basetmpdir}/#{htmlfile}", "w") do |f|
      f.puts header(CGI.escapeHTML(@params["booktitle"]))
      f.puts <<EOT
<div class="titlepage">
<h1 class="tp-title">#{CGI.escapeHTML(@params["booktitle"])}</h1>
EOT

      if @params["aut"]
        f.puts <<EOT
<h2 class="tp-author">#{@params["aut"].join(", ")}</h2>
EOT
      end
      if @params["prt"]
        f.puts <<EOT
<h3 class="tp-publisher">#{@params["prt"].join(", ")}</h3>
EOT
      end

      f.puts <<EOT
</div>
EOT
      f.puts footer
    end
  end

  def copy_backmatter(basetmpdir)
    if @params["profile"]
      FileUtils.cp(@params["profile"], "#{basetmpdir}/#{File.basename(@params["profile"])}")
      @epub.contents.push(Content.new("file" => File.basename(@params["profile"]), "title" => @epub.res.v("profile")))
    end

    if @params["advfile"]
      FileUtils.cp(@params["advfile"], "#{basetmpdir}/#{File.basename(@params["advfile"])}")
      @epub.contents.push(Content.new("file" => File.basename(@params["advfile"]), "title" => @epub.res.v("advtitle")))
    end

    if @params["colophon"]
      if @params["colophon"].instance_of?(String)
        FileUtils.cp(@params["colophon"], "#{basetmpdir}/colophon.#{@params["htmlext"]}")
      else
        File.open("#{basetmpdir}/colophon.#{@params["htmlext"]}", "w") {|f| @epub.colophon(f) }
      end
      @epub.contents.push(Content.new("id" => "colophon", "file" => "colophon.#{@params["htmlext"]}", "title" => @epub.res.v("colophontitle")))
    end
  end

  def header(title)
    # titleはすでにエスケープ済みと想定
    s = <<EOT
<?xml version="1.0" encoding="UTF-8"?>
EOT
    if @params["htmlversion"] == 5
      s << <<EOT
<!DOCTYPE html>
<html xml:lang='ja' xmlns:ops='http://www.idpf.org/2007/ops' xmlns='http://www.w3.org/1999/xhtml'>
<head>
  <meta charset="UTF-8" />
EOT
    else
      s << <<EOT
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
<html xml:lang='ja' xmlns:ops='http://www.idpf.org/2007/ops' xmlns='http://www.w3.org/1999/xhtml'>
<head>
  <meta http-equiv='Content-Type' content='text/html;charset=UTF-8' />
  <meta http-equiv='Content-Style-Type' content='text/css' />
EOT
    end
    if @params["stylesheet"].size > 0
      @params["stylesheet"].each do |sfile|
        s << <<EOT
  <link rel='stylesheet' type='text/css' href='#{sfile}' />
EOT
      end
    end
    s << <<EOT
  <meta content='ReVIEW' name='generator'/>
  <title>#{title}</title>
</head>
<body>
EOT
  end

  def footer
    <<EOT
</body>
</html>
EOT
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
