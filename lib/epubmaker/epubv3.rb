# encoding: utf-8
# = epubv3.rb -- EPUB version 3 producer.
#
# Copyright (c) 2010 Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
#

require 'epubmaker/epubv2'

module EPUBMaker
  
  # EPUBv3 is EPUB version 3 producer.
  class EPUBv3 < EPUBv2
    def ncx(indentarray)
      # FIXME: handle indentarray
      s = common_header
      s << <<EOT
  <title>#{@producer.res.v("toctitle")}</title>
</head>
<body>
  <nav epub:type="toc" id="toc">
  <h1 class="toc-title">#{@producer.res.v("toctitle")}</h1>
  <ul class="toc-h1">
EOT

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
  </nav>
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
      File.open("#{tmpdir}/OEBPS/#{@producer.params["bookname"]}-toc.#{@producer.params["htmlext"]}", "w") {|f| @producer.ncx(f, @producer.params["ncxindent"]) }
#      File.open("#{tmpdir}/OEBPS/#{@producer.params["tocfile"]}", "w") {|f| @producer.mytoc(f) } unless @producer.params["mytoc"].nil?
      
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
          exec("zip", "-Xr9D", "#{epubfile}", "META-INF", "OEBPS")
        }
      }
      Process.waitall
    end

    # Return opf file content.
    def opf
      mathstr = @producer.params["mathml"].nil? ? "" : %Q[ properties="mathml"]
      s = <<EOT
<?xml version="1.0" encoding="UTF-8"?>
<package version="3.0" xmlns="http://www.idpf.org/2007/opf" unique-identifier="BookId" xml:lang="#{@producer.params["language"]}" profile="http://www.idpf.org/epub/30/profile/package/">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:opf="http://www.idpf.org/2007/opf">
EOT
      %w[title language date type format source description relation coverage subject rights].each do |item|
        next if @producer.params[item].nil?
        if @producer.params[item].instance_of?(Array)
          s << @producer.params[item].map {|i| %Q[    <dc:#{item} prefer="#{item}">#{i}</dc:#{item}>\n]}.join
          s << @producer.params[item].map {|i| %Q[    <meta id="#{item}" property="dcterms:#{item}">#{i}</meta>\n]}.join
        else
          s << %Q[    <dc:#{item} prefer="#{item}">#{@producer.params[item]}</dc:#{item}>\n]
          s << %Q[    <meta id="#{item}" property="dcterms:#{item}">#{@producer.params[item]}</meta>\n]
        end
      end

      # ID
      if @producer.params["isbn"].nil?
        s << %Q[    <dc:identifier id="BookId" prefer="bookid">#{@producer.params["urnid"]}</dc:identifier>\n]
        s << %Q[    <meta property="dcterms:identifier" id="bookid">#{@producer.params["urnid"]}</meta>\n]
      else
        s << %Q[    <dc:identifier id="BookId" opf:scheme="ISBN" prefer="bookid">#{@producer.params["isbn"]}</dc:identifier>\n]
        s << %Q[    <meta property="dcterms:identifier" id="bookid" opf:scheme="ISBN">#{@producer.params["isbn"]}</meta>\n]
      end
      
      # creator
      %w[aut a-adp a-ann a-arr a-art a-asn a-aqt a-aft a-aui a-ant a-bkp a-clb a-cmm a-dsr a-edt a-ill a-lyr a-mdc a-mus a-nrt a-oth a-pht a-prt a-red a-rev a-spn a-ths a-trc a-trl].each do |role|
        next if @producer.params[role].nil?
        @producer.params[role].each_with_index do |v, i|
          s << %Q[    <dc:creator opf:role="#{role.sub('a-', '')}" prefer="creator-#{i}">#{v}</dc:creator>\n]
          s << %Q[    <meta property="dcterms:creator" id="creator-#{i}" opf:role="#{role.sub('a-', '')}">#{v}</meta>\n]
        end
      end
      # contributor
      %w[adp ann arr art asn aqt aft aui ant bkp clb cmm dsr edt ill lyr mdc mus nrt oth pht prt red rev spn ths trc trl].each do |role|
        next if @producer.params[role].nil?
        @producer.params[role].each_with_index do |v, i|
          s << %Q[    <dc:contributor opf:role="#{role}" prefer="contributor-#{i}">#{v}</dc:contributor>\n]
          s << %Q[    <meta property="dcterms:contributor" id="contributor-#{i}" opf:role="#{role}">#{v}</meta>\n]

          if role == "prt"
            s << %Q[    <dc:publisher prefer="publisher">#{v}</dc:publisher>\n]
            s << %Q[    <meta property="dcterms:publisher" id="publisher">#{v}</meta>\n]
          end
        end
      end

      s << %Q[  </metadata>\n]
      
      # manifest
      s << <<EOT
  <manifest>
    <item properties="nav#{mathstr.empty? ? '' : ' mathml'}" id="#{@producer.params["bookname"]}-toc.#{@producer.params["htmlext"]}" href="#{@producer.params["bookname"]}-toc.#{@producer.params["htmlext"]}" media-type="application/xhtml+xml"/>
    <item id="#{@producer.params["bookname"]}" href="#{@producer.params["cover"]}" media-type="application/xhtml+xml"/>
EOT

      if @producer.params["coverimage"]
        @producer.contents.each do |item|
          if item.media =~ /\Aimage/ && item.file =~ /#{@producer.params["coverimage"]}\Z/
              s << %Q[    <item properties="cover-image" id="#{item.id}" href="#{item.file}" media-type="#{item.media}"/>\n]
            break
          end
        end
      end
      
#      s << %Q[    <item id="toc" href="#{@producer.params["tocfile"]}" media-type="application/xhtml+xml"/>\n] unless @producer.params["mytoc"].nil?
      
      @producer.contents.each do |item|
        next if item.file =~ /#/ # skip subgroup
        s << %Q[    <item#{mathstr} id="#{item.id}" href="#{item.file}" media-type="#{item.media}"/>\n]
      end
      s << %Q[  </manifest>\n]
      
      # tocx
      s << %Q[  <spine>\n]
      s << %Q[    <itemref idref="#{@producer.params["bookname"]}" linear="no"/>\n]
      s << %Q[    <itemref idref="#{@producer.params["bookname"]}-toc.#{@producer.params["htmlext"]}" />\n] unless @producer.params["mytoc"].nil?
      
      @producer.contents.each do |item|
        next if item.media !~ /xhtml\+xml/ # skip non XHTML
        s << %Q[    <itemref idref="#{item.id}"/>\n] if item.notoc.nil?
      end
      s << %Q[  </spine>\n]
      
      # guide
      s << %Q[  <guide>\n]
      s << %Q[    <reference type="cover" title="#{@producer.res.v("covertitle")}" href="#{@producer.params["cover"]}"/>\n]
      s << %Q[    <reference type="title-page" title="#{@producer.res.v("titlepagetitle")}" href="#{@producer.params["titlepage"]}"/>\n] unless @producer.params["titlepage"].nil?
      s << %Q[    <reference type="toc" title="#{@producer.res.v("toctitle")}" href="#{@producer.params["bookname"]}-toc.#{@producer.params["htmlext"]}"/>\n] unless @producer.params["mytoc"].nil?
      s << %Q[    <reference type="colophon" title="#{@producer.res.v("colophontitle")}" href="colophon.#{@producer.params["htmlext"]}"/>\n] unless @producer.params["colophon"].nil? # FIXME: path
      s << %Q[  </guide>\n]
      s << %Q[</package>\n]
      return s
    end

    private

    # Return cover pointer for opf file
    def cover_in_opf
      s = ""

      if @producer.params["coverimage"]
        @producer.contents.each do |item|
          if item.media =~ /\Aimage/ && item.file =~ /#{@producer.params["coverimage"]}\Z/
              s << <<EOT
            <item id="#{item.id}" href="#{item.file}" media-type="#{item.media}"/>
EOT
            break
          end
        end
      end
      
      s << <<EOT
    <item id="#{@producer.params["bookname"]}" href="#{@producer.params["cover"]}" media-type="application/xhtml+xml"/>
EOT
      return s
    end

    def common_header
      s =<<EOT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2011/epub" xmlns:ops="http://www.idpf.org/2007/ops" xml:lang="#{@producer.params["language"]}">
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
