require 'review'
require 'review/tocprinter'

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
      @out.puts "<li><a href=\"index.html\">TOP</a></li>\n"
      book.each_part do |part|
        print_part(part)
      end
      @out.puts '</ul>'
    end

    def print_part(part)
      if part.number
        @out.puts "<li>#{h(part.title)}\n<ul>\n"
      end
      part.each_chapter do |chap|
        print_chapter(chap)
      end
      if part.number
        @out.puts "</ul>\n</li>\n"
      end
    end

    def print_chapter(chap)
      chap_node = TOCParser.chapter_node(chap)
      ext = chap.book.config["htmlext"] || "html"
      path = chap.path.sub(/\.re/, "."+ext)
      if chap_node.number && chap.on_CHAPS?
        label = "#{chap.number} #{chap.title}"
      else
        label = chap.title
      end
      @out.puts "<li><a href=\"#{path}\">#{h(label)}</a></li>\n"
    end

  end
end
