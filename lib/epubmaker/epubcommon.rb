# = epubcommon.rb -- super class for EPUBv2 and EPUBv3
#
# Copyright (c) 2010-2017 Kenshi Muto and Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
#

require 'review/i18n'
require 'review/template'
require 'cgi'

module EPUBMaker
  # EPUBCommon is the common class for EPUB producer.
  class EPUBCommon
    # Construct object with parameter hash +config+ and message resource hash +res+.
    def initialize(producer)
      @body_ext = ''
      @producer = producer
      @body_ext = nil
    end

    # Return mimetype content.
    def mimetype
      'application/epub+zip'
    end

    def opf_path
      "OEBPS/#{@producer.config['bookname']}.opf"
    end

    def opf_coverimage
      s = ''
      if @producer.config['coverimage']
        file = nil
        @producer.contents.each do |item|
          next if !item.media.start_with?('image') || item.file !~ /#{@producer.config["coverimage"]}\Z/

          s << %Q(    <meta name="cover" content="#{item.id}"/>\n)
          file = item.file
          break
        end
        raise "coverimage #{@producer.config['coverimage']} not found. Abort." if file.nil?
      end
      s
    end

    def ncx_isbn
      uid = @producer.config['isbn'] || @producer.config['urnid']
      %Q(    <meta name="dtb:uid" content="#{uid}"/>\n)
    end

    def ncx_doctitle
      <<EOT
  <docTitle>
    <text>#{CGI.escapeHTML(@producer.config['title'])}</text>
  </docTitle>
  <docAuthor>
    <text>#{@producer.config['aut'].nil? ? '' : CGI.escapeHTML(join_with_separator(@producer.config['aut'], ReVIEW::I18n.t('names_splitter')))}</text>
  </docAuthor>
EOT
    end

    def ncx_navmap(indentarray)
      s = <<EOT
  <navMap>
    <navPoint id="top" playOrder="1">
      <navLabel>
        <text>#{CGI.escapeHTML(@producer.config['title'])}</text>
      </navLabel>
      <content src="#{@producer.config['cover']}"/>
    </navPoint>
EOT

      nav_count = 2

      unless @producer.config['mytoc'].nil?
        s << <<EOT
    <navPoint id="toc" playOrder="#{nav_count}">
      <navLabel>
        <text>#{CGI.escapeHTML(@producer.res.v('toctitle'))}</text>
      </navLabel>
      <content src="#{@producer.config['bookname']}-toc.#{@producer.config['htmlext']}"/>
    </navPoint>
EOT
        nav_count += 1
      end

      @producer.contents.each do |item|
        next if item.title.nil?
        indent = indentarray.nil? ? [''] : indentarray
        level = item.level.nil? ? 0 : (item.level - 1)
        level = indent.size - 1 if level >= indent.size
        s << <<EOT
    <navPoint id="nav-#{nav_count}" playOrder="#{nav_count}">
      <navLabel>
        <text>#{indent[level]}#{CGI.escapeHTML(item.title)}</text>
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

    # Return cover content.
    def cover(type = nil)
      @body_ext = type.nil? ? '' : %Q( epub:type="#{type}")

      if @producer.config['coverimage']
        file = @producer.coverimage
        raise "coverimage #{@producer.config['coverimage']} not found. Abort." unless file
        @body = <<-EOT
  <div id="cover-image" class="cover-image">
    <img src="#{file}" alt="#{CGI.escapeHTML(@producer.config.name_of('title'))}" class="max"/>
  </div>
        EOT
      else
        @body = <<-EOT
<h1 class="cover-title">#{CGI.escapeHTML(@producer.config.name_of('title'))}</h1>
        EOT
        if @producer.config['subtitle']
          @body << <<-EOT
<h2 class="cover-subtitle">#{CGI.escapeHTML(@producer.config.name_of('subtitle'))}</h2>
          EOT
        end
      end

      @title = CGI.escapeHTML(@producer.config.name_of('title'))
      @language = @producer.config['language']
      @stylesheets = @producer.config['stylesheet']
      tmplfile = if @producer.config['htmlversion'].to_i == 5
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
      @title = CGI.escapeHTML(@producer.config.name_of('title'))

      @body = <<EOT
  <h1 class="tp-title">#{@title}</h1>
EOT

      if @producer.config['subtitle']
        @body << <<EOT
  <h2 class="tp-subtitle">#{CGI.escapeHTML(@producer.config.name_of('subtitle'))}</h2>
EOT
      end

      if @producer.config['aut']
        @body << <<EOT
  <p>
    <br />
    <br />
  </p>
  <h2 class="tp-author">#{CGI.escapeHTML(join_with_separator(@producer.config.names_of('aut'), ReVIEW::I18n.t('names_splitter')))}</h2>
EOT
      end

      publisher = @producer.config.names_of('pbl')
      if publisher
        @body << <<EOT
  <p>
    <br />
    <br />
    <br />
    <br />
  </p>
  <h3 class="tp-publisher">#{CGI.escapeHTML(join_with_separator(publisher, ReVIEW::I18n.t('names_splitter')))}</h3>
EOT
      end

      @language = @producer.config['language']
      @stylesheets = @producer.config['stylesheet']
      tmplfile = if @producer.config['htmlversion'].to_i == 5
                   File.expand_path('./html/layout-html5.html.erb', ReVIEW::Template::TEMPLATE_DIR)
                 else
                   File.expand_path('./html/layout-xhtml1.html.erb', ReVIEW::Template::TEMPLATE_DIR)
                 end
      tmpl = ReVIEW::Template.load(tmplfile)
      tmpl.result(binding)
    end

    # Return colophon content.
    def colophon
      @title = CGI.escapeHTML(@producer.res.v('colophontitle'))
      @body = <<EOT
  <div class="colophon">
EOT

      if @producer.config['subtitle'].nil?
        @body << <<EOT
    <p class="title">#{CGI.escapeHTML(@producer.config.name_of('title'))}</p>
EOT
      else
        @body << <<EOT
    <p class="title">#{CGI.escapeHTML(@producer.config.name_of('title'))}<br /><span class="subtitle">#{CGI.escapeHTML(@producer.config.name_of('subtitle'))}</span></p>
EOT
      end

      @body << colophon_history if @producer.config['date'] || @producer.config['history']

      @body << %Q(    <table class="colophon">\n)
      @body << @producer.config['colophon_order'].map do |role|
        if @producer.config[role]
          %Q(      <tr><th>#{CGI.escapeHTML(@producer.res.v(role))}</th><td>#{CGI.escapeHTML(join_with_separator(@producer.config.names_of(role), ReVIEW::I18n.t('names_splitter')))}</td></tr>\n)
        else
          ''
        end
      end.join

      @body << %Q(      <tr><th>ISBN</th><td>#{@producer.isbn_hyphen}</td></tr>\n) if @producer.isbn_hyphen
      @body << %Q(    </table>\n)
      @body << %Q(    <p class="copyright">#{join_with_separator(@producer.config.names_of('rights').map { |m| CGI.escapeHTML(m) }, '<br />')}</p>\n) if @producer.config['rights'] && !@producer.config['rights'].empty?
      @body << %Q(  </div>\n)

      @language = @producer.config['language']
      @stylesheets = @producer.config['stylesheet']
      tmplfile = if @producer.config['htmlversion'].to_i == 5
                   File.expand_path('./html/layout-html5.html.erb', ReVIEW::Template::TEMPLATE_DIR)
                 else
                   File.expand_path('./html/layout-xhtml1.html.erb', ReVIEW::Template::TEMPLATE_DIR)
                 end
      tmpl = ReVIEW::Template.load(tmplfile)
      tmpl.result(binding)
    end

    def colophon_history
      buf = ''
      buf << %Q(    <div class="pubhistory">\n)
      if @producer.config['history']
        @producer.config['history'].each_with_index do |items, edit|
          items.each_with_index do |item, rev|
            editstr = edit == 0 ? ReVIEW::I18n.t('first_edition') : ReVIEW::I18n.t('nth_edition', (edit + 1).to_s)
            revstr = ReVIEW::I18n.t('nth_impression', (rev + 1).to_s)
            if item =~ /\A\d+\-\d+\-\d+\Z/
              buf << %Q(      <p>#{ReVIEW::I18n.t('published_by1', [date_to_s(item), editstr + revstr])}</p>\n)
            elsif item =~ /\A(\d+\-\d+\-\d+)[\s　](.+)/
              # custom date with string
              item.match(/\A(\d+\-\d+\-\d+)[\s　](.+)/) do |m|
                buf << %Q(      <p>#{ReVIEW::I18n.t('published_by3', [date_to_s(m[1]), m[2]])}</p>\n)
              end
            else
              # free format
              buf << %Q(      <p>#{item}</p>\n)
            end
          end
        end
      else
        buf << %Q(      <p>#{ReVIEW::I18n.t('published_by2', date_to_s(@producer.config['date']))}</p>\n)
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
      @title = CGI.escapeHTML(@producer.res.v('toctitle'))

      @body = %Q(  <h1 class="toc-title">#{CGI.escapeHTML(@producer.res.v('toctitle'))}</h1>\n)
      if @producer.config['epubmaker']['flattoc'].nil?
        @body << hierarchy_ncx('ul')
      else
        @body << flat_ncx('ul', @producer.config['epubmaker']['flattocindent'])
      end

      @language = @producer.config['language']
      @stylesheets = @producer.config['stylesheet']
      tmplfile = if @producer.config['htmlversion'].to_i == 5
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
      toclevel = @producer.config['toclevel'].to_i

      # check part existance
      @producer.contents.each do |item|
        next if item.notoc || item.chaptype != 'part'

        has_part = true
        break
      end

      if has_part
        @producer.contents.each do |item|
          item.level += 1 if item.chaptype == 'part' || item.chaptype == 'body'
          item.notoc = true if (item.chaptype == 'pre' || item.chaptype == 'post') && !item.level.nil? && (item.level + 1 == toclevel) # FIXME: part processing
        end
        toclevel += 1
      end

      doc = REXML::Document.new(%Q(<#{type} class="toc-h#{level}"><li /></#{type}>))
      doc.context[:attribute_quote] = :quote

      e = doc.root.elements[1] # first <li/>
      @producer.contents.each do |item|
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
      @producer.contents.each do |item|
        next if !item.notoc.nil? || item.level.nil? || item.file.nil? || item.title.nil? || item.level > @producer.config['toclevel'].to_i
        is = indent == true ? '　' * item.level : ''
        s << %Q(<li><a href="#{item.file}">#{is}#{CGI.escapeHTML(item.title)}</a></li>\n)
      end
      s << %Q(</#{type}>\n)

      s
    end

    def produce_write_common(basedir, tmpdir)
      File.open("#{tmpdir}/mimetype", 'w') { |f| @producer.mimetype(f) }

      FileUtils.mkdir_p("#{tmpdir}/META-INF")
      File.open("#{tmpdir}/META-INF/container.xml", 'w') { |f| @producer.container(f) }

      FileUtils.mkdir_p("#{tmpdir}/OEBPS")
      File.open(File.join(tmpdir, opf_path), 'w') { |f| @producer.opf(f) }

      if File.exist?("#{basedir}/#{@producer.config['cover']}")
        FileUtils.cp("#{basedir}/#{@producer.config['cover']}", "#{tmpdir}/OEBPS")
      else
        File.open("#{tmpdir}/OEBPS/#{@producer.config['cover']}", 'w') { |f| @producer.cover(f) }
      end

      @producer.contents.each do |item|
        next if item.file =~ /#/ # skip subgroup
        fname = "#{basedir}/#{item.file}"
        raise "#{fname} doesn't exist. Abort." unless File.exist?(fname)
        FileUtils.mkdir_p(File.dirname("#{tmpdir}/OEBPS/#{item.file}"))
        FileUtils.cp(fname, "#{tmpdir}/OEBPS/#{item.file}")
      end
    end

    def legacy_cover_and_title_file(loadfile, writefile)
      @title = @producer.config['booktitle']
      s = ''
      File.open(loadfile) do |f|
        f.each_line do |l|
          s << l
        end
      end

      File.open(writefile, 'w') do |f|
        f.puts s
      end
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
