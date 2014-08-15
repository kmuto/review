module ReVIEW
  class Node
    attr_accessor :content

    def to_raw
      if content.kind_of? String
        @content
      elsif !content.kind_of? Array
        @content.to_raw
      else
        @content.map{|o| o.to_raw}.join("")
      end
    end

    def to_doc
      if content.kind_of? String
        @content
      elsif !content.kind_of? Array
        @content.to_doc
      else
        @content.map{|o| o.to_doc}.join("")
      end
    end
  end

  class HeadlineNode < Node

    def to_doc
      content_str = super
      cmd = @cmd ? @cmd.to_doc : nil
      label = @label ? @label.to_doc : nil
      @compiler.compile_headline(@level, cmd, label, content_str)
    end
  end

  class ParagraphNode < Node

    def to_doc
      #content = @content.map(&:to_doc)
      content = super.split(/\n/)
      @compiler.compile_paragraph(content)
    end
  end

  class BlockElementNode < Node

    def to_doc
      # content_str = super
      args = @args.map(&:to_doc)
      if @content
        content_lines = @content.map(&:to_doc)
      else
        content_lines = nil
      end
      @compiler.compile_command(@name, args, content_lines)
    end
  end

  class InlineElementNode < Node

    def to_raw
      content_str = super
      "@<#{@symbol.to_s}>{#{content_str}}"
    end

    def to_doc
      #content_str = super
      @compiler.compile_inline(@symbol, @content)
    end
  end

  class InlineElementContentNode < Node
  end

  class TextNode < Node

    def to_raw
      content_str = super
      content_str.to_s
    end

    def to_doc
      content_str = super
      @compiler.compile_text(content_str)
    end
  end

  class RawNode < Node

    def to_doc
      @compiler.compile_raw(@builder, @content.join(""))
    end
  end

  class BracketArgNode < Node
  end

  class BraceArgNode < Node
  end

  class SinglelineCommentNode < Node
    def to_doc
      ""
    end
  end

  class SinglelineContentNode < Node
  end

  class UlistNode < Node
    def to_doc
      @compiler.compile_ulist(@content)
    end
  end

  class UlistElementNode < Node
    def to_doc
      @content.map(&:to_doc).join("")
    end

    def concat(elem)
      @content << elem
    end
  end

  class OlistNode < Node
    def to_doc
      @compiler.compile_olist(@content)
    end
  end

  class OlistElementNode < Node
    def to_doc
      @content.map(&:to_doc).join("")
    end

    def concat(elem)
      @content << elem
    end
  end

  class DlistNode < Node
    def to_doc
      @compiler.compile_dlist(@content)
    end
  end

  class DlistElementNode < Node
    def to_doc
      @content.map(&:to_doc).join("")
    end
  end

  class DocumentNode < Node
  end

  class TaggedSectionNode < Node

    def to_doc
      @compiler.compile_column(@content)
    end
  end

end
