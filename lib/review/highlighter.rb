module ReVIEW
  module Highlighter
    def highlight(ops)
      body = ops[:body] || ''
      lexer = ops[:lexer] || ''
      format = ops[:format] || ''
      pygments_opts = ops[:pygments_opts] || nil
      # e.g. {style:'emacs'}

      if pygments_opts
        require 'pygments'
        Pygments.highlight(
                 body,
                 :options => {
                             :nowrap => true,
                             :noclasses => true,
                           }.merge(pygments_opts),
                 :formatter => format,
                 :lexer => lexer)
      else
        body
      end
    end
  end
end
