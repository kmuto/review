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

    def highlight?
      @book.config["pygments"].present? ||
        @book.config["highlight"] && @book.config["highlight"]["html"] == "pygments"
    end

    def highlight(ops)
      body = ops[:body] || ''
      if @book.config["highlight"] && @book.config["highlight"]["lang"]
        lexer = @book.config["highlight"]["lang"] # default setting
      else
        lexer = 'text'
      end
      lexer = ops[:lexer] if ops[:lexer].present?
      format = ops[:format] || ''
      options = {:nowrap => true, :noclasses => true}
      if ops[:options] && ops[:options].kind_of?(Hash)
        options.merge!(ops[:options])
      end
      return body if !highlight?

      begin
        require 'pygments'
        begin
          Pygments.highlight(
                   unescape_html(body),
                   :options => options,
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
      if id =~ /\A[a-z][a-z0-9_.-]*\Z/i
        return id
      elsif id =~ /\A[0-9_.-][a-z0-9_.-]*\Z/i
        return "id_#{id}" # dummy prefix
      else
        return "id_#{CGI.escape(id.gsub("_", "__")).gsub("%", "_").gsub("+", "-")}" # escape all
      end
    end
  end

end # module ReVIEW
