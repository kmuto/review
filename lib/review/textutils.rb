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

  end

end
