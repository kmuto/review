# = epubv2.rb -- EPUB version 2 producer.
#
# Copyright (c) 2010-2017 Kenshi Muto and Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
#

require 'epubmaker/epubcommon'
require 'cgi'
require 'epubmaker/zip_exporter'

module EPUBMaker
  # EPUBv2 is EPUB version 2 producer.
  class EPUBv2 < EPUBCommon
    # Construct object with parameter hash +config+ and message resource hash +res+.
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
      tmpl.result(binding)
    end

    def opf_metainfo
      s = ''
      %w[title language date type format source description relation coverage subject rights].each do |item|
        next unless @producer.config[item]
        if @producer.config[item].is_a?(Array)
          s << @producer.config.names_of(item).map { |i| %Q(    <dc:#{item}>#{CGI.escapeHTML(i)}</dc:#{item}>\n) }.join
        else
          s << %Q(    <dc:#{item}>#{CGI.escapeHTML(@producer.config.name_of(item))}</dc:#{item}>\n)
        end
      end

      # ID
      if @producer.config['isbn'].nil?
        s << %Q(    <dc:identifier id="BookId">#{@producer.config['urnid']}</dc:identifier>\n)
      else
        s << %Q(    <dc:identifier id="BookId" opf:scheme="ISBN">#{@producer.config['isbn']}</dc:identifier>\n)
      end

      # creator (should be array)
      %w[aut a-adp a-ann a-arr a-art a-asn a-aqt a-aft a-aui a-ant a-bkp a-clb a-cmm a-dsr a-edt a-ill a-lyr a-mdc a-mus a-nrt a-oth a-pht a-prt a-red a-rev a-spn a-ths a-trc a-trl].each do |role|
        next unless @producer.config[role]
        @producer.config.names_of(role).each do |v|
          s << %Q(    <dc:creator opf:role="#{role.sub('a-', '')}">#{CGI.escapeHTML(v)}</dc:creator>\n)
        end
      end

      # contributor (should be array)
      %w[adp ann arr art asn aqt aft aui ant bkp clb cmm dsr edt ill lyr mdc mus nrt oth pht prt red rev spn ths trc trl].each do |role|
        next unless @producer.config[role]
        @producer.config.names_of(role).each do |v|
          s << %Q(    <dc:contributor opf:role="#{role}">#{CGI.escapeHTML(v)}</dc:contributor>\n)
          s << %Q(    <dc:publisher>#{v}</dc:publisher>\n) if role == 'prt'
        end
      end

      s
    end

    def opf_manifest
      s = ''
      s << <<EOT
  <manifest>
    <item id="ncx" href="#{@producer.config['bookname']}.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="#{@producer.config['bookname']}" href="#{@producer.config['cover']}" media-type="application/xhtml+xml"/>
EOT

      s << %Q(    <item id="toc" href="#{@producer.config['bookname']}-toc.#{@producer.config['htmlext']}" media-type="application/xhtml+xml"/>\n) if @producer.config['toc'] && @producer.config['mytoc']

      @producer.contents.each do |item|
        next if item.file =~ /#/ # skip subgroup
        s << %Q(    <item id="#{item.id}" href="#{item.file}" media-type="#{item.media}"/>\n)
      end
      s << %Q(  </manifest>\n)
      s
    end

    def opf_tocx
      cover_linear = if @producer.config['epubmaker']['cover_linear'] && @producer.config['epubmaker']['cover_linear'] != 'no'
                       'yes'
                     else
                       'no'
                     end

      s = ''
      s << %Q(  <spine toc="ncx">\n)
      s << %Q(    <itemref idref="#{@producer.config['bookname']}" linear="#{cover_linear}"/>\n)
      s << %Q(    <itemref idref="toc" />\n) unless @producer.config['mytoc'].nil?

      @producer.contents.each do |item|
        next if item.media !~ /xhtml\+xml/ # skip non XHTML
        s << %Q(    <itemref idref="#{item.id}"/>\n)
      end
      s << %Q(  </spine>\n)
      s
    end

    # Return ncx content. +indentarray+ has prefix marks for each level.
    def ncx(indentarray)
      @ncx_isbn = ncx_isbn
      @ncx_doctitle = ncx_doctitle
      @ncx_navmap = ncx_navmap(indentarray)

      tmplfile = File.expand_path('./ncx/epubv2.ncx.erb', ReVIEW::Template::TEMPLATE_DIR)
      ReVIEW::Template.load(tmplfile).result(binding)
    end

    # Produce EPUB file +epubfile+.
    # +basedir+ points the directory has contents.
    # +tmpdir+ defines temporary directory.
    def produce(epubfile, basedir, tmpdir)
      produce_write_common(basedir, tmpdir)

      File.open("#{tmpdir}/OEBPS/#{@producer.config['bookname']}.ncx", 'w') { |f| @producer.ncx(f, @producer.config['epubmaker']['ncxindent']) }
      File.open("#{tmpdir}/OEBPS/#{@producer.config['bookname']}-toc.#{@producer.config['htmlext']}", 'w') { |f| @producer.mytoc(f) } if @producer.config['mytoc']

      @producer.call_hook(@producer.config['epubmaker']['hook_prepack'], tmpdir)
      expoter = EPUBMaker::ZipExporter.new(tmpdir, @producer.config)
      expoter.export_zip(epubfile)
    end
  end
end
