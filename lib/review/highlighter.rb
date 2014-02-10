module ReVIEW
  module Highlighter
    def Highlighter::highlighter_opts(engine = :pygments, style = 'none')
      case engine
      when :pygments
        case style
        when nil, 'none'
          return nil
        when 'monochrome'
          return {:pygments_opts => {:style =>'bw'}}
        when 'color'
          return {:pygments_opts => {:style => 'default'}}
        else
          $stderr.puts "syntax-highlight must be none, monochrome, or color"
          exit 1
        end
      else
        $stderr.puts "highlight engine #{engine} is not supported"
        exit 1
      end
    end

    def highlight(ops)
      if @highlighter_opts and @highlighter_opts[:pygments_opts]
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
