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
require 'epubmaker/zip_exporter'

module EPUBMaker
  # EPUBv2 is EPUB version 2 producer.
  class EPUBv2 < EPUBCommon
    # Construct object with parameter hash +config+ and message resource hash +res+.
    def initialize(producer) # rubocop:disable Lint/UselessMethodDefinition
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
        next unless config[item]

        if config[item].is_a?(Array)
          s << config.names_of(item).map { |i| %Q(    <dc:#{item}>#{h(i)}</dc:#{item}>\n) }.join
        else
          s << %Q(    <dc:#{item}>#{h(config.name_of(item).to_s)}</dc:#{item}>\n)
        end
      end

      # ID
      if config['isbn'].nil?
        s << %Q(    <dc:identifier id="BookId">#{config['urnid']}</dc:identifier>\n)
      else
        s << %Q(    <dc:identifier id="BookId" opf:scheme="ISBN">#{config['isbn']}</dc:identifier>\n)
      end

      # creator (should be array)
      %w[aut a-adp a-ann a-arr a-art a-asn a-aqt a-aft a-aui a-ant a-bkp a-clb a-cmm a-dsr a-edt a-ill a-lyr a-mdc a-mus a-nrt a-oth a-pht a-prt a-red a-rev a-spn a-ths a-trc a-trl].each do |role|
        next unless config[role]

        config.names_of(role).each do |v|
          s << %Q(    <dc:creator opf:role="#{role.sub('a-', '')}">#{h(v)}</dc:creator>\n)
        end
      end

      # contributor (should be array)
      %w[adp ann arr art asn aqt aft aui ant bkp clb cmm dsr edt ill lyr mdc mus nrt oth pht prt red rev spn ths trc trl].each do |role|
        next unless config[role]

        config.names_of(role).each do |v|
          s << %Q(    <dc:contributor opf:role="#{role}">#{h(v)}</dc:contributor>\n)
          if role == 'prt'
            s << %Q(    <dc:publisher>#{v}</dc:publisher>\n)
          end
        end
      end

      s
    end

    def opf_manifest
      s = ''
      s << <<EOT
  <manifest>
    <item id="ncx" href="#{config['bookname']}.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="#{config['bookname']}" href="#{config['cover']}" media-type="application/xhtml+xml"/>
EOT

      s << %Q(    <item id="toc" href="#{config['bookname']}-toc.#{config['htmlext']}" media-type="application/xhtml+xml"/>\n) if config['toc'] && config['mytoc']

      @producer.contents.each do |item|
        next if item.file =~ /#/ # skip subgroup

        s << %Q(    <item id="#{item.id}" href="#{item.file}" media-type="#{item.media}"/>\n)
      end
      s << %Q(  </manifest>\n)
      s
    end

    def opf_tocx
      cover_linear = if config['epubmaker']['cover_linear'] && config['epubmaker']['cover_linear'] != 'no'
                       'yes'
                     else
                       'no'
                     end

      s = ''
      s << %Q(  <spine toc="ncx">\n)
      s << %Q(    <itemref idref="#{config['bookname']}" linear="#{cover_linear}"/>\n)
      s << %Q(    <itemref idref="toc" />\n) unless config['mytoc'].nil?

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

      ncx_file = "#{tmpdir}/OEBPS/#{config['bookname']}.ncx"
      File.write(ncx_file, ncx(config['epubmaker']['ncxindent']))

      if config['mytoc']
        toc_file = "#{tmpdir}/OEBPS/#{config['bookname']}-toc.#{config['htmlext']}"
        File.write(toc_file, mytoc)
      end

      @producer.call_hook(config['epubmaker']['hook_prepack'], tmpdir)
      expoter = EPUBMaker::ZipExporter.new(tmpdir, config)
      expoter.export_zip(epubfile)
    end
  end
end
