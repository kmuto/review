module ReVIEW
  module Highlighter
    def highlight(ops)
      if @highlighter_opts[:pygments_opts]
        return highlight_with_pygments(ops)
      end
      body = ops[:body] || ''
      return body
    end

    def highlight_with_pygments(ops)
      require 'pygments'
      body = ops[:body] || ''
      lexer = ops[:lexer] || ''
      format = ops[:format] || ''
      pygments_opts = @highlighter_opts[:pygments_opts]
      # e.g. {style:'emacs'}
      Pygments.highlight(
               body,
               :options => {
                           :nowrap => true,
                           :noclasses => true,
                         }.merge(pygments_opts),
               :formatter => format,
               :lexer => lexer)
    end
  end
end
