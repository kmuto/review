require 'lineinput'

module ReVIEW
  class LineInput < LineInput
    def skip_comment_lines
      n = 0
      while line = gets
        unless line.strip =~ /\A\#@/
          ungets line
          return n
        end
        n += 1
      end
      n
    end
  end
end
