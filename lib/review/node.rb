require 'json'

module ReVIEW
  class Node
    attr_accessor :content

    def to_raw
      to_s_by(:to_raw)
    end

    def to_doc
      to_s_by(:to_doc)
    end

    def to_s_by(meth)
      if content.kind_of? String
        @content
      elsif content == nil
        nil
      elsif !content.kind_of? Array
        @content.__send__(meth)
      else
        ##@content.map(&meth).join("")
        @content.map{|o| o.__send__(meth)}.join("")
      end
    end

    def to_json
      if content.kind_of? String
        val = '"'+@content.gsub(/\"/,'\\"')+'"'
      elsif content == nil
        val = "null"
      elsif !content.kind_of? Array
        val = @content.to_json
      else
        val = "["+@content.map(&:to_json).join(",")+"]"
      end
      '{"t":"' + self.class.to_s.sub(/ReVIEW::/,"").sub(/Node$/,"") + '","c":' + val + '}'
    end

    def inspect
      self.to_json
    end

  end

  class HeadlineNode < Node

    def to_doc
      content_str = super
      cmd = @cmd ? @cmd.to_doc : nil
      label = @label
      @compiler.compile_headline(@level, cmd, label, content_str)
    end

    def to_json
      '{"t":"' + self.class.to_s.sub(/ReVIEW::/,"").sub(/Node$/,"") + '",' +
        %Q|"cmd":"#{@cmd.to_json}",|+
        %Q|"label":"#{@label.to_json}",|+
        '"c":' + @content.to_json + '}'
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
      @compiler.compile_command(@name, @args, content_lines, self)
    end

    def parse_args(*patterns)
      patterns.map.with_index do |pattern, i|
        if @args[i]
          @args[i].__send__("to_#{pattern}")
        else
          nil
        end
      end
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

    def to_json
      '{"t":"' + self.class.to_s.sub(/ReVIEW::/,"").sub(/Node$/,"") + '",' +
        %Q|"symbol":"#{@symbol}",| +
        '"c":[' + @content.map(&:to_json).join(",") + ']}'
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

  class ColumnNode < Node

    def to_doc
      level = @level
      label = @label
      caption = @caption ? @caption.to_doc : nil
      @compiler.compile_column(level, label, caption, @content)
    end
  end

end
