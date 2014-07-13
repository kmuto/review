module ReVIEW
  class Node
    attr_accessor :content

    def to_s
      if !content.kind_of? Array
        @content.to_s
      else
        @content.map{|o| o.to_s}.join("")
      end
    end
  end

  class HeadlineNode < Node

    def to_s
      content_str = super
      @compiler.compile_headline(@level, @cmd, @label, content_str)
    end
  end

  class ParagraphNode < Node

    def to_s
      #content = @content.map(&:to_s)
      content = super
      @compiler.compile_paragraph(content)
    end
  end

  class BlockElementNode < Node

    def to_s
      # content_str = super
      args = @args.map(&:to_s)
      content_lines = @content.map(&:to_s)
      @compiler.compile_command(@name, args, content_lines)
    end
  end

  class InlineElementNode < Node

    def to_s
      #content_str = super
      @compiler.compile_inline(@symbol, @content.map(&:to_s))
    end
  end

  class InlineElementContentNode < Node
  end

  class TextNode < Node

    def to_s
      content_str = super
      @compiler.compile_text(content_str)
    end
  end

  class RawNode < Node

    def to_s
      content_str = super
      @compiler.compile_raw(@builder, content_str)
    end
  end

  class BracketArgNode < Node
  end

  class BraceArgNode < Node
  end

  class SinglelineCommentNode < Node
  end

  class SinglelineContentNode < Node
  end

  class UlistNode < Node
    def to_s
      @compiler.compile_ulist(@content)
    end
  end

  class UlistElementNode < Node
    def to_s
      @content.map(&:to_s).join("")
    end

    def concat(elem)
      @content << elem
    end
  end

  class OlistNode < Node
    def to_s
      @compiler.compile_olist(@content)
    end
  end

  class OlistElementNode < Node
    def to_s
      str = @content.map(&:to_s).join("")
      str
    end

    def concat(elem)
      @content << elem
    end
  end

  class DlistNode < Node
  end

  class DlistElementNode < Node
    def initialize(compiler, text, content)
      @compiler, @text, @content = compiler, text, content
    end
  end
end
