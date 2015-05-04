# encoding: utf-8
# = epubcommon.rb -- super class for EPUBv2 and EPUBv3
#
# Copyright (c) 2010-2014 Kenshi Muto and Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
#

require 'epubmaker/producer'
require 'review/i18n'
require 'cgi'
require 'shellwords'

module EPUBMaker
  # EPUBCommon is the common class for EPUB producer.
  class EPUBCommon
    # Construct object with parameter hash +params+ and message resource hash +res+.
    def initialize(producer)
      @producer = producer
    end

    # Return mimetype content.
    def mimetype
      'application/epub+zip'
    end

    def opf_coverimage
      s = ''
      if @producer.params['coverimage']
        file = nil
        @producer.contents.each do |item|
          if item.media =~ /\Aimage/ && item.file =~ /#{@producer.params["coverimage"]}\Z/
            s << %(    <meta name="cover" content="#{item.id}"/>\n)
            file = item.file
            break
          end
        end
        fail "coverimage #{@producer.params['coverimage']} not found. Abort." unless file
      end
      s
    end

    def ncx_isbn
      uid = @producer.params['isbn'] ? @producer.params['isbn'] : @producer.params['urnid']
      %(    <meta name="dtb:uid" content="#{uid}"/>\n)
    end

    def ncx_doctitle
      <<EOT
  <docTitle>
    <text>#{CGI.escapeHTML(@producer.params['title'])}</text>
  </docTitle>
  <docAuthor>
    <text>#{@producer.params['aut'].nil? ? '' : CGI.escapeHTML(@producer.params['aut'].join(', '))}</text>
  </docAuthor>
EOT
    end

    def ncx_navmap(indentarray)
      s = <<EOT
  <navMap>
    <navPoint id="top" playOrder="1">
      <navLabel>
        <text>#{CGI.escapeHTML(@producer.params['title'])}</text>
      </navLabel>
      <content src="#{@producer.params['cover']}"/>
    </navPoint>
EOT

      nav_count = 2

      if @producer.params['mytoc']
        s << <<EOT
    <navPoint id="toc" playOrder="#{nav_count}">
      <navLabel>
        <text>#{@producer.res.v('toctitle')}</text>
      </navLabel>
      <content src="#{@producer.params['bookname']}-toc.#{@producer.params['htmlext']}"/>
    </navPoint>
EOT
        nav_count += 1
      end

      @producer.contents.each do |item|
        next unless item.title
        indent = indentarray || ['']
        level = (item.level || 1) - 1
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
      s = <<EOT
<?xml version="1.0" encoding="UTF-8"?>
<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container" version="1.0">
  <rootfiles>
    <rootfile full-path="OEBPS/#{@producer.params['bookname']}.opf" media-type="application/oebps-package+xml" />
  </rootfiles>
</container>
EOT
      s
    end

    # Return cover content.
    def cover(type = nil)
      bodyext = type ? " epub:type=\"#{type}\"" : ''

      s = common_header
      s << <<EOT
  <title>#{CGI.escapeHTML(@producer.params['title'])}</title>
</head>
<body#{bodyext}>
EOT
      if @producer.params['coverimage']
        file = nil
        @producer.contents.each do |item|
          if item.media =~ /\Aimage/ && item.file =~ /#{@producer.params["coverimage"]}\Z/ # /
            file = item.file
            break
          end
        end
        fail "coverimage #{@producer.params['coverimage']} not found. Abort." if file.nil?
        s << <<EOT
  <div id="cover-image" class="cover-image">
    <img src="#{file}" alt="#{CGI.escapeHTML(@producer.params['title'])}" class="max"/>
  </div>
EOT
      else
        s << <<EOT
<h1 class="cover-title">#{CGI.escapeHTML(@producer.params['title'])}</h1>
EOT
      end

      s << <<EOT
</body>
</html>
EOT
      s
    end

    # Return title (copying) content.
    def titlepage
      s = common_header
      s << <<EOT
  <title>#{CGI.escapeHTML(@producer.params['title'])}</title>
</head>
<body>
  <h1 class="tp-title">#{CGI.escapeHTML(@producer.params['title'])}</h1>
EOT

      if @producer.params['aut']
        s << <<EOT
  <p>
    <br />
    <br />
  </p>
  <h2 class="tp-author">#{CGI.escapeHTML(@producer.params['aut'].join(', '))}</h2>
EOT
      end

      publisher = @producer.params['pbl'] || @producer.params['prt'] # XXX Backward Compatiblity
      if publisher
        s << <<EOT
  <p>
    <br />
    <br />
    <br />
    <br />
  </p>
  <h3 class="tp-publisher">#{CGI.escapeHTML(publisher.join(', '))}</h3>
EOT
      end

      s << <<EOT
</body>
</html>
EOT

      s
    end

    # Return colophon content.
    def colophon
      s = common_header
      s << <<EOT
  <title>#{@producer.res.v('colophontitle')}</title>
</head>
<body>
  <div class="colophon">
EOT

      if @producer.params['subtitle']
        s << <<EOT
    <p class="title">#{CGI.escapeHTML(@producer.params['title'])}<br /><span class="subtitle">#{CGI.escapeHTML(@producer.params['subtitle'])}</span></p>
EOT
      else
        s << <<EOT
    <p class="title">#{CGI.escapeHTML(@producer.params['title'])}</p>
EOT
      end

      if @producer.params['date'] || @producer.params['history']
        s << %(    <div class="pubhistory">
)
        if @producer.params['history']
          @producer.params['history'].each_with_index do |items, edit|
            items.each_with_index do |item, rev|
              editstr = (edit == 0) ? ReVIEW::I18n.t('first_edition') : ReVIEW::I18n.t('nth_edition', "#{edit + 1}")
              revstr = ReVIEW::I18n.t('nth_impression', "#{rev + 1}")
              if item =~ /\A\d+\-\d+\-\d+\Z/
                s << %(      <p>#{ReVIEW::I18n.t('published_by1', [date_to_s(item), editstr + revstr])}</p>\n)
              else
                # custom date with string
                item.match(/\A(\d+\-\d+\-\d+)[\s　](.+)/) do |m|
                  s << %(      <p>#{ReVIEW::I18n.t('published_by3', [date_to_s(m[1]), m[2]])}</p>\n)
                end
              end
            end
          end
        else
          s << %(      <p>#{ReVIEW::I18n.t('published_by2', date_to_s(@producer.params['date']))}</p>\n)
        end
        s << %(    </div>
)
      end

      s << %(    <table class="colophon">
)
      %w(aut csl trl dsr ill edt pbl prt pht).each do |key|
        s << %(      <tr><th>#{@producer.res.v(key)}</th><td>#{CGI.escapeHTML(@producer.params[key].join(', '))}</td></tr>\n) if @producer.params[key]
      end

      if @producer.params['isbn'].to_s =~ /\A\d{10}\Z/ || @producer.params['isbn'].to_s =~ /\A\d{13}\Z/
        isbn = nil
        str = @producer.params['isbn'].to_s
        if str.size == 10
          isbn = "#{str[0..0]}-#{str[1..5]}-#{str[6..8]}-#{str[9..9]}"
        else
          isbn = "#{str[0..2]}-#{str[3..3]}-#{str[4..8]}-#{str[9..11]}-#{str[12..12]}"
        end
        s << %(      <tr><th>ISBN</th><td>#{isbn}</td></tr>\n)
      end
      s << <<EOT
    </table>
EOT
      if !@producer.params['rights'].nil? && @producer.params['rights'].size > 0
        s << %(    <p class="copyright">#{@producer.params['rights'].join('<br />')}</p>)
      end

      s << <<EOT
  </div>
</body>
</html>
EOT
      s
    end

    def date_to_s(date)
      require 'date'
      d = Date.parse(date)
      d.strftime(ReVIEW::I18n.t('date_format'))
    end

    # Return own toc content.
    def mytoc
      s = common_header
      s << <<EOT
  <title>#{@producer.res.v('toctitle')}</title>
</head>
<body>
  <h1 class="toc-title">#{@producer.res.v('toctitle')}</h1>
EOT

      if @producer.params['epubmaker']['flattoc']
        s << flat_ncx('ul', @producer.params['epubmaker']['flattocindent'])
      else
        s << hierarchy_ncx('ul')
      end

      s << <<EOT
</body>
</html>
EOT
      s
    end

    def hierarchy_ncx(type)
      require 'rexml/document'
      level = 1
      find_jump = nil
      has_part = nil
      toclevel = @producer.params['toclevel'].to_i

      # check part existance
      @producer.contents.each do |item|
        if item.notoc.nil? && item.chaptype == 'part'
          has_part = true
          break
        end
      end

      if has_part
        @producer.contents.each do |item|
          item.level += 1 if item.chaptype == 'part' || item.chaptype == 'body'
          item.notoc = true if (item.chaptype == 'pre' || item.chaptype == 'post') && item.level && (item.level + 1 == toclevel) # FIXME: 部があるときに前後の処理が困難
        end
        toclevel += 1
      end

      doc = REXML::Document.new(%(<#{type} class="toc-h#{level}"><li /></#{type}>))
      doc.context[:attribute_quote] = :quote

      e = doc.root.elements[1] # first <li/>
      @producer.contents.each do |item|
        next if item.notoc || !item.level || !item.file || !item.title || item.level > toclevel

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
          (level - 1).downto(item.level) do |n|
            e = e.parent.parent
          end
          e2 = e.parent.add_element('li')
          e = e2
          level = item.level
        end
        e2 = e.add_element('a', 'href' => item.file)
        e2.add_text(REXML::Text.new(item.title, true))
      end

      warn "found level jumping in table of contents. consider to use 'epubmaker:flattoc: true' for strict ePUB validator." if find_jump

      doc.to_s.gsub('<li/>', '').gsub('</li>', "</li>\n").gsub("<#{type} ", "\n" + '\&') # ugly
    end

    def flat_ncx(type, indent = nil)
      s = %(<#{type} class="toc-h1">\n)
      @producer.contents.each do |item|
        next if item.notoc || !item.level || !item.file || !item.title || item.level > @producer.params['toclevel'].to_i
        is = indent ? '　' * item.level : ''
        s << %(<li><a href="#{item.file}">#{is}#{CGI.escapeHTML(item.title)}</a></li>\n)
      end
      s << %(</#{type}>\n)

      s
    end

    def produce_write_common(basedir, tmpdir)
      File.open("#{tmpdir}/mimetype", 'w') { |f| @producer.mimetype(f) }

      FileUtils.mkdir_p("#{tmpdir}/META-INF")
      File.open("#{tmpdir}/META-INF/container.xml", 'w') { |f| @producer.container(f) }

      FileUtils.mkdir_p("#{tmpdir}/OEBPS")
      File.open("#{tmpdir}/OEBPS/#{@producer.params['bookname']}.opf", 'w') { |f| @producer.opf(f) }

      if File.exist?("#{basedir}/#{@producer.params['cover']}")
        FileUtils.cp("#{basedir}/#{@producer.params['cover']}", "#{tmpdir}/OEBPS")
      else
        File.open("#{tmpdir}/OEBPS/#{@producer.params['cover']}", 'w') { |f| @producer.cover(f) }
      end

      @producer.contents.each do |item|
        next if item.file =~ /#/ # skip subgroup
        fname = "#{basedir}/#{item.file}"
        fail "#{fname} doesn't exist. Abort." unless File.exist?(fname)
        FileUtils.mkdir_p(File.dirname("#{tmpdir}/OEBPS/#{item.file}"))
        FileUtils.cp(fname, "#{tmpdir}/OEBPS/#{item.file}")
      end
    end

    def export_zip(tmpdir, epubfile)
      Dir.chdir(tmpdir) { |d| `#{@producer.params['epubmaker']['zip_stage1']} #{epubfile.shellescape} mimetype` }
      Dir.chdir(tmpdir) { |d| `#{@producer.params['epubmaker']['zip_stage2']} #{epubfile.shellescape} META-INF OEBPS #{@producer.params['epubmaker']['zip_addpath']}` }
    end

    def legacy_cover_and_title_file(loadfile, writefile)
      s = common_header
      s << <<EOT
  <title>#{@producer.params['booktitle']}</title>
</head>
<body>
EOT
      File.open(loadfile) do |f|
        f.each_line do |l|
          s << l
        end
      end
      s << <<EOT
</body>
</html>
EOT

      File.open(writefile, 'w') do |f|
        f.puts s
      end
    end
  end
end
