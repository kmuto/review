# $Id: textutils.rb 2192 2005-11-13 11:55:42Z aamine $
require 'nkf'

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

    def convert_inencoding(str, enc)
      case enc
      when /^EUC$/i
        NKF.nkf("-E -w -m0x", str)
      when /^SJIS$/i
        NKF.nkf("-S -w -m0x", str)
      when /^JIS$/i
        NKF.nkf("-J -w -m0x", str)
      when /^UTF-8$/i
        NKF.nkf("-W -w -m0x", str)
      else
        NKF.nkf("-w -m0 -m0x", str)
      end
    end

    def convert_outencoding(str, enc)
      case enc
      when /^EUC$/i
        NKF.nkf("-W -e -m0x", str)
      when /^SJIS$/i
        NKF.nkf("-W -s -m0x", str)
      when /^JIS$/i
        NKF.nkf("-W -j -m0x", str)
      else
        str
      end
    end
  end
end
