# encoding: utf-8
# = epubv2.rb -- EPUB version 2 producer.
#
# Copyright (c) 2010-2015 Kenshi Muto and Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
#

require 'epubmaker/epubcommon'
require 'cgi'

module EPUBMaker
  # EPUBv2 is EPUB version 2 producer.
  class EPUBv2 < EPUBCommon
    # Construct object with parameter hash +params+ and message resource hash +res+.
    def initialize(producer)
      super
    end

    # Return opf file content.
    def opf
      s = <<EOT
<?xml version="1.0" encoding="UTF-8"?>
<package version="2.0" xmlns="http://www.idpf.org/2007/opf" unique-identifier="BookId">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:opf="http://www.idpf.org/2007/opf">
EOT

      s << opf_metainfo
      s << opf_coverimage

      s << %(  </metadata>
)

      s << opf_manifest
      s << opf_tocx
      s << opf_guide

      s << %(</package>
)

      s
    end

    def opf_metainfo
      s = ''
      %w(title language date type format source description relation coverage subject rights).each do |item|
        next unless @producer.params[item]
        if @producer.params[item].instance_of?(Array)
          s << @producer.params[item].map { |i| %(    <dc:#{item}>#{CGI.escapeHTML(i.to_s)}</dc:#{item}>\n) }.join
        else
          s << %(    <dc:#{item}>#{CGI.escapeHTML(@producer.params[item].to_s)}</dc:#{item}>\n)
        end
      end

      # ID
      if @producer.params['isbn']
        s << %(    <dc:identifier id="BookId" opf:scheme="ISBN">#{@producer.params['isbn']}</dc:identifier>\n)
      else
        s << %(    <dc:identifier id="BookId">#{@producer.params['urnid']}</dc:identifier>\n)
      end

      # creator (should be array)
      %w(aut a-adp a-ann a-arr a-art a-asn a-aqt a-aft a-aui a-ant a-bkp a-clb a-cmm a-dsr a-edt a-ill a-lyr a-mdc a-mus a-nrt a-oth a-pht a-prt a-red a-rev a-spn a-ths a-trc a-trl).each do |role|
        next unless @producer.params[role]
        @producer.params[role].each do |v|
          s << %(    <dc:creator opf:role="#{role.sub('a-', '')}">#{CGI.escapeHTML(v)}</dc:creator>\n)
        end
      end

      # contributor (should be array)
      %w(adp ann arr art asn aqt aft aui ant bkp clb cmm dsr edt ill lyr mdc mus nrt oth pht prt red rev spn ths trc trl).each do |role|
        next unless @producer.params[role]
        @producer.params[role].each do |v|
          s << %(    <dc:contributor opf:role="#{role}">#{CGI.escapeHTML(v)}</dc:contributor>\n)
          s << %(    <dc:publisher>#{v}</dc:publisher>\n) if role == 'prt'
        end
      end

      s
    end

    def opf_manifest
      s = ''
      s << <<EOT
  <manifest>
    <item id="ncx" href="#{@producer.params['bookname']}.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="#{@producer.params['bookname']}" href="#{@producer.params['cover']}" media-type="application/xhtml+xml"/>
EOT

      s << %(    <item id="toc" href="#{@producer.params['bookname']}-toc.#{@producer.params['htmlext']}" media-type="application/xhtml+xml"/>\n) if @producer.params['toc'] && @producer.params['mytoc']

      @producer.contents.each do |item|
        next if item.file =~ /#/ # skip subgroup
        s << %(    <item id="#{item.id}" href="#{item.file}" media-type="#{item.media}"/>\n)
      end
      s << %(  </manifest>
)
      s
    end

    def opf_tocx
      if @producer.params['epubmaker']['cover_linear'] && @producer.params['epubmaker']['cover_linear'] != 'no'
        cover_linear = 'yes'
      else
        cover_linear = 'no'
      end

      s = ''
      s << %(  <spine toc="ncx">
)
      s << %(    <itemref idref="#{@producer.params['bookname']}" linear="#{cover_linear}"/>\n)
      s << %(    <itemref idref="toc" />
) if @producer.params['mytoc']

      @producer.contents.each do |item|
        next if item.media !~ /xhtml\+xml/ # skip non XHTML
        s << %(    <itemref idref="#{item.id}"/>\n) unless item.notoc
      end
      s << %(  </spine>
)
      s
    end

    def opf_guide
      s = ''
      s << %(  <guide>
)
      s << %(    <reference type="cover" title="#{@producer.res.v('covertitle')}" href="#{@producer.params['cover']}"/>\n)
      s << %(    <reference type="title-page" title="#{@producer.res.v('titlepagetitle')}" href="titlepage.#{@producer.params['htmlext']}"/>\n) if @producer.params['titlepage']
      s << %(    <reference type="toc" title="#{@producer.res.v('toctitle')}" href="#{@producer.params['bookname']}-toc.#{@producer.params['htmlext']}"/>\n) if @producer.params['mytoc']
      s << %(    <reference type="colophon" title="#{@producer.res.v('colophontitle')}" href="colophon.#{@producer.params['htmlext']}"/>\n) if @producer.params['colophon']
      s << %(  </guide>
)
      s
    end

    # Return ncx content. +indentarray+ has prefix marks for each level.
    def ncx(indentarray)
      s = <<EOT
<?xml version="1.0" encoding="UTF-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <head>
    <meta name="dtb:depth" content="1"/>
    <meta name="dtb:totalPageCount" content="0"/>
    <meta name="dtb:maxPageNumber" content="0"/>
EOT
      s << ncx_isbn

      s << <<EOT
  </head>
EOT
      s << ncx_doctitle
      s << ncx_navmap(indentarray)

      s << <<EOT
</ncx>
EOT
      s
    end

    # Produce EPUB file +epubfile+.
    # +basedir+ points the directory has contents.
    # +tmpdir+ defines temporary directory.
    def produce(epubfile, basedir, tmpdir)
      produce_write_common(basedir, tmpdir)

      File.open("#{tmpdir}/OEBPS/#{@producer.params['bookname']}.ncx", 'w') { |f| @producer.ncx(f, @producer.params['epubmaker']['ncxindent']) }
      File.open("#{tmpdir}/OEBPS/#{@producer.params['bookname']}-toc.#{@producer.params['htmlext']}", 'w') { |f| @producer.mytoc(f) } if @producer.params['mytoc']

      @producer.call_hook(@producer.params['epubmaker']['hook_prepack'], tmpdir)
      export_zip(tmpdir, epubfile)
    end

    private

    # Return common XHTML headder
    def common_header
      s = <<EOT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:ops="http://www.idpf.org/2007/ops" xml:lang="#{@producer.params['language']}">
<head>
  <meta http-equiv="Content-Type" content="text/html;charset=UTF-8"/>
  <meta http-equiv="Content-Style-Type" content="text/css"/>
  <meta name="generator" content="Re:VIEW"/>
EOT

      @producer.params['stylesheet'].each do |file|
        s << %(  <link rel="stylesheet" type="text/css" href="#{file}"/>\n)
      end
      s
    end
  end
end
