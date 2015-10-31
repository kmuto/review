# encoding: utf-8
#
# Copyright (c) 2010-2015 Kenshi Muto and Masayoshi Takahashi
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
require 'review/htmltoc'

module ReVIEW
 class EPUBMaker
  include ::EPUBMaker
  include REXML

  def initialize
    @producer = nil
    @htmltoc = nil
    @buildlogtxt = "build-log.txt"
  end

  def log(s)
    puts s if @params["debug"].present?
  end

  def load_yaml(yamlfile)
    @params = ReVIEW::Configure.values.merge(YAML.load_file(yamlfile)) # FIXME:設定がRe:VIEW側とepubmaker/producer.rb側の2つに分かれて面倒
    @producer = Producer.new(@params)
    @producer.load(yamlfile)
    @params = @producer.params
  end

  def produce(yamlfile, bookname=nil)
    load_yaml(yamlfile)
    I18n.setup(@params["language"])
    bookname = @params["bookname"] if bookname.nil?
    booktmpname = "#{bookname}-epub"

    log("Loaded yaml file (#{yamlfile}). I will produce #{bookname}.epub.")

    FileUtils.rm_f("#{bookname}.epub")
    FileUtils.rm_rf(booktmpname) if @params["debug"]

    basetmpdir = Dir.mktmpdir("#{bookname}-", Dir.pwd)
    begin
      log("Created first temporary directory as #{basetmpdir}.")

      call_hook("hook_beforeprocess", basetmpdir)

      @htmltoc = ReVIEW::HTMLToc.new(basetmpdir)
      ## copy all files into basetmpdir
      copy_stylesheet(basetmpdir)

      copy_frontmatter(basetmpdir)
      call_hook("hook_afterfrontmatter", basetmpdir)

      build_body(basetmpdir, yamlfile)
      call_hook("hook_afterbody", basetmpdir)

      copy_backmatter(basetmpdir)
      call_hook("hook_afterbackmatter", basetmpdir)

      ## push contents in basetmpdir into @producer
      push_contents(basetmpdir)

      if @params["epubmaker"]["verify_target_images"].present?
        verify_target_images(basetmpdir)
        copy_images(@params["imagedir"], basetmpdir)
      else
        copy_images(@params["imagedir"], "#{basetmpdir}/images")
      end

      copy_resources("covers", "#{basetmpdir}/images")
      copy_resources("adv", "#{basetmpdir}/images")
      copy_resources(@params["fontdir"], "#{basetmpdir}/fonts", @params["font_ext"])

      call_hook("hook_aftercopyimage", basetmpdir)

      @producer.import_imageinfo("#{basetmpdir}/images", basetmpdir)
      @producer.import_imageinfo("#{basetmpdir}/fonts", basetmpdir, @params["font_ext"])

      epubtmpdir = nil
      if @params["debug"].present?
        epubtmpdir = "#{Dir.pwd}/#{booktmpname}"
        Dir.mkdir(epubtmpdir)
      end
      log("Call ePUB producer.")
      @producer.produce("#{bookname}.epub", basetmpdir, epubtmpdir)
      log("Finished.")
    ensure
      FileUtils.remove_entry_secure basetmpdir if @params["debug"].nil?
    end
  end

  def call_hook(hook_name, *params)
    filename = @params["epubmaker"][hook_name]
    log("Call #{hook_name}. (#{filename})")
    if filename.present? && File.exist?(filename) && FileTest.executable?(filename)
      if ENV["REVIEW_SAFE_MODE"].to_i & 1 > 0
        warn "hook is prohibited in safe mode. ignored."
      else
        system(filename, *params)
      end
    end
  end

  def verify_target_images(basetmpdir)
    @producer.contents.each do |content|
      if content.media == "application/xhtml+xml"

        File.open("#{basetmpdir}/#{content.file}") do |f|
          Document.new(File.new(f)).each_element("//img") do |e|
            @params["epubmaker"]["force_include_images"].push(e.attributes["src"])
            if e.attributes["src"] =~ /svg\Z/i
              content.properties.push("svg")
            end
          end
        end
      elsif content.media == "text/css"
        File.open("#{basetmpdir}/#{content.file}") do |f|
          f.each_line do |l|
            l.scan(/url\((.+?)\)/) do |m|
              @params["epubmaker"]["force_include_images"].push($1.strip)
            end
          end
        end
      end
    end
    @params["epubmaker"]["force_include_images"] = @params["epubmaker"]["force_include_images"].sort.uniq
  end

  def copy_images(resdir, destdir, allow_exts=nil)
    return nil unless File.exist?(resdir)
    allow_exts = @params["image_ext"] if allow_exts.nil?
    FileUtils.mkdir_p(destdir)
    if @params["epubmaker"]["verify_target_images"].present?
      @params["epubmaker"]["force_include_images"].each do |file|
        unless File.exist?(file)
          warn "#{file} is not found, skip." if file !~ /\Ahttp[s]?:/
          next
        end
        basedir = File.dirname(file)
        FileUtils.mkdir_p("#{destdir}/#{basedir}")
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
    FileUtils.mkdir_p(destdir)
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
            FileUtils.mkdir_p(destdir)
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
          @htmltoc.add_item(0, htmlfile, title, {:chaptype => "part"})
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
      @body = ""
      @body << "<div class=\"part\">\n"
      @body << "<h1 class=\"part-number\">#{ReVIEW::I18n.t("part", part.number)}</h1>\n"
      if part.name.strip.present?
        @body << "<h2 class=\"part-title\">#{part.name.strip}</h2>\n"
      end
      @body << "</div>\n"

      @language = @producer.params['language']
      @stylesheets = @producer.params["stylesheet"]
      if @producer.params["htmlversion"].to_i == 5
        tmplfile = File.expand_path('./html/layout-html5.html.erb', ReVIEW::Template::TEMPLATE_DIR)
      else
        tmplfile = File.expand_path('./html/layout-xhtml1.html.erb', ReVIEW::Template::TEMPLATE_DIR)
      end
      tmpl = ReVIEW::Template.load(tmplfile)
      f.write tmpl.result(binding)
    end
  end

  def build_chap(chap, base_path, basetmpdir, yamlfile, ispart=nil)
    filename = ""

    chaptype = "body"
    if ispart.present?
      chaptype = "part"
    elsif chap.on_PREDEF?
      chaptype = "pre"
    elsif chap.on_APPENDIX?
      chaptype = "post"
    end

    if ispart.present?
      filename = chap.path
    else
      filename = Pathname.new(chap.path).relative_path_from(base_path).to_s
    end
    id = filename.sub(/\.re\Z/, "")

    if @params["epubmaker"]["rename_for_legacy"] && ispart.nil?
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
    system("#{ReVIEW::MakerHelper.bindir}/review-compile-peg --yaml=#{yamlfile} --target=html --level=#{level} --htmlversion=#{@params["htmlversion"]} --epubversion=#{@params["epubversion"]} #{stylesheet} #{@params["params"]} #{filename} > \"#{basetmpdir}/#{htmlfile}\"")

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
      headline["level"] = 0 if ispart.present? && headline["level"] == 1
      if first.nil?
        @htmltoc.add_item(headline["level"], filename+"#"+headline["id"], headline["title"], {:chaptype => chaptype})
      else
        @htmltoc.add_item(headline["level"], filename, headline["title"], {:force_include => true, :chaptype => chaptype+prop_str})
        first = nil
      end
    end
  end

  def push_contents(basetmpdir)
    @htmltoc.each_item do |level, file, title, args|
      next if level.to_i > @params["toclevel"] && args[:force_include].nil?
      log("Push #{file} to ePUB contents.")

      hash = {"file" => file, "level" => level.to_i, "title" => title, "chaptype" => args[:chaptype]}
      if args[:id].present?
        hash["id"] = args[:id]
      end
      if args[:properties].present?
        hash["properties"] = args[:properties].split(" ")
      end
      @producer.contents.push(Content.new(hash))
    end
  end

  def copy_stylesheet(basetmpdir)
    if @params["stylesheet"].size > 0
      @params["stylesheet"].each do |sfile|
        FileUtils.cp(sfile, basetmpdir)
        @producer.contents.push(Content.new("file" => sfile))
      end
    end
  end

  def copy_frontmatter(basetmpdir)
    FileUtils.cp(@params["cover"], "#{basetmpdir}/#{File.basename(@params["cover"])}") if @params["cover"].present? && File.exist?(@params["cover"])

    if @params["titlepage"]
      if @params["titlefile"].nil?
        build_titlepage(basetmpdir, "titlepage.#{@params["htmlext"]}")
      else
        FileUtils.cp(@params["titlefile"], "#{basetmpdir}/titlepage.#{@params["htmlext"]}")
      end
      @htmltoc.add_item(1, "titlepage.#{@params['htmlext']}", @producer.res.v("titlepagetitle"), {:chaptype => "pre"})
    end

    if @params["originaltitlefile"].present? && File.exist?(@params["originaltitlefile"])
      FileUtils.cp(@params["originaltitlefile"], "#{basetmpdir}/#{File.basename(@params["originaltitlefile"])}")
      @htmltoc.add_item(1, File.basename(@params["originaltitlefile"]), @producer.res.v("originaltitle"), {:chaptype => "pre"})
    end

    if @params["creditfile"].present? && File.exist?(@params["creditfile"])
      FileUtils.cp(@params["creditfile"], "#{basetmpdir}/#{File.basename(@params["creditfile"])}")
      @htmltoc.add_item(1, File.basename(@params["creditfile"]), @producer.res.v("credittitle"), {:chaptype => "pre"})
    end
  end

  def build_titlepage(basetmpdir, htmlfile)
    File.open("#{basetmpdir}/#{htmlfile}", "w") do |f|
      @body = ""
      @body << "<div class=\"titlepage\">"
      @body << "<h1 class=\"tp-title\">#{CGI.escapeHTML(@params["booktitle"])}</h1>"
      if @params["aut"]
        @body << "<h2 class=\"tp-author\">#{@params["aut"].join(", ")}</h2>"
      end
      if @params["prt"]
        @body << "<h3 class=\"tp-publisher\">#{@params["prt"].join(", ")}</h3>"
      end
      @body << "</div>"

      @language = @producer.params['language']
      @stylesheets = @producer.params["stylesheet"]
      if @producer.params["htmlversion"].to_i == 5
        tmplfile = File.expand_path('./html/layout-html5.html.erb', ReVIEW::Template::TEMPLATE_DIR)
      else
        tmplfile = File.expand_path('./html/layout-xhtml1.html.erb', ReVIEW::Template::TEMPLATE_DIR)
      end
      tmpl = ReVIEW::Template.load(tmplfile)
      f.write tmpl.result(binding)
    end
  end

  def copy_backmatter(basetmpdir)
    if @params["profile"]
      FileUtils.cp(@params["profile"], "#{basetmpdir}/#{File.basename(@params["profile"])}")
      @htmltoc.add_item(1, File.basename(@params["profile"]), @producer.res.v("profiletitle"), {:chaptype => "post"})
    end

    if @params["advfile"]
      FileUtils.cp(@params["advfile"], "#{basetmpdir}/#{File.basename(@params["advfile"])}")
      @htmltoc.add_item(1, File.basename(@params["advfile"]), @producer.res.v("advtitle"), {:chaptype => "post"})
    end

    if @params["colophon"]
      if @params["colophon"].instance_of?(String) # FIXME:このやり方はやめる？
        FileUtils.cp(@params["colophon"], "#{basetmpdir}/colophon.#{@params["htmlext"]}")
      else
        File.open("#{basetmpdir}/colophon.#{@params["htmlext"]}", "w") {|f| @producer.colophon(f) }
      end
      @htmltoc.add_item(1, "colophon.#{@params["htmlext"]}", @producer.res.v("colophontitle"), {:chaptype => "post"})
    end

    if @params["backcover"]
      FileUtils.cp(@params["backcover"], "#{basetmpdir}/#{File.basename(@params["backcover"])}")
      @htmltoc.add_item(1, File.basename(@params["backcover"]), @producer.res.v("backcovertitle"), {:chaptype => "post"})
    end
  end

  def write_buildlogtxt(basetmpdir, htmlfile, reviewfile)
    File.open("#{basetmpdir}/#{@buildlogtxt}", "a") do |f|
      f.puts "#{htmlfile},#{reviewfile}"
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
        if @level.present?
          raise "#{name}, #{attrs}"
        end
        @level = $1.to_i
        @id = attrs["id"] if attrs["id"].present?
      elsif !@level.nil?
        if name == "img" && attrs["alt"].present?
          @content << attrs["alt"]
        elsif name == "a" && attrs["id"].present?
          @id = attrs["id"]
        end
      end
    end

    def tag_end(name)
      if name =~ /\Ah\d+/
        @headlines.push({"level" => @level, "id" => @id, "title" => @content}) if @id.present?
        @content = ""
        @level = nil
        @id = nil
      end
    end

    def text(text)
      if @level.present?
        @content << text.gsub("\t", "　") # FIXME:区切り文字
      end
    end
  end
 end
end
