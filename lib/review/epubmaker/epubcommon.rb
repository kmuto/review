# = epubcommon.rb -- super class for EPUBv2 and EPUBv3
#
# Copyright (c) 2010-2022 Kenshi Muto and Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
#

require 'review/i18n'
require 'review/template'
begin
  require 'cgi/escape'
rescue LoadError
  require 'cgi/util'
end

module ReVIEW
  class EPUBMaker
    # EPUBCommon is the common class for EPUB producer.
    # Some methods of this class are overridden by subclasses
    class EPUBCommon
      # Construct object with parameter hash +config+ and message resource hash +res+.
      def initialize(producer)
        @config = producer.config
        @contents = producer.contents
        @body_ext = nil
        @logger = ReVIEW.logger
        @workdir = nil
      end

      attr_reader :config
      attr_reader :contents

      def h(str)
        CGI.escapeHTML(str)
      end

      def produce(_epubfile, _basedir, _tmpdir, base_dir:)
        @workdir = base_dir
        raise NotImplementedError # should be overridden
      end

      # Return mimetype content.
      def mimetype
        'application/epub+zip'
      end

      def opf
        raise NotImplementedError # should be overridden
      end

      def opf_manifest
        raise NotImplementedError # should be overridden
      end

      def opf_metainfo
        raise NotImplementedError # should be overridden
      end

      def opf_tocx
        raise NotImplementedError # should be overridden
      end

      def opf_path
        "OEBPS/#{config['bookname']}.opf"
      end

      def opf_coverimage
        if config['coverimage']
          item = contents.find { |content| content.coverimage?(config['coverimage']) }

          unless item
            raise ApplicationError, "coverimage #{config['coverimage']} not found. Abort."
          end

          %Q(    <meta name="cover" content="#{item.id}"/>\n)
        else
          ''
        end
      end

      def ncx(indentarray)
        raise NotImplementedError # should be overridden
      end

      # Return container content.
      def container
        @opf_path = opf_path
        ReVIEW::Template.generate(path: './xml/container.xml.erb', binding: binding)
      end

      def coverimage
        return nil unless config['coverimage']

        item = contents.find { |content| content.coverimage?(config['coverimage']) }

        if item
          item.file
        end
      end

      def template_name(localfile: 'layout.html.erb', systemfile: nil)
        if @workdir
          layoutfile = File.join(@workdir, 'layouts', localfile)
          if File.exist?(layoutfile)
            return layoutfile
          end
        end

        if systemfile
          return systemfile
        end

        if config['htmlversion'].to_i == 5
          './html/layout-html5.html.erb'
        else
          './html/layout-xhtml1.html.erb'
        end
      end

      # Return cover content.
      # If Producer#config["coverimage"] is defined, it will be used for
      # the cover image.
      def cover
        @body_ext = config['epubversion'] >= 3 ? %Q( epub:type="cover") : nil

        if config['coverimage']
          @coverimage_src = coverimage
          raise ApplicationError, "coverimage #{config['coverimage']} not found. Abort." unless @coverimage_src
        end
        @body = ReVIEW::Template.generate(path: template_name(localfile: '_cover.html.erb', systemfile: 'html/_cover.html.erb'), binding: binding)

        @title = h(config.name_of('title'))
        @language = config['language']
        @stylesheets = config['stylesheet']
        ret = ReVIEW::Template.generate(path: template_name, binding: binding)
        @body_ext = nil
        ret
      end

      # Return title (copying) content.
      # NOTE: this method is not used yet.
      #       see lib/review/epubmaker.rb#build_titlepage
      def titlepage
        @title = h(config.name_of('title'))

        @title_str = config.name_of('title')
        if config['subtitle']
          @subtitle_str = config.name_of('subtitle')
        end
        if config['aut']
          @author_str = join_with_separator(config.names_of('aut'), ReVIEW::I18n.t('names_splitter'))
        end
        if config.names_of('pbl')
          @publisher_str = join_with_separator(config.names_of('pbl'), ReVIEW::I18n.t('names_splitter'))
        end
        @body = ReVIEW::Template.generate(path: template_name(localfile: '_titlepage.html.erb', systemfile: './html/_titlepage.html.erb'), binding: binding)

        @language = config['language']
        @stylesheets = config['stylesheet']
        ReVIEW::Template.generate(path: template_name, binding: binding)
      end

      # Return colophon content.
      def colophon
        @title = h(ReVIEW::I18n.t('colophontitle'))
        @isbn_hyphen = isbn_hyphen

        @body = ReVIEW::Template.generate(path: template_name(localfile: '_colophon.html.erb', systemfile: './html/_colophon.html.erb'), binding: binding)

        @language = config['language']
        @stylesheets = config['stylesheet']
        ReVIEW::Template.generate(path: template_name, binding: binding)
      end

      def isbn_hyphen
        str = config['isbn'].to_s

        if str =~ /\A\d{10}\Z/
          "#{str[0..0]}-#{str[1..5]}-#{str[6..8]}-#{str[9..9]}"
        elsif str =~ /\A\d{13}\Z/
          "#{str[0..2]}-#{str[3..3]}-#{str[4..8]}-#{str[9..11]}-#{str[12..12]}"
        end
      end

      def colophon_history
        @col_history = []
        if config['history']
          config['history'].each_with_index do |items, edit|
            items.each_with_index do |item, rev|
              editstr = edit == 0 ? ReVIEW::I18n.t('first_edition') : ReVIEW::I18n.t('nth_edition', (edit + 1).to_s)
              revstr = ReVIEW::I18n.t('nth_impression', (rev + 1).to_s)
              if item =~ /\A\d+-\d+-\d+\Z/
                @col_history << ReVIEW::I18n.t('published_by1', [date_to_s(item), editstr + revstr])
              elsif item =~ /\A(\d+-\d+-\d+)[\s　](.+)/
                # custom date with string
                item.match(/\A(\d+-\d+-\d+)[\s　](.+)/) do |m|
                  @col_history << ReVIEW::I18n.t('published_by3', [date_to_s(m[1]), m[2]])
                end
              else
                # free format
                @col_history << item
              end
            end
          end
        end

        ReVIEW::Template.generate(path: template_name(localfile: '_colophon_history.html.erb', systemfile: './html/_colophon_history.html.erb'), binding: binding)
      end

      def date_to_s(date)
        require 'date'
        d = Date.parse(date)
        d.strftime(ReVIEW::I18n.t('date_format'))
      end

      # Return own toc content.
      def mytoc
        @title = h(ReVIEW::I18n.t('toctitle'))
        @body = %Q(  <h1 class="toc-title">#{h(ReVIEW::I18n.t('toctitle'))}</h1>\n)
        @body << if config['epubmaker']['flattoc'].nil?
                   hierarchy_ncx('ul')
                 else
                   flat_ncx('ul', config['epubmaker']['flattocindent'])
                 end

        @language = config['language']
        @stylesheets = config['stylesheet']
        ReVIEW::Template.generate(path: template_name, binding: binding)
      end

      def hierarchy_ncx(type)
        require 'rexml/document'
        level = 1
        find_jump = nil
        has_part = nil
        toclevel = config['toclevel'].to_i

        # check part existance
        contents.each do |item|
          next if item.notoc || item.chaptype != 'part'

          has_part = true
          break
        end

        if has_part
          contents.each do |item|
            if item.chaptype == 'part' && item.level > 0
              # sections in part
              item.level -= 1
            end
            # down level for part and chaps. pre, appendix, post are preserved
            if item.chaptype == 'part' || item.chaptype == 'body'
              item.level += 1
            end
          end
          toclevel += 1
        end

        doc = REXML::Document.new(%Q(<#{type} class="toc-h#{level}"><li /></#{type}>))
        doc.context[:attribute_quote] = :quote

        e = doc.root.elements[1] # first <li/>
        contents.each do |item|
          next if !item.notoc.nil? || item.level.nil? || item.file.nil? || item.title.nil? || item.level > toclevel

          if item.level == level
            e2 = e.parent.add_element('li')
            e = e2
          elsif item.level > level
            find_jump = true if (item.level - level) > 1
            # deeper
            (level + 1).upto(item.level) do |n|
              if e.size == 0
                # empty span for epubcheck
                e.attributes['style'] = 'list-style-type: none;'
                es = e.add_element('span', 'style' => 'display:none;')
                es.add_text(REXML::Text.new('&#xa0;', false, nil, true))
              end

              e2 = e.add_element(type, 'class' => "toc-h#{n}")
              e3 = e2.add_element('li')
              e = e3
            end
            level = item.level
          elsif item.level < level
            # shallower
            (level - 1).downto(item.level) { e = e.parent.parent }
            e2 = e.parent.add_element('li')
            e = e2
            level = item.level
          end
          e2 = e.add_element('a', 'href' => item.file)
          e2.add_text(REXML::Text.new(item.title, true))
        end

        warn %Q(found level jumping in table of contents. consider to use 'epubmaker:flattoc: true' for strict ePUB validator.) unless find_jump.nil?

        doc.to_s.gsub('<li/>', '').gsub('</li>', "</li>\n").gsub("<#{type} ", "\n" + '\&') # ugly
      end

      def flat_ncx(type, indent = nil)
        s = %Q(<#{type} class="toc-h1">\n)
        contents.each do |item|
          next if !item.notoc.nil? || item.level.nil? || item.file.nil? || item.title.nil? || item.level > config['toclevel'].to_i

          is = indent == true ? '　' * item.level : ''
          s << %Q(<li><a href="#{item.file}">#{is}#{h(item.title)}</a></li>\n)
        end
        s << %Q(</#{type}>\n)

        s
      end

      def produce_write_common(basedir, tmpdir)
        File.write("#{tmpdir}/mimetype", mimetype)

        FileUtils.mkdir_p("#{tmpdir}/META-INF")
        File.write("#{tmpdir}/META-INF/container.xml", container)

        FileUtils.mkdir_p("#{tmpdir}/OEBPS")
        File.write(File.join(tmpdir, opf_path), opf)

        if File.exist?("#{basedir}/#{config['cover']}")
          FileUtils.cp("#{basedir}/#{config['cover']}", "#{tmpdir}/OEBPS")
        else
          File.write("#{tmpdir}/OEBPS/#{config['cover']}", cover)
        end

        if config['colophon'] && !config['colophon'].is_a?(String)
          filename = File.join(basedir, "colophon.#{config['htmlext']}")
          File.write(filename, colophon)
        end

        contents.each do |item|
          next if item.file =~ /#/ # skip subgroup

          fname = "#{basedir}/#{item.file}"
          unless File.exist?(fname)
            raise ApplicationError, "#{fname} is not found."
          end

          FileUtils.mkdir_p(File.dirname("#{tmpdir}/OEBPS/#{item.file}"))
          FileUtils.cp(fname, "#{tmpdir}/OEBPS/#{item.file}")
        end
      end

      def call_hook(filename, *params)
        return if !filename.present? || !File.exist?(filename) || !FileTest.executable?(filename)

        if ENV['REVIEW_SAFE_MODE'].to_i & 1 > 0
          warn 'hook is prohibited in safe mode. ignored.'
        else
          system(filename, *params)
        end
      end

      def legacy_cover_and_title_file(loadfile, writefile)
        FileUtils.cp(loadfile, writefile)
      end

      def join_with_separator(value, sep)
        if value.is_a?(Array)
          value.join(sep)
        else
          value
        end
      end
    end
  end
end
