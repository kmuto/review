begin
  require 'bibtex'
  require 'citeproc'
  require 'csl/styles'
  require 'review/book/bibliography_format'
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

      def ref(keys)
        authors = []
        keys.split(',').each do |key|
          authors << { id: key.strip }
        end

        cited = @citeproc.render(:citation, authors)

        # FIXME: need to apply CSL style
        if cited.gsub(/[\[\]()\s,]/, '') == ''
          refnums = []
          refnames = authors.map(&:values).flatten
          @citeproc.bibliography.ids.each_with_index do |key, idx|
            if refnames.include?(key)
              refnums << (idx + 1)
            end
          end
          cited = "[#{refnums.join(', ')}]"
        end

        cited
      end

      def list
        b = @citeproc.bibliography
        content = []
        b.references.each_with_index do |r, _idx|
          content << [b.prefix, r, b.suffix].compact.join
        end
        [
          b.header,
          content.join(b.connector),
          b.footer
        ].compact.join(b.connector)
      end
    end
  end
end
