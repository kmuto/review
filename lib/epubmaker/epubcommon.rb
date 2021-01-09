# = epubcommon.rb -- super class for EPUBv2 and EPUBv3
#
# Copyright (c) 2010-2019 Kenshi Muto and Masayoshi Takahashi
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

module EPUBMaker
  # EPUBCommon is the common class for EPUB producer.
  # Some methods of this class are overridden by subclasses
  class EPUBCommon
    # Construct object with parameter hash +config+ and message resource hash +res+.
    def initialize(producer)
      @config = producer.config
      @contents = producer.contents
      @body_ext = nil
    end

    attr_reader :config
    attr_reader :contents

    def h(str)
      CGI.escapeHTML(str)
    end

    def produce(epubfile, basedir, tmpdir)
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
      s = ''
      if config['coverimage']
        file = nil
        contents.each do |item|
          if !item.media.start_with?('image') || item.file !~ /#{config['coverimage']}\Z/
            next
          end

          s << %Q(    <meta name="cover" content="#{item.id}"/>\n)
          file = item.file
          break
        end

        if file.nil?
          raise "coverimage #{config['coverimage']} not found. Abort."
        end
      end
      s
    end

    def ncx(indentarray)
      raise NotImplementedError # should be overridden
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

    # Return container content.
    def container
      @opf_path = opf_path
      tmplfile = File.expand_path('./xml/container.xml.erb', ReVIEW::Template::TEMPLATE_DIR)
      tmpl = ReVIEW::Template.load(tmplfile)
      tmpl.result(binding)
    end

    def coverimage
      return nil unless config['coverimage']

      contents.each do |item|
        if item.media.start_with?('image') && item.file =~ /#{config['coverimage']}\Z/
          return item.file
        end
      end
      nil
    end

    # Return cover content.
    # If Producer#config["coverimage"] is defined, it will be used for
    # the cover image.
    def cover
      @body_ext = config['epubversion'] >= 3 ? %Q( epub:type="cover") : ''

      if config['coverimage']
        file = coverimage
        raise "coverimage #{config['coverimage']} not found. Abort." unless file

        @body = <<-EOT
  <div id="cover-image" class="cover-image">
    <img src="#{file}" alt="#{h(config.name_of('title'))}" class="max"/>
  </div>
        EOT
      else
        @body = <<-EOT
<h1 class="cover-title">#{h(config.name_of('title'))}</h1>
        EOT
        if config['subtitle']
          @body << <<-EOT
<h2 class="cover-subtitle">#{h(config.name_of('subtitle'))}</h2>
          EOT
        end
      end

      @title = h(config.name_of('title'))
      @language = config['language']
      @stylesheets = config['stylesheet']
      tmplfile = if config['htmlversion'].to_i == 5
                   File.expand_path('./html/layout-html5.html.erb', ReVIEW::Template::TEMPLATE_DIR)
                 else
                   File.expand_path('./html/layout-xhtml1.html.erb', ReVIEW::Template::TEMPLATE_DIR)
                 end
      tmpl = ReVIEW::Template.load(tmplfile)
      tmpl.result(binding)
    end

    # Return title (copying) content.
    # NOTE: this method is not used yet.
    #       see lib/review/epubmaker.rb#build_titlepage
    def titlepage
      @title = h(config.name_of('title'))

      @body = <<EOT
  <h1 class="tp-title">#{@title}</h1>
EOT

      if config['subtitle']
        @body << <<EOT
  <h2 class="tp-subtitle">#{h(config.name_of('subtitle'))}</h2>
EOT
      end

      if config['aut']
        @body << <<EOT
  <p>
    <br />
    <br />
  </p>
  <h2 class="tp-author">#{h(join_with_separator(config.names_of('aut'), ReVIEW::I18n.t('names_splitter')))}</h2>
EOT
      end

      publisher = config.names_of('pbl')
      if publisher
        @body << <<EOT
  <p>
    <br />
    <br />
    <br />
    <br />
  </p>
  <h3 class="tp-publisher">#{h(join_with_separator(publisher, ReVIEW::I18n.t('names_splitter')))}</h3>
EOT
      end

      @language = config['language']
      @stylesheets = config['stylesheet']
      tmplfile = if config['htmlversion'].to_i == 5
                   File.expand_path('./html/layout-html5.html.erb', ReVIEW::Template::TEMPLATE_DIR)
                 else
                   File.expand_path('./html/layout-xhtml1.html.erb', ReVIEW::Template::TEMPLATE_DIR)
                 end
      tmpl = ReVIEW::Template.load(tmplfile)
      tmpl.result(binding)
    end

    # Return colophon content.
    def colophon
      @title = h(ReVIEW::I18n.t('colophontitle'))
      @body = <<EOT
  <div class="colophon">
EOT

      if config['subtitle'].nil?
        @body << <<EOT
    <p class="title">#{h(config.name_of('title'))}</p>
EOT
      else
        @body << <<EOT
    <p class="title">#{h(config.name_of('title'))}<br /><span class="subtitle">#{h(config.name_of('subtitle'))}</span></p>
EOT
      end

      @body << colophon_history if config['date'] || config['history']

      @body << %Q(    <table class="colophon">\n)
      @body << config['colophon_order'].map do |role|
        if config[role]
          %Q(      <tr><th>#{h(ReVIEW::I18n.t(role))}</th><td>#{h(join_with_separator(config.names_of(role), ReVIEW::I18n.t('names_splitter')))}</td></tr>\n)
        else
          ''
        end
      end.join

      @body << %Q(      <tr><th>ISBN</th><td>#{isbn_hyphen}</td></tr>\n) if isbn_hyphen
      @body << %Q(    </table>\n)
      if config['rights'] && !config['rights'].empty?
        @body << %Q(    <p class="copyright">#{join_with_separator(config.names_of('rights').map { |m| h(m) }, '<br />')}</p>\n)
      end
      @body << %Q(  </div>\n)

      @language = config['language']
      @stylesheets = config['stylesheet']
      tmplfile = if config['htmlversion'].to_i == 5
                   File.expand_path('./html/layout-html5.html.erb', ReVIEW::Template::TEMPLATE_DIR)
                 else
                   File.expand_path('./html/layout-xhtml1.html.erb', ReVIEW::Template::TEMPLATE_DIR)
                 end
      tmpl = ReVIEW::Template.load(tmplfile)
      tmpl.result(binding)
    end

    def isbn_hyphen
      str = config['isbn'].to_s

      if str =~ /\A\d{10}\Z/
        return "#{str[0..0]}-#{str[1..5]}-#{str[6..8]}-#{str[9..9]}"
      end
      if str =~ /\A\d{13}\Z/
        return "#{str[0..2]}-#{str[3..3]}-#{str[4..8]}-#{str[9..11]}-#{str[12..12]}"
      end
    end

    def colophon_history
      buf = ''
      buf << %Q(    <div class="pubhistory">\n)
      if config['history']
        config['history'].each_with_index do |items, edit|
          items.each_with_index do |item, rev|
            editstr = edit == 0 ? ReVIEW::I18n.t('first_edition') : ReVIEW::I18n.t('nth_edition', (edit + 1).to_s)
            revstr = ReVIEW::I18n.t('nth_impression', (rev + 1).to_s)
            if item =~ /\A\d+-\d+-\d+\Z/
              buf << %Q(      <p>#{ReVIEW::I18n.t('published_by1', [date_to_s(item), editstr + revstr])}</p>\n)
            elsif item =~ /\A(\d+-\d+-\d+)[\s　](.+)/
              # custom date with string
              item.match(/\A(\d+-\d+-\d+)[\s　](.+)/) do |m|
                buf << %Q(      <p>#{ReVIEW::I18n.t('published_by3', [date_to_s(m[1]), m[2]])}</p>\n)
              end
            else
              # free format
              buf << %Q(      <p>#{item}</p>\n)
            end
          end
        end
      else
        buf << %Q(      <p>#{ReVIEW::I18n.t('published_by2', date_to_s(config['date']))}</p>\n)
      end
      buf << %Q(    </div>\n)
      buf
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
      if config['epubmaker']['flattoc'].nil?
        @body << hierarchy_ncx('ul')
      else
        @body << flat_ncx('ul', config['epubmaker']['flattocindent'])
      end

      @language = config['language']
      @stylesheets = config['stylesheet']
      tmplfile = if config['htmlversion'].to_i == 5
                   File.expand_path('./html/layout-html5.html.erb', ReVIEW::Template::TEMPLATE_DIR)
                 else
                   File.expand_path('./html/layout-xhtml1.html.erb', ReVIEW::Template::TEMPLATE_DIR)
                 end
      tmpl = ReVIEW::Template.load(tmplfile)
      tmpl.result(binding)
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

      contents.each do |item|
        next if item.file =~ /#/ # skip subgroup

        fname = "#{basedir}/#{item.file}"
        raise "#{fname} doesn't exist. Abort." unless File.exist?(fname)

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
