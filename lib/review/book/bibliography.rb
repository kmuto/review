begin
  require 'bibtex'
  require 'citeproc'
  require 'csl/styles'
rescue LoadError
  # raise ReVIEW::ConfigError inside the class
end

module ReVIEW
  module Book
    class Bibliography
      def initialize(bibfile, config = nil)
        @bibtex = BibTeX.parse(bibfile, filter: :latex)
        @config = config
        format('text')
      rescue NameError
        raise ReVIEW::ConfigError, 'not found bibtex libraries. disabled bibtex feature.'
      end

      def format(format)
        style = @config['bib-csl-style'] || 'acm-siggraph'
        @citeproc = CiteProc::Processor.new(style: style, format: format)
        @citeproc.import(@bibtex.to_citeproc)
        self
      rescue NameError
        raise ReVIEW::ConfigError, 'not found bibtex libraries. disabled bibtex feature.'
      end

      def ref(key)
        cited = @citeproc.render(:citation, id: key)

        # FIXME: need to apply CSL style
        if cited == ''
          idx = 1
          @citeproc.bibliography.ids.each do |i|
            if i == key
              cited = "[#{idx}]"
              break
            end
            idx += 1
          end
        end

        cited
      end

      def list
        @citeproc.bibliography.join
      end
    end
  end
end
