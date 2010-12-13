=begin rdoc
EPUBの生成を支援するライブラリ

  [シンプルな例]
  params = EPUBMaker.load_yaml(ARGV[0])
  epub = EPUBMaker.new(2, params)
  epub.data.push(Ec.new({"href" => "ch01.xhtml"}))
  epub.data.push(Ec.new({"href" => "ch02.xhtml"}))
   ...
  epub.importImageInfo("images")
  epub.makeepub("#{params["bookname"]}.epub")
=end

# encoding: utf-8
#
# Copyright (c) 2010 Kenshi Muto and Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
#
# TODO: handle title-page
#       epub v3
#       better documents and samples

require 'tmpdir'
require 'fileutils'
require 'yaml'
require 'rexml/document'
require 'uuid'

# EPUBMakerに渡すコンテンツデータ。Ecオブジェクトの配列をEPUBMaker#dataに代入することで、コンテンツとして処理される
class Ec
  # コンテンツの一意な識別子
  attr_accessor :id
  # コンテンツの相対ファイルパス(アンカーを含むこともできる)
  attr_accessor :href
  # コンテンツのMIMEタイプ
  attr_accessor :media
  # コンテンツの見出し
  attr_accessor :title
  # コンテンツの見出しレベル(1〜)
  attr_accessor :level
  # コンテンツの目次表示可否。nilの場合には表示しない
  attr_accessor :notoc

  # コンテンツデータの値を引数またはハッシュで指定してオブジェクトを作る
  # hreforhash::ファイルパスまたはハッシュ。ハッシュの場合には後続の値は指定せず、ハッシュ内で指定する("id"=>"〜", "href"=>"〜", ...)。基本的にはhrefだけを明確に指定すればほかは自動生成して省略できる
  def initialize(hreforhash, id=nil, media=nil, title=nil, level=nil, notoc=nil)
    if hreforhash.instance_of?(Hash)
      @id = hreforhash["id"]
      @href = hreforhash["href"]
      @media = hreforhash["media"]
      @title = hreforhash["title"]
      @level = hreforhash["level"]
      @notoc = hreforhash["notoc"]
    else
      @href = hreforhash
      @id = id
      @media = media
      @title = title
      @level = level
      @notoc = notoc
    end
    validate
  end

  private

  def validate
    # validation
    @id = @href.gsub(/[\\\/\.]/, '-') if @id.nil?
    @media = @href.sub(/.+\./, '').downcase if !@href.nil? && @media.nil?

    @media = "application/xhtml+xml" if @media == "xhtml" || @media == "xml" || @media == "html"
    @media = "text/css" if @media == "css"
    @media = "image/jpeg" if @media == "jpg" || @media == "jpeg" || @media == "image/jpg"
    @media = "image/png" if @media == "png"
    @media = "image/gif" if @media == "gif"
    @media = "image/svg" if @media == "svg"
    @media = "image/svg+xml" if @media == "svg" || @media == "image/svg"

    if @id.nil? || @href.nil? || @media.nil?
      raise "Type error: #{id}, #{href}, #{media}, #{title}, #{notoc}"
    end
  end
end

# メッセージリソース。languageパラメータの値によっていくつかの文字列を切り替える
class EPUBMakerResource
  # languageパラメータに従って使用する言語メッセージを設定する
  def initialize(params)
    @params = params

    @hash = nil
    begin
      @hash = __send__ @params["language"]
    rescue
      @hash = __send__ :en
    end

    @hash.each_pair do |k, v|
      @hash[k] = @params[k] unless @params[k].nil?
    end
  end

  # メッセージIDに相当するメッセージを返す
  # key:: メッセージID
  def v(key)
    return @hash[key]
  end

  private
  def en
    {
      "toctitle" => "Table of Contents",
      "covertitle" => "Cover",
      "titlepagetitle" => "Title Page",
      "colophontitle" => "Colophon",
      "c-aut" => "Author",
      "c-dsr" => "Designer",
      "c-ill" => "Illustrator",
      "c-edt" => "Editor",
      "c-prt" => "Publisher",
    }
  end

  def ja
    {
      "toctitle" => "目次",
      "covertitle" => "表紙",
      "titlepagetitle" => "権利表記",
      "colophontitle" => "奥付",
      "c-aut" => "著　者",
      "c-dsr" => "デザイン",
      "c-ill" => "イラスト",
      "c-edt" => "編　集",
      "c-prt" => "発行所",
    }
  end
end

# EPUB生成のための各種内部処理を提供する
class EPUBMaker
  # コンテンツデータ(Ec)の配列
  attr_accessor :data

  # YAMLファイルを読み取り、パラメータを返す
  # yamlfile:: YAMLファイル名
  def EPUBMaker.load_yaml(yamlfile)
    raise "Can't open #{yamlfile}." if yamlfile.nil? || !File.exist?(yamlfile)
    return YAML.load_file(yamlfile)
  end

  # EPUBバージョン、パラメータを渡してオブジェクトを生成する
  # version:: EPUBのバージョン。現行では「2」を指定すること
  # params:: パラメータ(ハッシュ)。通常はYAMLファイルで定義する
  def initialize(version, params)
    @data = []
    @params = params
    @version = version
    validate_params
    @res = EPUBMakerResource.new(@params)
  end

  # EPUBバージョンに従ったmimetypeファイルを生成する
  # wobj:: 書き込み先IOオブジェクト。STDOUTを指定すると標準出力に出力する
  def mimetype(wobj)
    s = __send__("mimetype_#{@version}")
    if !s.nil? && !wobj.nil?
      wobj.puts s
    end
  end

  # EPUBバージョンに従ったopfファイルを生成する
  # wobj:: 書き込み先IOオブジェクト。STDOUTを指定すると標準出力に出力する
  def opf(wobj)
    s = __send__("opf_#{@version}")
    if !s.nil? && !wobj.nil?
      wobj.puts s
    end
  end

  # EPUBバージョンに従ったncxファイルを生成する
  # wobj:: 書き込み先IOオブジェクト。STDOUTを指定すると標準出力に出力する
  # indentarray:: 見出しレベルに応じてプレフィクスに付ける文字を配列で指定する。配列の0番目の値がレベル1の見出しに付き、1番目の値がレベル2の見出しに付き、……となる
  def ncx(wobj, indentarray=[])
    s = __send__("ncx_#{@version}", indentarray)
    if !s.nil? && !wobj.nil?
      wobj.puts s
    end
  end

  # EPUBバージョンに従ったcontainerファイルを生成する
  # wobj:: 書き込み先IOオブジェクト。STDOUTを指定すると標準出力に出力する
  def container(wobj)
    s = __send__("container_#{@version}")
    if !s.nil? && !wobj.nil?
      wobj.puts s
    end
  end

  # 表紙ファイルを生成する。coverimageパラメータが設定されているときには、その画像を画面一杯に表示するように構成する
  # wobj:: 書き込み先IOオブジェクト。STDOUTを指定すると標準出力に出力する
  def cover(wobj)
    s = common_header
    s << <<EOT
  <title>#{@params["title"]}</title>
</head>
<body>
EOT
   if @params["coverimage"].nil?
     s << <<EOT
<h1 class="cover-title">#{@params["title"]}</h1>
EOT
   else
     href = nil
     @data.each do |item|
        if item.media =~ /\Aimage/ && item.href =~ /#{@params["coverimage"]}\Z/
            href = item.href
          break
        end
      end
     raise "coverimage #{@params["coverimage"]} not found. Abort." if href.nil?
     s << <<EOT
  <div id="cover-image" class="cover-image">
    <img src="#{href}" alt="#{@params["title"]}" class="max"/>
  </div>
EOT
   end

    s << <<EOT
</body>
</html>
EOT
    wobj.puts s
  end

  # 奥付ファイルを生成する
  # wobj:: 書き込み先IOオブジェクト。STDOUTを指定すると標準出力に出力する
  def colophon(wobj)
    s = common_header
    s << <<EOT
  <title>#{@res.v("colophontitle")}</title>
</head>
<body>
  <div class="colophon">
    <p class="title">#{@params["title"]}</p>
EOT

    if @params["pubhistory"]
      s << %Q[    <div class="pubhistory">\n      <p>#{@params["pubhistory"].gsub(/\n/, "<br />")}</p>\n    </div>\n] # FIXME: should be array?
    end

    s << %Q[    <table class="colophon">\n]
    s << %Q[      <tr><th>#{@res.v("c-aut")}</th><td>#{@params["aut"]}</td></tr>\n] if @params["aut"]
    s << %Q[      <tr><th>#{@res.v("c-dsr")}</th><td>#{@params["dsr"]}</td></tr>\n] if @params["dsr"]
    s << %Q[      <tr><th>#{@res.v("c-ill")}</th><td>#{@params["ill"]}</td></tr>\n] if @params["ill"]
    s << %Q[      <tr><th>#{@res.v("c-edt")}</th><td>#{@params["edt"]}</td></tr>\n] if @params["edt"]
    s << %Q[      <tr><th>#{@res.v("c-prt")}</th><td>#{@params["prt"]}</td></tr>\n] if @params["prt"]

    s << <<EOT
    </table>
  </div>
</body>
</html>
EOT
    wobj.puts s
  end

  # 独自の目次ファイルを生成する
  # wobj:: 書き込み先IOオブジェクト。STDOUTを指定すると標準出力に出力する
  def mytoc(wobj)
    s = common_header
    s << <<EOT
  <title>#{@res.v("toctitle")}</title>
</head>
<body>
  <h1 class="toc-title">#{@res.v("toctitle")}</h1>
  <ul class="toc-h1">
EOT

    # FIXME: indent
    current = 1
    init_item = true
    @data.each do |item|
      next if !item.notoc.nil? || item.level.nil? || item.href.nil? || item.title.nil? || item.level > @params["toclevel"].to_i
      if item.level > current
        s << %Q[\n<ul class="toc-h#{item.level}">\n]
        current = item.level
      elsif item.level < current
        s << %Q[</li>\n</ul>\n</li>\n]
        current = item.level
      elsif init_item
        # noop
      else
        s << %Q[</li>\n]
      end
      s << %Q[<li><a href="#{item.href}">#{item.title}</a>]
      init_item = false
    end

    (current - 1).downto(1) do |n|
      s << %Q[</li>\n</ul>\n]
    end
    if !init_item
      s << %Q[</li>\n]
    end
    s << <<EOT
  </ul>
</body>
</html>
EOT
    wobj.puts s
  end

  # 指定ディレクトリ下の画像を再帰的に検索し、コンテンツデータ配列に追加登録する。このメソッドは自己呼び出しされる
  # path:: 検索パス
  # base:: コンテンツデータとしての登録時にファイルパスから除外する文字列
  def importImageInfo(path, base=nil)
    Dir.foreach(path) do |f|
      next if f =~ /\A\./
      if f =~ /\.(png|jpg|jpeg|svg|gif)\Z/i
        path.chop! if path =~ /\/\Z/
        if base.nil?
          @data.push(Ec.new({"href" => "#{path}/#{f}"}))
        else
          @data.push(Ec.new({"href" => "#{path.sub(base + "/", '')}/#{f}"}))
        end
      end
      if FileTest.directory?("#{path}/#{f}")
        importImageInfo("#{path}/#{f}", base)
      end
    end
  end

  # EPUBバージョンに従ったEPUBファイルを生成する
  # epubfile:: 出力先のEPUBファイル名
  # basedir:: コピー元コンテンツのあるディレクトリ名
  # _tmpdir:: 一時作業に使うディレクトリ名。省略した場合はテンポラリディレクトリを作成し、作業完了後に削除する
  def makeepub(epubfile, basedir=nil, _tmpdir=nil)
    # another zip implemantation?
    current = Dir.pwd
    basedir = current if basedir.nil?
    tmpdir = _tmpdir.nil? ? Dir.mktmpdir : _tmpdir
    epubfile = "#{current}/#{epubfile}" if epubfile !~ /\A\//
    
    # FIXME error check
    File.unlink(epubfile) if File.exist?(epubfile)
    
    begin
      __send__("makeepub_#{@version}", epubfile, basedir, tmpdir)
    ensure
      FileUtils.rm_r(tmpdir) if _tmpdir.nil?
    end
  end

  private

  def common_header
    s =<<EOT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:ops="http://www.idpf.org/2007/ops" xml:lang="#{@params["language"]}">
<head>
  <meta http-equiv="Content-Type" content="text/html;charset=UTF-8"/>
  <meta http-equiv="Content-Style-Type" content="text/css"/>
  <meta name="generator" content="ReVIEW EPUB Maker"/>
EOT

    @params["stylesheet"].each do |file|
      s << %Q[  <link rel="stylesheet" type="text/css" href="#{file}"/>\n]
    end
    return s
  end

  def makeepub_2(epubfile, basedir, tmpdir)
    File.open("#{tmpdir}/mimetype", "w") {|f| mimetype(f) }

    Dir.mkdir("#{tmpdir}/META-INF") unless File.exist?("#{tmpdir}/META-INF")
    File.open("#{tmpdir}/META-INF/container.xml", "w") {|f| container(f) }

    Dir.mkdir("#{tmpdir}/OEBPS") unless File.exist?("#{tmpdir}/OEBPS")
    File.open("#{tmpdir}/OEBPS/#{@params["bookname"]}.opf", "w") {|f| opf(f) }
    File.open("#{tmpdir}/OEBPS/#{@params["bookname"]}.ncx", "w") {|f| ncx(f, @params["ncxindent"]) }
    File.open("#{tmpdir}/OEBPS/#{@params["tocfile"]}", "w") {|f| mytoc(f) } unless @params["mytoc"].nil?

    if File.exist?("#{basedir}/#{@params["cover"]}")
      FileUtils.cp("#{basedir}/#{@params["cover"]}", "#{tmpdir}/OEBPS")
    else
      File.open("#{tmpdir}/OEBPS/#{@params["cover"]}", "w") {|f| cover(f) }
    end

    @data.each do |item|
      fname = "#{basedir}/#{item.href}"
      raise "#{fname} doesn't exist. Abort." unless File.exist?(fname)
      FileUtils.mkdir_p(File.dirname("#{tmpdir}/OEBPS/#{item.href}")) unless File.exist?(File.dirname("#{tmpdir}/OEBPS/#{item.href}"))
      FileUtils.cp(fname, "#{tmpdir}/OEBPS/#{item.href}")
    end

    fork {
      Dir.chdir(tmpdir) {|d|
        exec("zip -0X #{epubfile} mimetype")
      }
    }
    Process.waitall
    fork {
      Dir.chdir(tmpdir) {|d|
        exec("zip -Xr9D #{epubfile} META-INF OEBPS")
      }
    }
    Process.waitall
  end

  def makeepub_3(epubfile, basedir, tmpdir)
    raise "FIXME: makeepub_3 for EPUB3"
  end

  def validate_params
    # FIXME: needs escapeHTML?

    # use default value if not defined
    defaults = {
      "cover" => "#{@params["bookname"]}.xhtml",
      "title" => @params["booktitle"], # backward compatibility
      "language" => "ja",
      "date" => Time.now.strftime("%Y-%m-%d"),
      "urnid" => "urn:uid:#{UUID.create}",
      "tocfile" => "toc.xhtml",
      "toclevel" => 2,
      "stylesheet" => [],
    }
    defaults.each_pair do |k, v|
      @params[k] = v if @params[k].nil?
    end

    # must be defined
    %w[bookname title].each do |k|
      raise "Key #{k} must have a value. Abort." if @params[k].nil?
    end
    # array
    %w[subject aut a-adp a-ann a-arr a-art a-asn a-aqt a-aft a-aui a-ant a-bkp a-clb a-cmm a-dsr a-edt a-ill a-lyr a-mdc a-mus a-nrt a-oth a-pht a-prt a-red a-rev a-spn a-ths a-trc a-trl adp ann arr art asn aut aqt aft aui ant bkp clb cmm dsr edt ill lyr mdc mus nrt oth pht prt red rev spn ths trc trl stylesheet].each do |item|
      @params[item] = [@params[item]] if !@params[item].nil? && @params[item].instance_of?(String)
    end
    # optional
    # type, format, identifier, source, relation, coverpage, rights, aut
  end

  def mimetype_2
    return <<EOT
application/epub+zip
EOT
  end

  def mimetype_3
    raise "FIXME: opf_3 for EPUB3"
  end

  def opf_2
    s = <<EOT
<?xml version="1.0" encoding="UTF-8"?>
<package version="2.0" xmlns="http://www.idpf.org/2007/opf" unique-identifier="BookId">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:opf="http://www.idpf.org/2007/opf">
EOT
    %w[title language date type format source description relation coverage subject rights].each do |item|
      unless @params[item].nil?
        if @params[item].instance_of?(Array)
          s << @params[item].map {|i| %Q[    <dc:#{item}>#{i}</dc:#{item}>\n]}.join
        else
          s << %Q[    <dc:#{item}>#{@params[item]}</dc:#{item}>\n]
        end
      end
    end

    # ID
    if @params["isbn"].nil?
      s << %Q[    <dc:identifier id="BookId">#{@params["urnid"]}</dc:identifier>\n]
    else
      s << %Q[    <dc:identifier id="BookId" opf:scheme="ISBN">#{@params["isbn"]}</dc:identifier>\n]
    end

    # creator
    %w[aut a-adp a-ann a-arr a-art a-asn a-aqt a-aft a-aui a-ant a-bkp a-clb a-cmm a-dsr a-edt a-ill a-lyr a-mdc a-mus a-nrt a-oth a-pht a-prt a-red a-rev a-spn a-ths a-trc a-trl].each do |role|
      unless @params[role].nil?
        @params[role].each do |v|
          s << %Q[    <dc:creator opf:role="#{role.sub('a-', '')}">#{v}</dc:creator>\n]
        end
      end
    end
    # contributor
    %w[adp ann arr art asn aqt aft aui ant bkp clb cmm dsr edt ill lyr mdc mus nrt oth pht prt red rev spn ths trc trl].each do |role|
      unless @params[role].nil?
        @params[role].each do |v|
          s << %Q[    <dc:contributor opf:role="#{role}">#{v}</dc:contributor>\n]
        end
      end
    end

    if @params["coverimage"]
      @data.each do |item|
        if item.media =~ /\Aimage/ && item.href =~ /#{@params["coverimage"]}\Z/
          s << %Q[    <meta name="cover" content="#{item.id}"/>\n]
          break
        end
      end
    end
    
    s << %Q[  </metadata>\n]

    # manifest (FIXME:ncx can be included in?)
    s << <<EOT
  <manifest>
    <item id="ncx" href="#{@params["bookname"]}.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="#{@params["bookname"]}" href="#{@params["cover"]}" media-type="application/xhtml+xml"/>
EOT
    s << %Q[    <item id="toc" href="#{@params["tocfile"]}" media-type="application/xhtml+xml"/>\n] unless @params["mytoc"].nil?

    @data.each do |item|
      next if item.id =~ /#/ # skip subgroup
      s << %Q[    <item id="#{item.id}" href="#{item.href}" media-type="#{item.media}"/>\n]
    end
    s << %Q[  </manifest>\n]

    # tocx
    s << %Q[  <spine toc="ncx">\n]
    s << %Q[    <itemref idref="#{@params["bookname"]}" linear="no"/>\n]
    s << %Q[    <itemref idref="toc" />\n] unless @params["mytoc"].nil?

    @data.each do |item|
      next if item.media !~ /xhtml\+xml/ # skip non XHTML
      s << %Q[    <itemref idref="#{item.id}"/>\n] if item.notoc.nil?
    end
    s << %Q[  </spine>\n]

    # guide
    s << %Q[  <guide>\n]
    s << %Q[    <reference type="cover" title="#{@res.v("covertitle")}" href="#{@params["cover"]}"/>\n]
    title = @params["titlepage"].nil? ? @params["cover"] : @params["titlepage"]
    s << %Q[    <reference type="title-page" title="#{@res.v("titlepagetitle")}" href="#{title}"/>\n]
    unless @params["mytoc"].nil?
      s << %Q[    <reference type="toc" title="#{@res.v("toctitle")}" href="#{@params["tocfile"]}"/>\n]
    end
    s << %Q[  </guide>\n]
    s << %Q[</package>\n]
    return s
  end

  def opf_3
    raise "FIXME: opf_3 for EPUB3"
  end

  def ncx_2(indentarray)
    s = <<EOT
<?xml version="1.0" encoding="UTF-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <head>
    <meta name="dtb:depth" content="1"/>
    <meta name="dtb:totalPageCount" content="0"/>
    <meta name="dtb:maxPageNumber" content="0"/>
EOT
    # ↑FIXME
    if @params["isbn"].nil?
      s << %Q[    <meta name="dtb:uid" content="#{@params["urnid"]}"/>\n]
    else
      s << %Q[    <meta name="dtb:uid" content="#{@params["isbn"]}"/>\n]
    end

    s << <<EOT
  </head>
  <docTitle>
    <text>#{@params["title"]}</text>
  </docTitle>
  <docAuthor>
    <text>#{@params["aut"].nil? ? "" : @params["aut"].join(", ")}</text>
  </docAuthor>
  <navMap>
    <navPoint id="top" playOrder="1">
      <navLabel>
        <text>#{@params["title"]}</text>
      </navLabel>
      <content src="#{@params["cover"]}"/>
    </navPoint>
EOT

    nav_count = 2

    unless @params["mytoc"].nil?
      s << <<EOT
    <navPoint id="toc" playOrder="#{nav_count}">
      <navLabel>
        <text>#{@res.v("toctitle")}</text>
      </navLabel>
      <content src="#{@params["tocfile"]}"/>
    </navPoint>
EOT
      nav_count += 1
    end

    @data.each do |item|
      next if item.title.nil?
      indent = indentarray.nil? ? [""] : indentarray
      level = item.level.nil? ? 0 : (item.level - 1)
      level = indent.size - 1 if level >= indent.size
      s << <<EOT
    <navPoint id="nav-#{nav_count}" playOrder="#{nav_count}">
      <navLabel>
       <text>#{indent[level]}#{item.title}</text>
      </navLabel>
      <content src="#{item.href}"/>
    </navPoint>
EOT
      nav_count += 1
    end

    s << <<EOT
  </navMap>
</ncx>
EOT
    return s
  end

  def ncx_3(indentarray)
    raise "FIXME: ncx_3 for EPUB3"
  end

  def container_2
    s = <<EOT
<?xml version="1.0" encoding="UTF-8"?>
<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container" version="1.0">
  <rootfiles>
    <rootfile full-path="OEBPS/#{@params["bookname"]}.opf" media-type="application/oebps-package+xml" />
  </rootfiles>
</container>
EOT
    return s
  end

  def container_3
    raise "FIXME: container_3 for EPUB3"
  end

end
