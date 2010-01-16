#
# $Id: htmlutils.rb 2227 2006-05-13 00:09:08Z aamine $
#
# Copyright (c) 2002-2006 Minero Aoki
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

module ReVIEW

  module HTMLUtils
    ESC = {
      '&' => '&amp;',
      '<' => '&lt;',
      '>' => '&gt;',
      '"' => '&quot;'
    }

    def escape_html(str)
      t = ESC
      str.gsub(/[&"<>]/) {|c| t[c] }
    end
  end

end   # module ReVIEW
