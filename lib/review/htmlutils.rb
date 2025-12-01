# frozen_string_literal: true

#
# Copyright (c) 2006-2018 Minero Aoki, Kenshi Muto
#               2002-2006 Minero Aoki
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

begin
  require 'cgi/escape'
rescue StandardError
  require 'cgi/util'
end

require 'review/highlighter'

module ReVIEW
  module HTMLUtils
    def escape(str)
      CGI.escapeHTML(str)
    end

    alias_method :escape_html, :escape # for backward compatibility
    alias_method :h, :escape

    def unescape(str)
      # FIXME: better code
      str.gsub('&quot;', '"').gsub('&gt;', '>').gsub('&lt;', '<').gsub('&amp;', '&')
    end

    alias_method :unescape_html, :unescape # for backward compatibility

    def strip_html(str)
      str.gsub(%r{</?[^>]*>}, '')
    end

    def escape_comment(str)
      str.gsub('-', '&#45;')
    end

    def highlight?
      highlighter.highlight?('html')
    end

    def highlight(ops)
      if @book.config['pygments'].present?
        raise ReVIEW::ConfigError, %Q('pygments:' in config.yml is obsoleted.)
      end

      highlighter.highlight(
        body: ops[:body],
        lexer: ops[:lexer],
        format: 'html',
        linenum: ops[:linenum],
        options: ops[:options] || {}
      )
    end

    private

    def highlighter
      @highlighter ||= ReVIEW::Highlighter.new(@book.config)
    end

    def normalize_id(id)
      if /\A[a-z][a-z0-9_.-]*\Z/i.match?(id)
        id
      elsif /\A[0-9_.-][a-z0-9_.-]*\Z/i.match?(id)
        "id_#{id}" # dummy prefix
      else
        "id_#{CGI.escape(id.gsub('_', '__')).tr('%', '_').tr('+', '-')}" # escape all
      end
    end
  end
end # module ReVIEW
