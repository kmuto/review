#
# Copyright (c) 2018-2019 Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".

require 'zip'
require 'rexml/document'
require 'optparse'
require 'review/version'

begin
  require 'cgi/escape'
rescue StandardError
  require 'cgi/util'
end

module ReVIEW
  class Epub2Html
    def self.execute(*args)
      new.execute(*args)
    end

    def execute(*args)
      opts = OptionParser.new

      opts.banner = <<EOT
Usage: review-epub2html [options] EPUBfile [file_for_head_and_foot] > HTMLfile
       file_for_head_and_foot: HTML file to extract header and footer area.
                               This file must be contained in the EPUB.
                               If omitted, the first found file is used.

EOT
      opts.version = ReVIEW::VERSION
      opts.on('--help', 'Prints this message and quit.') do
        puts opts.help
        exit 0
      end
      opts.on('--inline-footnote', 'Embed footnote blocks in paragraph.') { @inline_footnote = true }

      opts.parse!(args)

      if args[0].nil? || !File.exist?(args[0])
        puts opts.help
        exit 1
      end

      htmls = parse_epub(args[0])
      puts join_html(args[1], htmls)
    end

    def initialize
      @opfxml = nil
      @inline_footnote = nil
    end

    def parse_epub(epubname)
      htmls = {}
      Zip::File.open(epubname) do |zio|
        zio.each do |entry|
          if /.+\.opf\Z/.match?(entry.name)
            opf = entry.get_input_stream.read
            @opfxml = REXML::Document.new(opf)
          elsif /.+\.x?html\Z/.match?(entry.name)
            htmls[File.basename(entry.name)] = entry.get_input_stream.read.force_encoding('utf-8')
          end
        end
      end
      htmls
    end

    def take_headtail(html)
      head = html.sub(/(<body.*?>).*/m, '\1')
      tail = html.sub(%r{.*(</body>)}m, '\1')

      [head, tail]
    end

    def sanitize(s)
      s = s.sub(/\.x?html\Z/, '').
          sub(%r{\A\./}, '')
      's_' + CGI.escape(s).
             gsub(/[.,+%]/, '_')
    end

    def modify_html(fname, html)
      doc = REXML::Document.new(html)
      doc.context[:attribute_quote] = :quote

      ids = {}

      doc.each_element('//*[@id]') do |e|
        sid = "#{sanitize(fname)}_#{sanitize(e.attributes['id'])}"
        while ids[sid]
          sid += 'E'
        end
        ids[sid] = true
        e.attributes['id'] = sid
      end

      doc.each_element('//a[@href]') do |e|
        href = e.attributes['href']
        if href.start_with?('http:', 'https:', 'ftp:', 'ftps:', 'mailto:')
          next
        end

        file, anc = href.split('#', 2)
        anc = if anc
                if file.empty?
                  "#{sanitize(fname)}_#{sanitize(anc)}"
                else
                  "#{sanitize(file)}_#{sanitize(anc)}"
                end
              else
                sanitize(file)
              end

        e.attributes['href'] = "##{anc}"
      end

      if @inline_footnote
        # move footnotes to inline as same as LaTeX.
        footnotes = {}

        doc.each_element("//div[@class='footnote']") do |e|
          e.name = 'span'
          e.attributes.delete('epub:type')
          footnotes[e.attributes['id']] = e
          e.remove
        end

        doc.each_element("//a[@class='noteref']") do |e|
          e.parent.insert_after(e, footnotes[e.attributes['href'].sub('#', '')])
          e.remove
        end
      end

      doc.to_s.
        sub(/.*(<body.*?>)/m, %Q(<section id="#{sanitize(fname)}">)).
        sub(%r{(</body>).*}m, '</section>')
    end

    def join_html(reffile, htmls)
      head = tail = nil
      body = []
      make_list.each do |href_value|
        fname = File.basename(href_value)
        if head.nil? && (reffile.nil? || reffile == fname)
          head, tail = take_headtail(htmls[fname])
        end

        body << modify_html(fname, htmls[fname])
      end
      "#{head}\n#{body.join("\n")}\n#{tail}"
    end

    def make_list
      items = {}
      @opfxml.each_element("/package/manifest/item[@media-type='application/xhtml+xml']") do |e|
        items[e.attributes['id']] = e.attributes['href']
      end

      files = []
      @opfxml.each_element('/package/spine/itemref') do |e|
        files.push(items[e.attributes['idref']])
      end

      files
    end
  end
end
