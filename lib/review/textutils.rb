# $Id: textutils.rb 2192 2005-11-13 11:55:42Z aamine $
require 'nkf'

module ReVIEW
  module TextUtils
    def detab(str, ts = 8)
      add = 0
      len = nil
      str.gsub(/\t/) do
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
        if element == ""
          if blocked_lines.last != []
            blocked_lines << []
          end
        else
          blocked_lines.last << element
        end
      end

      if !pre.nil? and !post.nil?
        blocked_lines.map!{|i| [pre] + i + [post] }
      end

      blocked_lines.map{|l| l.join("")}
    end
  end
end
