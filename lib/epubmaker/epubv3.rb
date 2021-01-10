# = epubv3.rb -- EPUB version 3 producer.
#
# Copyright (c) 2010-2017 Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
#

require 'epubmaker/epubcommon'
require 'epubmaker/zip_exporter'

module EPUBMaker
  # EPUBv3 is EPUB version 3 producer.
  class EPUBv3 < EPUBCommon
    DC_ITEMS = %w[title language date type format source description relation coverage subject rights]
    CREATOR_ATTRIBUTES = %w[a-adp a-ann a-arr a-art a-asn a-aqt a-aft a-aui a-ant a-bkp a-clb a-cmm a-csl a-dsr a-edt a-ill a-lyr a-mdc a-mus a-nrt a-oth a-pht a-prt a-red a-rev a-spn a-ths a-trc a-trl aut]
    CONTRIBUTER_ATTRIBUTES = %w[adp ann arr art asn aqt aft aui ant bkp clb cmm csl dsr edt ill lyr mdc mus nrt oth pbd pbl pht prt red rev spn ths trc trl]

    # Construct object with parameter hash +config+ and message resource hash +res+.
    def initialize(producer)
      super
      @opf_prefix = {}
      if config['opf_prefix'].present?
        config['opf_prefix'].each { |k, v| @opf_prefix[k] = v }
      end
    end

    # Return opf file content.
    def opf
      @opf_metainfo = opf_metainfo
      @opf_coverimage = opf_coverimage
      @opf_manifest = opf_manifest
      @opf_toc = opf_tocx
      @package_attrs = ''

      if @opf_prefix && @opf_prefix.size > 0
        prefixes_str = @opf_prefix.map { |k, v| %Q(#{k}: #{v}) }.join(' ')
        @package_attrs << %Q( prefix="#{prefixes_str}")
      end

      tmplfile = File.expand_path('./opf/epubv3.opf.erb', ReVIEW::Template::TEMPLATE_DIR)
      ReVIEW::Template.load(tmplfile).result(binding)
    end

    def opf_metainfo
      @dc_items = DC_ITEMS.map do |item|
        next unless config[item]

        case config[item]
        when Array
          config[item].map.with_index do |v, i|
            if v.is_a?(Hash)
              { tag: "dc:#{item}",
                id: "#{item}-#{i}",
                val: v['name'],
                refines: v.map { |name, val| { name: name, val: val } }.delete_if { |h| h[:name] == 'name' } }
            else
              { tag: "dc:#{item}", id: "#{item}-#{i}", val: v.to_s, refines: [] }
            end
          end
        when Hash
          { tag: "dc:#{item}",
            id: item.to_s,
            val: config[item]['name'],
            refines: config[item].map { |name, val| { name: name, val: val } }.delete_if { |h| h[:name] == 'name' } }
        else
          { tag: "dc:#{item}",
            id: item.to_s,
            val: config[item].to_s,
            refines: [] }
        end
      end.flatten.compact

      # creator (should be array)
      @creators = CREATOR_ATTRIBUTES.map do |role|
        next unless config[role]

        config[role].map.with_index do |v, i|
          case v
          when Hash
            refines = v.map { |name, val| { id: "#{role.sub('a-', '')}-#{i}", property: name.to_s, scheme: nil, val: val } }.delete_if { |h| h[:property] == 'name' }

            {
              id: "#{role}-#{i}",
              val: v['name'],
              refines: [
                { id: "#{role}-#{i}", property: 'role', scheme: 'marc:relators', val: role.sub('a-', '') }
              ].concat(refines)
            }
          else
            {
              id: "#{role}-#{i}",
              val: v,
              refines: [
                { id: "#{role}-#{i}", property: 'role', scheme: 'marc:relators', val: role.sub('a-', '') }
              ]
            }
          end
        end
      end.flatten.compact

      # contributor (should be array)
      @contributers = CONTRIBUTER_ATTRIBUTES.map do |role|
        next unless config[role]

        config[role].map.with_index do |v, i|
          case v
          when Hash
            refines = v.map { |name, val| { id: "#{role}-#{i}", property: name, scheme: nil, val: val } }.delete_if { |h| h[:property] == 'name' }
            contributer = {
              id: "#{role}-#{i}",
              val: v['name'],
              refines: [
                { id: "#{role}-#{i}", property: 'role', scheme: 'marc:relators', val: role }
              ].concat(refines)
            }
          else
            contributer = {
              id: "#{role}-#{i}",
              val: v,
              refines: [
                { id: "#{role}-#{i}", property: 'role', scheme: 'marc:relators', val: role }
              ]
            }
          end
          if %w[prt pbl].include?(role)
            contributer[:pub_id] = "pub-#{role}-#{i}"
            case v
            when Hash
              contributer[:pub_val] = v['name']
              pub_refines = v.map { |name, val| { id: "pub-#{role}-#{i}", property: name, scheme: nil, val: val } }.delete_if { |h| h[:property] == 'name' }
              contributer[:pub_refines] = [
                { id: "pub-#{role}-#{i}", property: 'role', scheme: 'marc:relators', val: role }
              ].concat(pub_refines)
            else
              contributer[:pub_val] = v
              contributer[:pub_refines] = [
                { id: "pub-#{role}-#{i}", property: 'role', scheme: 'marc:relators', val: 'prt' }
              ]
            end
          end

          contributer
        end
      end.flatten.compact

      tmplfile = File.expand_path('./opf/opf_metainfo_epubv3.opf.erb', ReVIEW::Template::TEMPLATE_DIR)
      ReVIEW::Template.load(tmplfile).result(binding)
    end

    def opf_manifest
      if config['coverimage']
        item = contents.find { |content| content.coverimage?(config['coverimage']) }
        if item
          @coverimage = item
          item.id = nil
        end
      end
      @items = contents.find_all { |content| content.file !~ /#/ && content.id } # skip subgroup, or id=nil (for cover)

      tmplfile = File.expand_path('./opf/opf_manifest_epubv3.opf.erb', ReVIEW::Template::TEMPLATE_DIR)
      ReVIEW::Template.load(tmplfile).result(binding)
    end

    def opf_tocx
      @cover_linear = if config['epubmaker']['cover_linear'] && config['epubmaker']['cover_linear'] != 'no'
                        'yes'
                      else
                        'no'
                      end
      @tocx_contents = []
      toc = nil
      contents.each do |item|
        next if item.media !~ /xhtml\+xml/ # skip non XHTML

        @tocx_contents << item
      end

      tmplfile = File.expand_path('./opf/opf_tocx_epubv3.opf.erb', ReVIEW::Template::TEMPLATE_DIR)
      ReVIEW::Template.load(tmplfile).result(binding)
    end

    def ncx(indentarray)
      ncx_main = if config['epubmaker']['flattoc'].nil?
                   hierarchy_ncx('ol')
                 else
                   flat_ncx('ol', config['epubmaker']['flattocindent'])
                 end

      @body = <<-EOT
  <nav xmlns:epub="http://www.idpf.org/2007/ops" epub:type="toc" id="toc">
  <h1 class="toc-title">#{h(ReVIEW::I18n.t('toctitle'))}</h1>
#{ncx_main}  </nav>
      EOT

      @title = h(ReVIEW::I18n.t('toctitle'))
      @language = config['language']
      @stylesheets = config['stylesheet']
      tmplfile = File.expand_path('./html/layout-html5.html.erb', ReVIEW::Template::TEMPLATE_DIR)
      ReVIEW::Template.load(tmplfile).result(binding)
    end

    # Produce EPUB file +epubfile+.
    # +basedir+ points the directory has contents.
    # +tmpdir+ defines temporary directory.
    def produce(epubfile, basedir, tmpdir)
      produce_write_common(basedir, tmpdir)

      toc_file = "#{tmpdir}/OEBPS/#{config['bookname']}-toc.#{config['htmlext']}"
      File.write(toc_file, ncx(config['epubmaker']['ncxindent']))

      call_hook(config['epubmaker']['hook_prepack'], tmpdir)
      expoter = EPUBMaker::ZipExporter.new(tmpdir, config)
      expoter.export_zip(epubfile)
    end
  end
end
