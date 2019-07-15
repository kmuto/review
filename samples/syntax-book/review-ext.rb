require 'review'

module ReVIEW
  class HTMLBuilder
    def inline_balloon(str)
      %Q(<span class="balloon">#{escape_html(str)}</span>)
    end
  end
  class LATEXBuilder
    def inline_balloon(str)
      %Q(←#{escape(str)})
    end
  end
  class IDGXMLBuilder
    Compiler.definline(:strong)
    Compiler.definline(:em)

    def inline_strong(str)
      str
    end

    def inline_em(str)
      str
    end
  end
end
