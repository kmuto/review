# encoding: utf-8
#
# Copyright (c) 2010-2014 Kenshi Muto and Masayoshi Takahashi
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
    @buildlogtxt = "build-log.txt"
  end

  def log(s)
    puts s unless @params["debug"].nil?
  end

  def load_yaml(yamlfile)
    @params = ReVIEW::Configure.values.merge(YAML.load_file(yamlfile)) # FIXME:設定がRe:VIEW側とepubmaker/producer.rb側の2つに分かれて面倒
    @epub = Producer.new(@params)
    @epub.load(yamlfile)
    @params = @epub.params
  end

  def produce(yamlfile, bookname=nil)
    load_yaml(yamlfile)
    I18n.setup(@params["language"])
    bookname = @params["bookname"] if bookname.nil?
    booktmpname = "#{bookname}-epub"

    log("Loaded yaml file (#{yamlfile}). I will produce #{bookname}.epub.")

    File.unlink("#{bookname}.epub") if File.exist?("#{bookname}.epub")
    FileUtils.rm_rf(booktmpname) if @params["debug"] && File.exist?(booktmpname)

    basetmpdir = Dir.mktmpdir("#{bookname}-", Dir.pwd)
    begin
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

      if !@params["verify_target_images"].nil?
        verify_target_images(basetmpdir)
        copy_images(@params["imagedir"], basetmpdir)
      else
        copy_images(@params["imagedir"], "#{basetmpdir}/images")
      end

      copy_resources("covers", "#{basetmpdir}/images")
      copy_resources("adv", "#{basetmpdir}/images")
      copy_resources(@params["fontdir"], "#{basetmpdir}/fonts", @params["font_ext"])

      log("Call hook_aftercopyimage. (#{@params["hook_aftercopyimage"]})")
      call_hook(@params["hook_aftercopyimage"], basetmpdir)

      @epub.import_imageinfo("#{basetmpdir}/images", basetmpdir)
      @epub.import_imageinfo("#{basetmpdir}/fonts", basetmpdir, @params["font_ext"])

      epubtmpdir = @params["debug"].nil? ? nil : "#{Dir.pwd}/#{booktmpname}"
      Dir.mkdir(booktmpname) unless @params["debug"].nil?
      log("Call ePUB producer.")
      @epub.produce("#{bookname}.epub", basetmpdir, epubtmpdir)
      log("Finished.")
    ensure
      FileUtils.remove_entry_secure basetmpdir if @params["debug"].nil?
    end
  end

  def call_hook(filename, *params)
    if !filename.nil? && File.exist?(filename) && FileTest.executable?(filename)
      if ENV["REVIEW_SAFE_MODE"].to_i & 1 > 0
        warn "hook is prohibited in safe mode. ignored."
      else
        system(filename, *params)
      end
    end
  end

  def verify_target_images(basetmpdir)
    @epub.contents.each do |content|
      if content.media == "application/xhtml+xml"

        File.open("#{basetmpdir}/#{content.file}") do |f|
          Document.new(File.new(f)).each_element("//img") do |e|
            @params["force_include_images"].push(e.attributes["src"])
            if e.attributes["src"] =~ /svg\Z/i
              content.properties.push("svg")
            end
          end
        end
      elsif content.media == "text/css"
        File.open("#{basetmpdir}/#{content.file}") do |f|
          f.each_line do |l|
            l.scan(/url\((.+?)\)/) do |m|
              @params["force_include_images"].push($1.strip)
            end
          end
        end
      end
    end
    @params["force_include_images"] = @params["force_include_images"].sort.uniq
  end

  def copy_images(resdir, destdir, allow_exts=nil)
    return nil unless File.exist?(resdir)
    allow_exts = @params["image_ext"] if allow_exts.nil?
    FileUtils.mkdir_p(destdir) unless FileTest.directory?(destdir)
    if !@params["verify_target_images"].nil?
      @params["force_include_images"].each do |file|
        unless File.exist?(file)
          warn "#{file} is not found, skip." if file !~ /\Ahttp[s]?:/
          next
        end
        basedir = File.dirname(file)
        FileUtils.mkdir_p("#{destdir}/#{basedir}") unless FileTest.directory?("#{destdir}/#{basedir}")
        log("Copy #{file} to the temporary directory.")
        FileUtils.cp(file, "#{destdir}/#{basedir}")
      end
    else
      recursive_copy_files(resdir, destdir, allow_exts)
    end
  end

  def copy_resources(resdir, destdir, allow_exts=nil)
    return nil unless File.exist?(resdir)
    allow_exts = @params["image_ext"] if allow_exts.nil?
    FileUtils.mkdir_p(destdir) unless FileTest.directory?(destdir)
    recursive_copy_files(resdir, destdir, allow_exts)
  end

  def recursive_copy_files(resdir, destdir, allow_exts)
    Dir.open(resdir) do |dir|
      dir.each do |fname|
        next if fname =~ /\A\./
        if FileTest.directory?("#{resdir}/#{fname}")
          recursive_copy_files("#{resdir}/#{fname}", "#{destdir}/#{fname}", allow_exts)
        else
          if fname =~ /\.(#{allow_exts.join("|")})\Z/i
            Dir.mkdir(destdir) unless File.exist?(destdir)
            log("Copy #{resdir}/#{fname} to the temporary directory.")
            FileUtils.cp("#{resdir}/#{fname}", destdir)
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
    # toccount = 2  ## not used

    basedir = Dir.pwd
    base_path = Pathname.new(basedir)
    book = ReVIEW::Book.load(basedir)
    book.load_config(yamlfile)
    book.parts.each do |part|
      htmlfile = nil
      if part.name.present?
        if part.file?
          build_chap(part, base_path, basetmpdir, yamlfile, true)
        else
          htmlfile = "part_#{part.number}.#{@params["htmlext"]}"
          build_part(part, basetmpdir, htmlfile)
          title = ReVIEW::I18n.t("part", part.number)
          title += ReVIEW::I18n.t("chapter_postfix") + part.name.strip if part.name.strip.present?
          write_tochtmltxt(basetmpdir, "0\t#{htmlfile}\t#{title}\tchaptype=part")
          write_buildlogtxt(basetmpdir, htmlfile, "")
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

    chaptype = "body"
    if !ispart.nil?
      chaptype = "part"
    elsif chap.on_PREDEF?
      chaptype = "pre"
    elsif chap.on_APPENDIX?
      chaptype = "post"
    end

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
      elsif chap.on_APPENDIX?
        @postcount += 1
        id = sprintf("post%02d", @postcount)
      else
        @bodycount += 1
        id = sprintf("chap%02d", @bodycount)
      end
    end

    htmlfile = "#{id}.#{@params["htmlext"]}"
    write_buildlogtxt(basetmpdir, htmlfile, filename)
    log("Create #{htmlfile} from #{filename}.")

    level = @params["secnolevel"]

# TODO: It would be nice if we can modify level in PART, PREDEF, or POSTDEF.
#        But we have to care about section number reference (@<hd>) also.
#
#    if !ispart.nil?
#      level = @params["part_secnolevel"]
#    else
#      level = @params["pre_secnolevel"] if chap.on_PREDEF?
#      level = @params["post_secnolevel"] if chap.on_APPENDIX?
#    end

    stylesheet = ""
    if @params["stylesheet"].size > 0
      stylesheet = "--stylesheet=#{@params["stylesheet"].join(",")}"
    end

    ENV["REVIEWFNAME"] = filename
    system("#{ReVIEW::MakerHelper.bindir}/review-compile --yaml=#{yamlfile} --target=html --level=#{level} --htmlversion=#{@params["htmlversion"]} --epubversion=#{@params["epubversion"]} #{stylesheet} #{@params["params"]} #{filename} > \"#{basetmpdir}/#{htmlfile}\"")

    write_info_body(basetmpdir, id, htmlfile, ispart, chaptype)
  end

  def detect_properties(path)
    properties = []
    File.open(path) do |f|
      doc = REXML::Document.new(f)
      if REXML::XPath.first(doc, "//m:math", {'m' => 'http://www.w3.org/1998/Math/MathML'})
        properties<< "mathml"
      end
      if REXML::XPath.first(doc, "//s:svg", {'s' => 'http://www.w3.org/2000/svg'})
        properties<< "svg"
      end
    end
    properties
  end

  def write_info_body(basetmpdir, id, filename, ispart=nil, chaptype=nil)
    headlines = []
    # FIXME:nonumを修正する必要あり
    path = File.join(basetmpdir, filename)
    Document.parse_stream(File.new(path), ReVIEWHeaderListener.new(headlines))
    properties = detect_properties(path)
    prop_str = ""
    if properties.present?
      prop_str = ",properties="+properties.join(" ")
    end
    first = true
    headlines.each do |headline|
      headline["level"] = 0 if !ispart.nil? && headline["level"] == 1
      if first.nil?
        write_tochtmltxt(basetmpdir, "#{headline["level"]}\t#{filename}##{headline["id"]}\t#{headline["title"]}\tchaptype=#{chaptype}")
      else
        write_tochtmltxt(basetmpdir, "#{headline["level"]}\t#{filename}\t#{headline["title"]}\tforce_include=true,chaptype=#{chaptype}#{prop_str}")
        first = nil
      end
    end
  end

  def push_contents(basetmpdir)
    File.open("#{basetmpdir}/#{@tochtmltxt}") do |f|
      f.each_line do |l|
        force_include = nil
        customid = nil
        chaptype = nil
        properties = nil
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
            when "chaptype"
              chaptype = v
            when "properties"
              properties = v
            end
          end
        end
        next if level.to_i > @params["toclevel"] && force_include.nil?
        log("Push #{file} to ePUB contents.")

        hash = {"file" => file, "level" => level.to_i, "title" => title, "chaptype" => chaptype}
        if customid.present?
          hash["id"] = customid
        end
        if properties.present?
          hash["properties"] = properties.split(" ")
        end
        @epub.contents.push(Content.new(hash))
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
      if @params["titlefile"].nil?
        build_titlepage(basetmpdir, "titlepage.#{@params["htmlext"]}")
      else
        FileUtils.cp(@params["titlefile"], "#{basetmpdir}/titlepage.#{@params["htmlext"]}")
      end
      write_tochtmltxt(basetmpdir, "1\ttitlepage.#{@params["htmlext"]}\t#{@epub.res.v("titlepagetitle")}\tchaptype=pre")
    end

    if !@params["originaltitlefile"].nil? && File.exist?(@params["originaltitlefile"])
      FileUtils.cp(@params["originaltitlefile"], "#{basetmpdir}/#{File.basename(@params["originaltitlefile"])}")
      write_tochtmltxt(basetmpdir, "1\t#{File.basename(@params["originaltitlefile"])}\t#{@epub.res.v("originaltitle")}\tchaptype=pre")
    end

    if !@params["creditfile"].nil? && File.exist?(@params["creditfile"])
      FileUtils.cp(@params["creditfile"], "#{basetmpdir}/#{File.basename(@params["creditfile"])}")
      write_tochtmltxt(basetmpdir, "1\t#{File.basename(@params["creditfile"])}\t#{@epub.res.v("credittitle")}\tchaptype=pre")
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
      write_tochtmltxt(basetmpdir, "1\t#{File.basename(@params["profile"])}\t#{@epub.res.v("profiletitle")}\tchaptype=post")
    end

    if @params["advfile"]
      FileUtils.cp(@params["advfile"], "#{basetmpdir}/#{File.basename(@params["advfile"])}")
      write_tochtmltxt(basetmpdir, "1\t#{File.basename(@params["advfile"])}\t#{@epub.res.v("advtitle")}\tchaptype=post")
    end

    if @params["colophon"]
      if @params["colophon"].instance_of?(String) # FIXME:このやり方はやめる？
        FileUtils.cp(@params["colophon"], "#{basetmpdir}/colophon.#{@params["htmlext"]}")
      else
        File.open("#{basetmpdir}/colophon.#{@params["htmlext"]}", "w") {|f| @epub.colophon(f) }
      end
      write_tochtmltxt(basetmpdir, "1\tcolophon.#{@params["htmlext"]}\t#{@epub.res.v("colophontitle")}\tchaptype=post")
    end

    if @params["backcover"]
      FileUtils.cp(@params["backcover"], "#{basetmpdir}/#{File.basename(@params["backcover"])}")
      write_tochtmltxt(basetmpdir, "1\t#{File.basename(@params["backcover"])}\t#{@epub.res.v("backcovertitle")}\tchaptype=post")
    end
  end

  def write_tochtmltxt(basetmpdir, s)
    File.open("#{basetmpdir}/#{@tochtmltxt}", "a") do |f|
      f.puts s
    end
  end

  def write_buildlogtxt(basetmpdir, htmlfile, reviewfile)
    File.open("#{basetmpdir}/#{@buildlogtxt}", "a") do |f|
      f.puts "#{htmlfile},#{reviewfile}"
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
  <meta content='Re:VIEW' name='generator'/>
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
