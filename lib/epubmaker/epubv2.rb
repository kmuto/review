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
      @opf_metainfo = opf_metainfo
      @opf_coverimage = opf_coverimage
      @opf_manifest = opf_manifest
      @opf_toc = opf_tocx

      tmplfile = File.expand_path('./opf/epubv2.opf.erb', ReVIEW::Template::TEMPLATE_DIR)
      tmpl = ReVIEW::Template.load(tmplfile)
      return tmpl.result(binding)
    end

    def opf_metainfo
      s = ""
      %w[title language date type format source description relation coverage subject rights].each do |item|
        next if @producer.params[item].nil?
        if @producer.params[item].instance_of?(Array)
          s << @producer.params[item].map {|i| %Q[    <dc:#{item}>#{CGI.escapeHTML(i.to_s)}</dc:#{item}>\n]}.join
        else
          s << %Q[    <dc:#{item}>#{CGI.escapeHTML(@producer.params[item].to_s)}</dc:#{item}>\n]
        end
      end

      # ID
      if @producer.params["isbn"].nil?
        s << %Q[    <dc:identifier id="BookId">#{@producer.params["urnid"]}</dc:identifier>\n]
      else
        s << %Q[    <dc:identifier id="BookId" opf:scheme="ISBN">#{@producer.params["isbn"]}</dc:identifier>\n]
      end

      # creator (should be array)
      %w[aut a-adp a-ann a-arr a-art a-asn a-aqt a-aft a-aui a-ant a-bkp a-clb a-cmm a-dsr a-edt a-ill a-lyr a-mdc a-mus a-nrt a-oth a-pht a-prt a-red a-rev a-spn a-ths a-trc a-trl].each do |role|
        next if @producer.params[role].nil?
        @producer.params[role].each do |v|
          s << %Q[    <dc:creator opf:role="#{role.sub('a-', '')}">#{CGI.escapeHTML(v)}</dc:creator>\n]
        end
      end

      # contributor (should be array)
      %w[adp ann arr art asn aqt aft aui ant bkp clb cmm dsr edt ill lyr mdc mus nrt oth pht prt red rev spn ths trc trl].each do |role|
        next if @producer.params[role].nil?
        @producer.params[role].each do |v|
          s << %Q[    <dc:contributor opf:role="#{role}">#{CGI.escapeHTML(v)}</dc:contributor>\n]
          if role == "prt"
            s << %Q[    <dc:publisher>#{v}</dc:publisher>\n]
          end
        end
      end

      s
    end

    def opf_manifest
      s = ""
      s << <<EOT
  <manifest>
    <item id="ncx" href="#{@producer.params["bookname"]}.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="#{@producer.params["bookname"]}" href="#{@producer.params["cover"]}" media-type="application/xhtml+xml"/>
EOT

      s << %Q[    <item id="toc" href="#{@producer.params["bookname"]}-toc.#{@producer.params["htmlext"]}" media-type="application/xhtml+xml"/>\n] if @producer.params["toc"] && @producer.params["mytoc"]

      @producer.contents.each do |item|
        next if item.file =~ /#/ # skip subgroup
        s << %Q[    <item id="#{item.id}" href="#{item.file}" media-type="#{item.media}"/>\n]
      end
      s << %Q[  </manifest>\n]
      s
    end

    def opf_tocx
      if @producer.params["epubmaker"]["cover_linear"] && @producer.params["epubmaker"]["cover_linear"] != "no"
        cover_linear = "yes"
      else
        cover_linear = "no"
      end

      s = ""
      s << %Q[  <spine toc="ncx">\n]
      s << %Q[    <itemref idref="#{@producer.params["bookname"]}" linear="#{cover_linear}"/>\n]
      s << %Q[    <itemref idref="toc" />\n] unless @producer.params["mytoc"].nil?

      @producer.contents.each do |item|
        next if item.media !~ /xhtml\+xml/ # skip non XHTML
        s << %Q[    <itemref idref="#{item.id}"/>\n] if item.notoc.nil?
      end
      s << %Q[  </spine>\n]
      s
    end

    # Return ncx content. +indentarray+ has prefix marks for each level.
    def ncx(indentarray)
      @ncx_isbn = ncx_isbn
      @ncx_doctitle = ncx_doctitle
      @ncx_navmap = ncx_navmap(indentarray)

      tmplfile = File.expand_path('./ncx/epubv2.ncx.erb', ReVIEW::Template::TEMPLATE_DIR)
      tmpl = ReVIEW::Template.load(tmplfile)
      return tmpl.result(binding)
    end

    # Produce EPUB file +epubfile+.
    # +basedir+ points the directory has contents.
    # +tmpdir+ defines temporary directory.
    def produce(epubfile, basedir, tmpdir)
      produce_write_common(basedir, tmpdir)

      File.open("#{tmpdir}/OEBPS/#{@producer.params["bookname"]}.ncx", "w") {|f| @producer.ncx(f, @producer.params["epubmaker"]["ncxindent"]) }
      File.open("#{tmpdir}/OEBPS/#{@producer.params["bookname"]}-toc.#{@producer.params["htmlext"]}", "w") {|f| @producer.mytoc(f) } unless @producer.params["mytoc"].nil?

      @producer.call_hook(@producer.params["epubmaker"]["hook_prepack"], tmpdir)
      export_zip(tmpdir, epubfile)
    end

  end
end
