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

    alias_method :escape, :escape_html

    def unescape_html(str)
      # FIXME better code
      str.gsub('&quot;', '"').gsub('&gt;', '>').gsub('&lt;', '<').gsub('&amp;', '&')
    end

    alias_method :unescape, :unescape_html

    def strip_html(str)
      str.gsub(/<\/?[^>]*>/, "")
    end

    def escape_comment(str)
      str.gsub('-', '&#45;')
    end

    def highlight(ops)
      body = ops[:body] || ''
      lexer = ops[:lexer] || ''
      format = ops[:format] || ''

      return body if ReVIEW.book.param["pygments"].nil?

      begin
        require 'pygments'
        begin
          Pygments.highlight(
                   unescape_html(body),
                   :options => {
                               :nowrap => true,
                               :noclasses => true
                             },
                   :formatter => format,
                   :lexer => lexer)
        rescue MentosError
          body
        end
      rescue LoadError
          body
      end
    end

    def normalize_id(id)
      if id =~ /\A[a-z][a-z0-9_:.-]*\Z/i
        return id
      elsif id =~ /\A[0-9_:.-][a-z0-9_:.-]*\Z/i
        return "id:#{id}" # dummy prefix
      else
        return "id:#{CGI.escape(id.gsub("_", "__")).gsub("%", "_").gsub("+", ":")}" # escape all
      end
    end
  end

end   # module ReVIEW
