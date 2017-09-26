require 'review/tocprinter'
require 'review/i18n'

module ReVIEW
  class WEBTOCPrinter < TOCPrinter
    include HTMLUtils

    def self.book_to_string(book)
      io = StringIO.new
      ReVIEW::WEBTOCPrinter.new(1, {}, io).print_book(book)
      io.seek(0)
      io.read
    end

    def print_book(book)
      @out.puts '<ul class="book-toc">'
      @out.puts %Q(<li><a href="index.html">TOP</a></li>\n)
      book.each_part do |part|
        print_part(part)
      end
      @out.puts '</ul>'
    end

    def print_part(part)
      if part.number
        if part.file?
          ext = part.book.config['htmlext'] || 'html'
          path = part.path.sub(/\.re/, '.' + ext)
          @out.puts %Q(<li><a href="#{path}">#{h(I18n.t('part_short', part.number) + ' ' + part.title)}</a>\n<ul>\n)
        else
          @out.puts %Q(<li>#{h(I18n.t('part_short', part.number) + ' ' + part.title)}\n<ul>\n)
        end
      end
      part.each_chapter { |chap| print_chapter(chap) }
      @out.puts "</ul>\n</li>\n" if part.number
    end

    def print_chapter(chap)
      chap_node = TOCParser.chapter_node(chap)
      ext = chap.book.config['htmlext'] || 'html'
      path = chap.path.sub(/\.re/, '.' + ext)
      label = if chap_node.number && chap.on_chaps?
                "#{I18n.t('chapter_short', chap.number)} #{chap.title}"
              else
                chap.title
              end
      @out.puts %Q(<li><a href="#{path}">#{h(label)}</a></li>\n)
    end
  end
end
