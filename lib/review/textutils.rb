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

      blocked_lines = [[]]
      lines.each do |element|
        if element.empty?
          blocked_lines << [] if blocked_lines.last != []
        else
          blocked_lines.last << element
        end
      end

      blocked_lines.map! { |i| [pre] + i + [post] } if pre && post
      blocked_lines.map(&:join)
    end
  end
end
