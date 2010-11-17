# $Id: textutils.rb 2192 2005-11-13 11:55:42Z aamine $

module ReVIEW

  module TextUtils

    def detab(str, ts = 8)
      add = 0
      len = nil
      str.gsub(/\t/) {
        len = ts - ($`.size + add) % ts
        add += len - 1
        ' ' * len
      }
    end

    def split_paragraph(lines)
      if [ReVIEW::IDGXMLBuilder, ReVIEW::HTMLBuilder].include?(self.class)
        pre = "<p>"
        post = "</p>"
      else
        pre = nil
        post = nil
      end

      blocked_lines = lines.inject([[]]) {|results, element|
        if element == ""
          results << []
        else
          results.last << element
        end
        results
      }

      if !pre.nil? and !post.nil?
        blocked_lines.map!{|i| [pre] + i + [post] }
      end

      blocked_lines
    end

  end

end
