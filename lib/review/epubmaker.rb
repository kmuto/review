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

module ReVIEW
  class EPUBMaker
  include ::EPUBMaker
  include REXML

  def initialize
    @epub = nil
    @tochtmltxt = "toc-html.txt"
  end

  def log(s)
    puts s unless @params["debug"].nil?
  end

  def load_yaml(yamlfile)
    @params = ReVIEW::Configure.values.merge(YAML.load_file(yamlfile)) # FIXME:設定がReVIEW側とepubmaker/producer.rb側の2つに分かれて面倒
    @epub = Producer.new(@params)
    @epub.load(yamlfile)
    @params = @epub.params
  end

  def produce(yamlfile, bookname=nil)
    load_yaml(yamlfile)
    bookname = @params["bookname"] if bookname.nil?
    log("Loaded yaml file (#{yamlfile}). I will produce #{bookname}.epub.")

    File.unlink("#{bookname}.epub") if File.exist?("#{bookname}.epub")
    FileUtils.rm_rf(bookname) if @params["debug"] && File.exist?(bookname)
    
    Dir.mktmpdir(bookname, Dir.pwd) do |basetmpdir|
      log("Created first temporary directory as #{basetmpdir}.")

      log("Call hook_beforeprocess. (#{@params["hook_beforeprocess"]})")
      call_hook(@params["hook_beforeprocess"], basetmpdir)

      copy_stylesheet(basetmpdir)

      copy_frontmatter(basetmpdir)
      log("Call hook_afterfrontmatter. (#{@params["hook_afterfrontmatter"]})")
      call_hook(@params["hook_afterfrontmatter"], basetmpdir)

      build_body(basetmpdir, yamlfile)
      log("Call hook_afterbody. (#{@params["hook_afterbody"]})")
      call_hook(@params["hook_afterbody"], basetmpdir)

      copy_backmatter(basetmpdir)
      log("Call hook_afterbackmatter. (#{@params["hook_afterbackmatter"]})")
      call_hook(@params["hook_afterbackmatter"], basetmpdir)

      push_contents(basetmpdir)

      copy_images(@params["imagedir"], "#{basetmpdir}/images")
      copy_images("covers", "#{basetmpdir}/images")
      copy_images("adv", "#{basetmpdir}/images")
      log("Call hook_aftercopyimage. (#{@params["hook_aftercopyimage"]})")
      call_hook(@params["hook_aftercopyimage"], basetmpdir)

      @epub.import_imageinfo("#{basetmpdir}/images", basetmpdir)

      epubtmpdir = @params["debug"].nil? ? nil : "#{Dir.pwd}/#{bookname}"
      Dir.mkdir(bookname) unless @params["debug"].nil?
      log("Call ePUB producer.")
      @epub.produce("#{bookname}.epub", basetmpdir, epubtmpdir)
      log("Finished.")

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
            log("Copy #{imagedir}/#{fname} to the temporary directory.")
            FileUtils.cp("#{imagedir}/#{fname}", destdir)
          end
        end
      end
    end
  end

  def build_body(basetmpdir, yamlfile)
    @precount = 0
    @bodycount = 0
    @postcount = 0

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
          build_chap(part, base_path, basetmpdir, yamlfile, true)
        else
          htmlfile = "part_#{part.number}.#{@params["htmlext"]}"
          build_part(part, basetmpdir, htmlfile)
          title = ReVIEW::I18n.t("part", part.number)
          title += ReVIEW::I18n.t("chapter_postfix") + part.name.strip if part.name.strip.present?
          write_tochtmltxt(basetmpdir, "0\t#{filename}\t#{title}")
        end
      end

      part.chapters.each do |chap|
        build_chap(chap, base_path, basetmpdir, yamlfile, nil)
      end
      
    end
  end

  def build_part(part, basetmpdir, htmlfile)
    log("Create #{htmlfile} from a template.")
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

  def build_chap(chap, base_path, basetmpdir, yamlfile, ispart=nil)
    filename = ""
    if !ispart.nil?
      filename = chap.path
    else
      filename = Pathname.new(chap.path).relative_path_from(base_path).to_s
    end
    id = filename.sub(/\.re\Z/, "")

    if @params["rename_for_legacy"] && ispart.nil?
      if chap.on_PREDEF?
        @precount += 1
        id = sprintf("pre%02d", @precount)
      elsif chap.on_POSTDEF?
        @postcount += 1
        id = sprintf("post%02d", @postcount)
      else
        @bodycount += 1
        id = sprintf("chap%02d", @bodycount)
      end
    end

    htmlfile = "#{id}.#{@params["htmlext"]}"
    log("Create #{htmlfile} from #{filename}.")

    level = @params["secnolevel"]
    
    if !ispart.nil?
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

    write_info_body(basetmpdir, id, htmlfile, ispart)
  end

  def write_info_body(basetmpdir, id, filename, ispart=nil)
    headlines = []
    # FIXME:nonumを修正する必要あり
    Document.parse_stream(File.new("#{basetmpdir}/#{filename}"), ReVIEWHeaderListener.new(headlines))
    first = true
    headlines.each do |headline|
      headline["level"] = 0 if !ispart.nil? && headline["level"] == 1
      if first.nil?
        write_tochtmltxt(basetmpdir, "#{headline["level"]}\t#{filename}##{headline["id"]}\t#{headline["title"]}")
      else
        write_tochtmltxt(basetmpdir, "#{headline["level"]}\t#{filename}\t#{headline["title"]}\tforce_include=true")
        first = nil
      end
    end
  end

  def push_contents(basetmpdir)
    File.open("#{basetmpdir}/#{@tochtmltxt}") do |f|
      f.each_line do |l|
        force_include = nil
        customid = nil
        level, file, title, custom = l.chomp.split("\t")
        unless custom.nil?
          # custom setting
          vars = custom.split(/,\s*/)
          vars.each do |var|
            k, v = var.split("=")
            case k
            when "id"
              customid = v
            when "force_include"
              force_include = true
            end
          end
        end
        next if level.to_i > @params["toclevel"] && force_include.nil?
        log("Push #{file} to ePUB contents.")

        if customid.nil?
          @epub.contents.push(Content.new("file" => file, "level" => level.to_i, "title" => title))
        else
          @epub.contents.push(Content.new("id" => customid, "file" => file, "level" => level.to_i, "title" => title))
        end
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
        build_titlepage(basetmpdir, "titlepage.#{@params["htmlext"]}")
      else
        FileUtils.cp(@params["titlepagefile"], "titlepage.#{@params["htmlext"]}")
      end
      write_tochtmltxt(basetmpdir, "1\ttitlepage.#{@params["htmlext"]}\t#{@epub.res.v("titlepagetitle")}")
    end

    if !@params["originaltitlefile"].nil? && File.exist?(@params["originaltitlefile"])
      FileUtils.cp(@params["originaltitlefile"], "#{basetmpdir}/#{File.basename(@params["originaltitlefile"])}")
      write_tochtmltxt(basetmpdir, "1\t#{File.basename(@params["originaltitlefile"])}\t#{@epub.res.v("originaltitle")}")
    end

    if !@params["creditfile"].nil? && File.exist?(@params["creditfile"])
      FileUtils.cp(@params["creditfile"], "#{basetmpdir}/#{File.basename(@params["creditfile"])}")
      write_tochtmltxt(basetmpdir, "1\t#{File.basename(@params["creditfile"])}\t#{@epub.res.v("credit")}")
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
      write_tochtmltxt(basetmpdir, "1\t_#{File.basename(@params["profile"])}\t#{@epub.res.v("profile")}")
    end

    if @params["advfile"]
      FileUtils.cp(@params["advfile"], "#{basetmpdir}/#{File.basename(@params["advfile"])}")
      write_tochtmltxt(basetmpdir, "1\t_#{File.basename(@params["advfile"])}\t#{@epub.res.v("advtitle")}")
    end

    if @params["colophon"]
      if @params["colophon"].instance_of?(String) # FIXME:このやり方はやめる？
        FileUtils.cp(@params["colophon"], "#{basetmpdir}/colophon.#{@params["htmlext"]}")
      else
        File.open("#{basetmpdir}/colophon.#{@params["htmlext"]}", "w") {|f| @epub.colophon(f) }
      end
      write_tochtmltxt(basetmpdir, "1\tcolophon.#{@params["htmlext"]}\t#{@epub.res.v("colophontitle")}")
    end
  end

  def write_tochtmltxt(basetmpdir, s)
    File.open("#{basetmpdir}/#{@tochtmltxt}", "a") do |f|
      f.puts s
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
        @content << text.gsub("\t", "　") # FIXME:区切り文字
      end
    end
  end
end
end
