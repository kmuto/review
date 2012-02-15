# encoding: utf-8
# = epubv2.rb -- EPUB version 2 producer.
#
# Copyright (c) 2010 Kenshi Muto and Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
#

require 'epubmaker/producer'

module EPUBMaker
  
  # EPUBv2 is EPUB version 2 producer.
  class EPUBv2
    # Construct object with parameter hash +params+ and message resource hash +res+.
    def initialize(producer)
      @producer = producer
    end
    
    # Return mimetype content.
    def mimetype
      return <<EOT
application/epub+zip
EOT
    end
    
    # Return opf file content.
    def opf
      s = <<EOT
<?xml version="1.0" encoding="UTF-8"?>
<package version="2.0" xmlns="http://www.idpf.org/2007/opf" unique-identifier="BookId">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:opf="http://www.idpf.org/2007/opf">
EOT
      %w[title language date type format source description relation coverage subject rights].each do |item|
        next if @producer.params[item].nil?
        if @producer.params[item].instance_of?(Array)
          s << @producer.params[item].map {|i| %Q[    <dc:#{item}>#{i}</dc:#{item}>\n]}.join
        else
          s << %Q[    <dc:#{item}>#{@producer.params[item]}</dc:#{item}>\n]
        end
      end
      
      # ID
      if @producer.params["isbn"].nil?
        s << %Q[    <dc:identifier id="BookId">#{@producer.params["urnid"]}</dc:identifier>\n]
      else
        s << %Q[    <dc:identifier id="BookId" opf:scheme="ISBN">#{@producer.params["isbn"]}</dc:identifier>\n]
      end
      
      # creator
      %w[aut a-adp a-ann a-arr a-art a-asn a-aqt a-aft a-aui a-ant a-bkp a-clb a-cmm a-dsr a-edt a-ill a-lyr a-mdc a-mus a-nrt a-oth a-pht a-prt a-red a-rev a-spn a-ths a-trc a-trl].each do |role|
        next if @producer.params[role].nil?
        @producer.params[role].each do |v|
          s << %Q[    <dc:creator opf:role="#{role.sub('a-', '')}">#{v}</dc:creator>\n]
        end
      end
      # contributor
      %w[adp ann arr art asn aqt aft aui ant bkp clb cmm dsr edt ill lyr mdc mus nrt oth pht prt red rev spn ths trc trl].each do |role|
        next if @producer.params[role].nil?
        @producer.params[role].each do |v|
          s << %Q[    <dc:contributor opf:role="#{role}">#{v}</dc:contributor>\n]
          if role == "prt"
            s << %Q[    <dc:publisher>#{v}</dc:publisher>\n]
          end
        end
      end
      
      if @producer.params["coverimage"]
        @producer.contents.each do |item|
          if item.media =~ /\Aimage/ && item.file =~ /#{@producer.params["coverimage"]}\Z/
              s << %Q[    <meta name="cover" content="#{item.id}"/>\n]
            break
          end
        end
      end
      
      s << %Q[  </metadata>\n]
      
      # manifest
      s << <<EOT
  <manifest>
    <item id="ncx" href="#{@producer.params["bookname"]}.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="#{@producer.params["bookname"]}" href="#{@producer.params["cover"]}" media-type="application/xhtml+xml"/>
EOT

      s << %Q[    <item id="toc" href="#{@producer.params["tocfile"]}" media-type="application/xhtml+xml"/>\n] unless @producer.params["mytoc"].nil?
      
      @producer.contents.each do |item|
        next if item.file =~ /#/ # skip subgroup
        s << %Q[    <item id="#{item.id}" href="#{item.file}" media-type="#{item.media}"/>\n]
      end
      s << %Q[  </manifest>\n]
      
      # tocx
      s << %Q[  <spine toc="ncx">\n]
      s << %Q[    <itemref idref="#{@producer.params["bookname"]}" linear="no"/>\n]
      s << %Q[    <itemref idref="toc" />\n] unless @producer.params["mytoc"].nil?
      
      @producer.contents.each do |item|
        next if item.media !~ /xhtml\+xml/ # skip non XHTML
        s << %Q[    <itemref idref="#{item.id}"/>\n] if item.notoc.nil?
      end
      s << %Q[  </spine>\n]
      
      # guide
      s << %Q[  <guide>\n]
      s << %Q[    <reference type="cover" title="#{@producer.res.v("covertitle")}" href="#{@producer.params["cover"]}"/>\n]
      s << %Q[    <reference type="title-page" title="#{@producer.res.v("titlepagetitle")}" href="#{@producer.params["titlepage"]}"/>\n] unless @producer.params["titlepage"].nil?
      s << %Q[    <reference type="toc" title="#{@producer.res.v("toctitle")}" href="#{@producer.params["tocfile"]}"/>\n] unless @producer.params["mytoc"].nil?
      s << %Q[    <reference type="colophon" title="#{@producer.res.v("colophontitle")}" href="colophon.#{@producer.params["htmlext"]}"/>\n] unless @producer.params["colophon"].nil? # FIXME: path
      s << %Q[  </guide>\n]
      s << %Q[</package>\n]
      return s
    end

    # Return ncx content. +indentarray+ defines prefix string for each level.
    def ncx(indentarray)
      s = <<EOT
<?xml version="1.0" encoding="UTF-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <head>
    <meta name="dtb:depth" content="1"/>
    <meta name="dtb:totalPageCount" content="0"/>
    <meta name="dtb:maxPageNumber" content="0"/>
EOT
      if @producer.params["isbn"].nil?
        s << %Q[    <meta name="dtb:uid" content="#{@producer.params["urnid"]}"/>\n]
      else
        s << %Q[    <meta name="dtb:uid" content="#{@producer.params["isbn"]}"/>\n]
      end
      
      s << <<EOT
  </head>
  <docTitle>
    <text>#{@producer.params["title"]}</text>
  </docTitle>
  <docAuthor>
    <text>#{@producer.params["aut"].nil? ? "" : @producer.params["aut"].join(", ")}</text>
  </docAuthor>
  <navMap>
    <navPoint id="top" playOrder="1">
      <navLabel>
        <text>#{@producer.params["title"]}</text>
      </navLabel>
      <content src="#{@producer.params["cover"]}"/>
    </navPoint>
EOT

      nav_count = 2
      
      unless @producer.params["mytoc"].nil?
        s << <<EOT
    <navPoint id="toc" playOrder="#{nav_count}">
      <navLabel>
        <text>#{@producer.res.v("toctitle")}</text>
      </navLabel>
      <content src="#{@producer.params["tocfile"]}"/>
    </navPoint>
EOT
        nav_count += 1
      end
      
      @producer.contents.each do |item|
        next if item.title.nil?
        indent = indentarray.nil? ? [""] : indentarray
        level = item.level.nil? ? 0 : (item.level - 1)
        level = indent.size - 1 if level >= indent.size
        s << <<EOT
    <navPoint id="nav-#{nav_count}" playOrder="#{nav_count}">
      <navLabel>
        <text>#{indent[level]}#{item.title}</text>
      </navLabel>
      <content src="#{item.file}"/>
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
    
    # Return container content.
    def container
      s = <<EOT
<?xml version="1.0" encoding="UTF-8"?>
<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container" version="1.0">
  <rootfiles>
    <rootfile full-path="OEBPS/#{@producer.params["bookname"]}.opf" media-type="application/oebps-package+xml" />
  </rootfiles>
</container>
EOT
      return s
    end
    
    # Return cover content.
    def cover
      s = common_header
      s << <<EOT
  <title>#{@producer.params["title"]}</title>
</head>
<body>
EOT
      if @producer.params["coverimage"].nil?
        s << <<EOT
<h1 class="cover-title">#{@producer.params["title"]}</h1>
EOT
      else
        file = nil
        @producer.contents.each do |item|
          if item.media =~ /\Aimage/ && item.file =~ /#{@producer.params["coverimage"]}\Z/ # /
            file = item.file
            break
          end
        end
        raise "coverimage #{@producer.params["coverimage"]} not found. Abort." if file.nil?
        s << <<EOT
  <div id="cover-image" class="cover-image">
    <img src="#{file}" alt="#{@producer.params["title"]}" class="max"/>
  </div>
EOT
   end
      
      s << <<EOT
</body>
</html>
EOT
      return s
    end

    # Return title (copying) content.
    def titlepage
      s = common_header
      s << <<EOT
  <title>#{@producer.params["title"]}</title>
</head>
<body>
  <h1 class="tp-title">#{@producer.params["title"]}</h1>
EOT

      if @producer.params["aut"]
        s << <<EOT
  <p>
    <br />
    <br />
  </p>
  <h2 class="tp-author">#{@producer.params["aut"]}</h2>
EOT
      end

      if @producer.params["prt"]
        s << <<EOT
  <p>
    <br />
    <br />
    <br />
    <br />
  </p>
  <h3 class="tp-publisher">#{@producer.params["prt"]}</h3>
EOT
      end

      s << <<EOT
</body>
</html>
EOT
      return s
    end

    # Return colophon content.
    def colophon
      s = common_header
      s << <<EOT
  <title>#{@producer.res.v("colophontitle")}</title>
</head>
<body>
  <div class="colophon">
    <p class="title">#{@producer.params["title"]}</p>
EOT

      if @producer.params["pubhistory"]
        s << %Q[    <div class="pubhistory">\n      <p>#{@producer.params["pubhistory"].gsub(/\n/, "<br />")}</p>\n    </div>\n] # FIXME: should be array?
      end
      
      s << %Q[    <table class="colophon">\n]
      s << %Q[      <tr><th>#{@producer.res.v("c-aut")}</th><td>#{@producer.params["aut"]}</td></tr>\n] if @producer.params["aut"]
      s << %Q[      <tr><th>#{@producer.res.v("c-dsr")}</th><td>#{@producer.params["dsr"]}</td></tr>\n] if @producer.params["dsr"]
      s << %Q[      <tr><th>#{@producer.res.v("c-ill")}</th><td>#{@producer.params["ill"]}</td></tr>\n] if @producer.params["ill"]
      s << %Q[      <tr><th>#{@producer.res.v("c-edt")}</th><td>#{@producer.params["edt"]}</td></tr>\n] if @producer.params["edt"]
      s << %Q[      <tr><th>#{@producer.res.v("c-prt")}</th><td>#{@producer.params["prt"]}</td></tr>\n] if @producer.params["prt"]
      s << <<EOT
    </table>
  </div>
</body>
</html>
EOT
      return s
    end

    # Return own toc content.
    def mytoc
      s = common_header
      s << <<EOT
  <title>#{@producer.res.v("toctitle")}</title>
</head>
<body>
  <h1 class="toc-title">#{@producer.res.v("toctitle")}</h1>
  <ul class="toc-h1">
EOT

      # FIXME: indent
      current = 1
      init_item = true
      @producer.contents.each do |item|
        next if !item.notoc.nil? || item.level.nil? || item.file.nil? || item.title.nil? || item.level > @producer.params["toclevel"].to_i
        if item.level > current
          s << %Q[\n<ul class="toc-h#{item.level}">\n]
          current = item.level
        elsif item.level < current
          (current - 1).downto(item.level) do |n|
            s << %Q[</li>\n</ul>\n]
          end
          s << %Q[</li>\n]
          current = item.level
        elsif init_item
          # noop
        else
          s << %Q[</li>\n]
        end
        s << %Q[<li><a href="#{item.file}">#{item.title}</a>]
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
      return s
    end

    # Produce EPUB file +epubfile+.
    # +basedir+ points the directory has contents.
    # +tmpdir+ defines temporary directory.
    def produce(epubfile, basedir, tmpdir)
      File.open("#{tmpdir}/mimetype", "w") {|f| @producer.mimetype(f) }
      
      Dir.mkdir("#{tmpdir}/META-INF") unless File.exist?("#{tmpdir}/META-INF")
      File.open("#{tmpdir}/META-INF/container.xml", "w") {|f| @producer.container(f) }
      
      Dir.mkdir("#{tmpdir}/OEBPS") unless File.exist?("#{tmpdir}/OEBPS")
      File.open("#{tmpdir}/OEBPS/#{@producer.params["bookname"]}.opf", "w") {|f| @producer.opf(f) }
      File.open("#{tmpdir}/OEBPS/#{@producer.params["bookname"]}.ncx", "w") {|f| @producer.ncx(f, @producer.params["ncxindent"]) }
      File.open("#{tmpdir}/OEBPS/#{@producer.params["tocfile"]}", "w") {|f| @producer.mytoc(f) } unless @producer.params["mytoc"].nil?
      
      if File.exist?("#{basedir}/#{@producer.params["cover"]}")
        FileUtils.cp("#{basedir}/#{@producer.params["cover"]}", "#{tmpdir}/OEBPS")
      else
        File.open("#{tmpdir}/OEBPS/#{@producer.params["cover"]}", "w") {|f| @producer.cover(f) }
      end
      
      # FIXME:colophon and titlepage should be included in @producer.contents.
      
      @producer.contents.each do |item|
        next if item.file =~ /#/ # skip subgroup
        fname = "#{basedir}/#{item.file}"
        raise "#{fname} doesn't exist. Abort." unless File.exist?(fname)
        FileUtils.mkdir_p(File.dirname("#{tmpdir}/OEBPS/#{item.file}")) unless File.exist?(File.dirname("#{tmpdir}/OEBPS/#{item.file}"))
        FileUtils.cp(fname, "#{tmpdir}/OEBPS/#{item.file}")
      end

      fork {
        Dir.chdir(tmpdir) {|d|
          exec("zip", "-0X", "#{epubfile}", "mimetype")
        }
      }
      Process.waitall
      fork {
        Dir.chdir(tmpdir) {|d|
          exec("zip", "-Xr9D", "#{epubfile}", "META-INF OEBPS")
        }
      }
      Process.waitall
    end

    private

    # Return common XHTML headder
    def common_header
      s =<<EOT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:ops="http://www.idpf.org/2007/ops" xml:lang="#{@producer.params["language"]}">
<head>
  <meta http-equiv="Content-Type" content="text/html;charset=UTF-8"/>
  <meta http-equiv="Content-Style-Type" content="text/css"/>
  <meta name="generator" content="EPUBMaker::Producer"/>
EOT

      @producer.params["stylesheet"].each do |file|
        s << %Q[  <link rel="stylesheet" type="text/css" href="#{file}"/>\n]
      end
      return s
    end
  end
  
end
