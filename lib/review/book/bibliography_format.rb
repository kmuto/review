begin
  require 'citeproc'
  require 'citeproc/ruby'
rescue LoadError
  # raise ReVIEW::ConfigError inside the class
end

# https://github.com/inukshuk/citeproc-ruby
module CiteProc
  module Ruby
    module Formats
      class Html
      end

      class Latex
        def bibliography(bibliography)
          bibliography.header = "\\begin{description}"
          bibliography.footer = "\\end{description}"

          bibliography.prefix = "\\item[] "
          bibliography.suffix = ""

          bibliography.connector = "\n"
          bibliography
        end
      end
    end
  end
end
