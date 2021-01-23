# = epubv2.rb -- EPUB version 2 producer.
#
# Copyright (c) 2010-2017 Kenshi Muto and Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
#

require 'review/epubmaker/epubcommon'
require 'review/epubmaker/zip_exporter'

module ReVIEW
  module EPUBMaker
    # EPUBv2 is EPUB version 2 producer.
    class EPUBv2 < EPUBCommon
      DC_ITEMS = %w[title language date type format source description relation coverage subject rights]
      CREATOR_ATTRIBUTES = %w[aut a-adp a-ann a-arr a-art a-asn a-aqt a-aft a-aui a-ant a-bkp a-clb a-cmm a-dsr a-edt a-ill a-lyr a-mdc a-mus a-nrt a-oth a-pht a-prt a-red a-rev a-spn a-ths a-trc a-trl]
      CONTRIBUTER_ATTRIBUTES = %w[adp ann arr art asn aqt aft aui ant bkp clb cmm dsr edt ill lyr mdc mus nrt oth pht prt red rev spn ths trc trl]

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

        ReVIEW::Template.generate(path: './opf/epubv2.opf.erb', binding: binding)
      end

      def opf_metainfo
        @dc_items = DC_ITEMS.map do |item|
          if config[item]
            if config[item].is_a?(Array)
              config.names_of(item).map { |_v| { tag: "dc:#{item}", val: item_sub } }
            else
              { tag: "dc:#{item}", val: config.name_of(item).to_s }
            end
          end
        end.flatten.compact

        # creator (should be array)
        @creators = CREATOR_ATTRIBUTES.map do |role|
          if config[role]
            config.names_of(role).map { |v| { role: role, val: v } }
          end
        end.flatten.compact

        # contributor (should be array)
        @contributers = CONTRIBUTER_ATTRIBUTES.map do |role|
          if config[role]
            config.names_of(role).map { |v| { role: role, val: v } }
          end
        end.flatten.compact

        ReVIEW::Template.generate(path: './opf/opf_metainfo_epubv2.opf.erb', binding: binding)
      end

      def opf_manifest
        @items = contents.find_all { |item| item.file !~ /#/ } # skip subgroup

        ReVIEW::Template.generate(path: './opf/opf_manifest_epubv2.opf.erb', binding: binding)
      end

      def opf_tocx
        @cover_linear = if config['epubmaker']['cover_linear'] && config['epubmaker']['cover_linear'] != 'no'
                          'yes'
                        else
                          'no'
                        end
        @ncx_contents = contents.find_all { |content| content.media =~ /xhtml\+xml/ } # skip non XHTML

        ReVIEW::Template.generate(path: './opf/opf_tocx_epubv2.opf.erb', binding: binding)
      end

      # Return ncx content. +indentarray+ has prefix marks for each level.
      def ncx(indentarray)
        @ncx_isbn = ncx_isbn
        @ncx_doctitle = ncx_doctitle
        @ncx_navmap = ncx_navmap(indentarray)

        ReVIEW::Template.generate(path: './ncx/epubv2.ncx.erb', binding: binding)
      end

      def ncx_isbn
        uid = config['isbn'] || config['urnid']
        %Q(    <meta name="dtb:uid" content="#{uid}"/>\n)
      end

      def ncx_doctitle
        <<-EOT
  <docTitle>
    <text>#{h(config['title'])}</text>
  </docTitle>
  <docAuthor>
    <text>#{config['aut'].nil? ? '' : h(join_with_separator(config['aut'], ReVIEW::I18n.t('names_splitter')))}</text>
  </docAuthor>
EOT
      end

      def ncx_navmap(indentarray)
        s = <<EOT
  <navMap>
    <navPoint id="top" playOrder="1">
      <navLabel>
        <text>#{h(config['title'])}</text>
      </navLabel>
      <content src="#{config['cover']}"/>
    </navPoint>
EOT

        nav_count = 2

        unless config['mytoc'].nil?
          s << <<EOT
    <navPoint id="toc" playOrder="#{nav_count}">
      <navLabel>
        <text>#{h(ReVIEW::I18n.t('toctitle'))}</text>
      </navLabel>
      <content src="#{config['bookname']}-toc.#{config['htmlext']}"/>
    </navPoint>
EOT
          nav_count += 1
        end

        contents.each do |item|
          next if item.title.nil?

          indent = indentarray.nil? ? [''] : indentarray
          level = item.level.nil? ? 0 : (item.level - 1)
          level = indent.size - 1 if level >= indent.size
          s << <<EOT
    <navPoint id="nav-#{nav_count}" playOrder="#{nav_count}">
      <navLabel>
        <text>#{indent[level]}#{h(item.title)}</text>
      </navLabel>
      <content src="#{item.file}"/>
    </navPoint>
EOT
          nav_count += 1
        end

        s << <<EOT
  </navMap>
EOT
        s
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

        call_hook(config['epubmaker']['hook_prepack'], tmpdir)
        expoter = EPUBMaker::ZipExporter.new(tmpdir, config)
        expoter.export_zip(epubfile)
      end
    end
  end
end
