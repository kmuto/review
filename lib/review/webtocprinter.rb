require 'review/tocprinter'
require 'review/i18n'
require 'review/htmlutils'

module ReVIEW
  class WEBTOCPrinter < TOCPrinter
    include HTMLUtils

    def self.book_to_string(book)
      ReVIEW::WEBTOCPrinter.new.print_book(book)
    end

    def print_book(book)
      @book = book
      @indent = nil
      @upper = 1 # only part and chapter
      print_result(build_result_array)
    end

    def print_result(result_array)
      content = <<EOT
<ul class="book-toc">
<li><a href="index.html">TOP</a></li>
EOT

      path = ''
      result_array.each do |result|
        unless result.headline
          result.headline = '-'
        end

        if result.name
          path = "#{result.name}.#{@book.config['htmlext']}"
          next
        end

        if result.part
          if result.part == 'end'
            content << "</ul></li>\n"
          end
          next
        end

        content << if path.start_with?('.')
                     "<li>#{escape(result.headline)}"
                   else
                     %Q(<li><a href="#{path}">#{escape(result.headline)}</a>)
                   end
        content << if result.level == 0
                     "\n<ul>" # part
                   else
                     "</li>\n"
                   end
      end
      content << "</ul>\n"
    end
  end
end
