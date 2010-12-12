# encoding: utf-8
#
# Copyright (c) 2010 Kenshi Muto and Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
#

require 'tmpdir'
require 'fileutils'
require 'yaml'
require 'rexml/document'
require 'uuid'

class Ec
  attr_accessor :id, :href, :media, :title, :level, :notoc

  def initialize(idorhash, href=nil, media=nil, title=nil, level=nil, notoc=nil)
    if idorhash.instance_of?(Hash)
      @id = idorhash["id"]
      @href = idorhash["href"]
      @media = idorhash["media"]
      @title = idorhash["title"]
      @level = idorhash["level"]
      @notoc = idorhash["notoc"]
    else
      @id = idorhash
      @href = href
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
    @media = "images/jpeg" if @media == "jpg" || @media == "jpeg" || @media == "images/jpg"
    @media = "images/png" if @media == "png"
    @media = "images/gif" if @media == "gif"
    @media = "images/svg" if @media == "svg"
    @media = "images/svg+xml" if @media == "svg" || @media == "images/svg"

    if @id.nil? || @href.nil? || @media.nil?
      raise "Type error: #{id}, #{href}, #{media}, #{title}, #{notoc}"
    end
  end
end

class EPUBMaker

  attr_accessor :data

  def initialize(version, params)
    @params = params
    @version = version
    validate_params
  end

  def mimetype(wobj)
    s = __send__("mimetype_#{@version}")
    if !s.nil? && !wobj.nil?
      wobj.puts s
    end
  end

  def opf(wobj)
    s = __send__("opf_#{@version}")
    if !s.nil? && !wobj.nil?
      wobj.puts s
    end
  end

  def ncx(wobj, indentarray)
    s = __send__("ncx_#{@version}", indentarray)
    if !s.nil? && !wobj.nil?
      wobj.puts s
    end
  end

  def mytoc(wobj)

  end

  private

  def getTocTitle
    toctitle = "Table of contents"
    toctitle = "目次" if @params["language"] == "ja"
    toctitle = @params["toctitle"] unless @params["toctitle"].nil?
    return toctitle
  end

  def validate_params
    # FIXME: needs escapeHTML?

    # use default value if not defined
    defaults = {
      "title" => @params["booktitle"], # backward compatibility
      "language" => "ja",
      "date" => Time.now.strftime("%Y-%m-%d"),
      "urnid" => UUID.create,
    }
    defaults.each_pair do |k, v|
      @params[k] = v if @params[k].nil?
    end

    # must be defined
    ["bookname", "title"].each do |k|
      raise "Key #{k} must have a value. Abort." if @params[k].nil?
    end
    # array
    ["subject", "aut", "a-adp", "a-ann", "a-arr", "a-art", "a-asn", "a-aut", "a-aqt", "a-aft", "a-aui", "a-ant", "a-bkp", "a-clb", "a-cmm", "a-dsr", "a-edt", "a-ill", "a-lyr", "a-mdc", "a-mus", "a-nrt", "a-oth", "a-pht", "a-prt", "a-red", "a-rev", "a-spn", "a-ths", "a-trc", "a-trl", "adp", "ann", "arr", "art", "asn", "aut", "aqt", "aft", "aui", "ant", "bkp", "clb", "cmm", "dsr", "edt", "ill", "lyr", "mdc", "mus", "nrt", "oth", "pht", "prt", "red", "rev", "spn", "ths", "trc", "trl"].each do |item|
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
    ["title", "language", "date", "type", "format", "source", "description", "relation", "coverage", "subject", "rights"].each do |item|
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
      s << %Q[    <dc:identifier id="BookId">urn:uuid:#{@params["urnid"]}</dc:identifier>\n]
    else
      s << %Q[    <dc:identifier id="BookId" opf:scheme="ISBN">#{@params["isbn"]}</dc:identifier>\n]
    end

    # creator
    ["aut", "a-adp", "a-ann", "a-arr", "a-art", "a-asn", "a-aut", "a-aqt", "a-aft", "a-aui", "a-ant", "a-bkp", "a-clb", "a-cmm", "a-dsr", "a-edt", "a-ill", "a-lyr", "a-mdc", "a-mus", "a-nrt", "a-oth", "a-pht", "a-prt", "a-red", "a-rev", "a-spn", "a-ths", "a-trc", "a-trl"].each do |role|
      unless @params[role].nil?
        @params[role].each do |v|
          s << %Q[    <dc:creator opf:role="#{role.sub('a-', '')}">#{v}</dc:creator>\n]
        end
      end
    end
    # contributor
    ["adp", "ann", "arr", "art", "asn", "aut", "aqt", "aft", "aui", "ant", "bkp", "clb", "cmm", "dsr", "edt", "ill", "lyr", "mdc", "mus", "nrt", "oth", "pht", "prt", "red", "rev", "spn", "ths", "trc", "trl"].each do |role|
      unless @params[role].nil?
        @params[role].each do |v|
          s << %Q[    <dc:contributor opf:role="#{role}">#{v}</dc:creator>\n]
        end
      end
    end

    if @params["coverfile"]
      @data.each do |item|
        if item.media =~ /\Aimages/ && item.href =~ /#{@params["coverfile"]}\Z/
          s << %Q[    <meta name="cover" content="#{item.id}"/>\n]
          break
        end
      end
    end
    
    s << %Q[  </metadata>\n]

    # manifest
    s << <<EOT
  <manifest>
    <item id="ncx" href="#{@params["bookname"]}.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="#{@params["bookname"]}" href="#{@params["bookname"]}.xhtml" media-type="application/xhtml+xml"/>
EOT
s << %Q[    <item id="toc" href="toc.xhtml" media-type="application/xhtml+xml"/>\n] unless @params["mytoc"].nil?

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

    cs = "Cover Page"
    cs = "表紙" if @params["language"] == "ja"
    s << %Q[    <reference type="cover" title="#{cs}" href="#{@params["bookname"]}.xhtml"/>\n]
    title = @params["titlepage"].nil? ? "#{@params["bookname"]}.xhtml" : @params["titlepage"]
    s << %Q[    <reference type="title-page" title="Title Page" href="#{title}"/>\n]
    unless @params["mytoc"].nil?
      s << %Q[    <reference type="toc" title="#{getTocTitle}" href="toc.xhtml"/>\n]
    end

    s << %Q[  </guide>\n]

    s << %Q[</package>]
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
    <text>#{@params["booktitle"]}</text>
  </docTitle>
  <docAuthor>
    <text>#{@params["aut"].nil? ? "" : @params["aut"].join(", ")}</text>
  </docAuthor>
  <navMap>
    <navPoint id="top" playOrder="1">
      <navLabel>
        <text>#{@params["booktitle"]}</text>
      </navLabel>
      <content src="#{@params["bookname"]}.xhtml"/>
    </navPoint>
EOT

    nav_count = 2

    unless @params["mytoc"].nil?
      s << <<EOT
    <navPoint id="toc" playOrder="#{nav_count}">
      <navLabel>
        <text>#{getTocTitlle}</text>
      </navLabel>
      <content src="toc.xhtml"/>
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

end

params = {"bookname" => "book", "booktitle"=>"TITLE", "a-adp" => "kenshi", "subject" => ["A", "B"], "coverfile" => "cover.jpg"}
o = EPUBMaker.new(2, params)
o.data = [
          Ec.new("style", "a.css", "text/css"),
          Ec.new("using", "using.xhtml", "application/xhtml+xml", "tukaikata"),
          Ec.new("using2", "using2.xhtml", "application/xhtml+xml", "tukaikata2", 2),
          Ec.new("using3", "using3.xhtml", "application/xhtml+xml", "tukaikata3", 3),
          Ec.new("hidden", "hidden.xhtml", "xhtml", nil, nil, true),
          Ec.new("fig1", "images/hoa.png", "png"),
          Ec.new(nil, "images/cover.jpg", "jpg"),
          Ec.new({"id" => nil, "href" => "media.png"})
]
#o.mimetype(STDOUT)
#o.opf(STDOUT)
o.ncx(STDOUT, ["", "- "])
