require 'lineinput'

module ReVIEW
  class LineInput < LineInput
    def skip_comment_lines
      n = 0
      while line = gets
        unless line.strip =~ /\A\#@/
          ungets(line)
          return n
        end
        n += 1
      end
      n
    end

    def gets
      unless @buf.empty?
        @lineno += 1
        return @buf.pop
      end
      return nil if @eof_p # to avoid ARGF blocking.
      line = @input.gets
      @eof_p = true unless line
      @lineno += 1
      if line =~ /[\x00-\x08]/ || line =~ /[\x0b-\x0c]/ || line =~ /[\x0e-\x1f]/
        # accept 0x09: TAB, 0x0a: LF, 0x0d: CR
        raise SyntaxError, "found invalid control-sequence character (#{sprintf('%#x', $&.codepoints[0])})."
      end
      line
    end
  end
end
