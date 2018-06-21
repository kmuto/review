require 'nkf'

module ReVIEW
  module TextUtils
    def detab(str, ts = 8)
      add = 0
      len = nil
      str.gsub("\t") do
        len = ts - ($`.size + add) % ts
        add += len - 1
        ' ' * len
      end
    end

    def split_paragraph(lines)
      pre = pre_paragraph
      post = post_paragraph
      trimmed_lines = trim_lines(lines)

      blocked_lines = [[]]
      trimmed_lines.each do |element|
        if element.empty?
          blocked_lines << [] if blocked_lines.last != []
        else
          blocked_lines.last << element
        end
      end

      if pre && post
        blocked_lines.map! { |i| [pre] + i + [post] }
      end
      blocked_lines.map(&:join)
    end

    private

    # remove elements at the back of `lines` if element is empty string
    # (`lines` should be Array of String.)
    #
    def trim_lines(lines)
      new_lines = lines.dup
      while new_lines[-1] && new_lines[-1].strip.empty?
        new_lines.pop
      end
      new_lines
    end
  end
end
