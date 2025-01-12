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
      @book.config['highlight'] &&
        @book.config['highlight']['html']
    end

    def highlight(ops)
      if @book.config['pygments'].present?
        raise ReVIEW::ConfigError, %Q('pygments:' in config.yml is obsoleted.)
      end
      return ops[:body].to_s unless highlight?

      if @book.config['highlight']['html'] == 'pygments'
        highlight_pygments(ops)
      elsif @book.config['highlight']['html'] == 'rouge'
        highlight_rouge(ops)
      else
        raise ReVIEW::ConfigError, "unknown highlight method #{@book.config['highlight']['html']} in config.yml."
      end
    end

    def highlight_pygments(ops)
      body = ops[:body] || ''
      format = ops[:format] || ''
      lexer = if ops[:lexer].present?
                ops[:lexer]
              elsif @book.config['highlight'] && @book.config['highlight']['lang']
                @book.config['highlight']['lang'] # default setting
              else
                'text'
              end
      options = { nowrap: true, noclasses: true }
      if ops[:linenum]
        options[:nowrap] = false
        options[:linenos] = 'inline'
      end
      if ops[:options] && ops[:options].is_a?(Hash)
        options.merge!(ops[:options])
      end

      begin
        require 'pygments'
        begin
          Pygments.highlight(body,
                             options: options,
                             formatter: format,
                             lexer: lexer)
        rescue MentosError
          body
        end
      rescue LoadError
        body
      end
    end

    def highlight_rouge(ops)
      body = ops[:body] || ''
      lexer = if ops[:lexer].present?
                ops[:lexer]
              elsif @book.config['highlight'] && @book.config['highlight']['lang']
                @book.config['highlight']['lang'] # default setting
              else
                'text'
              end
      # format = ops[:format] || ''

      first_line_num = 1 ## default
      if ops[:options] && ops[:options][:linenostart]
        first_line_num = ops[:options][:linenostart]
      end

      require 'rouge'
      lexer = Rouge::Lexer.find(lexer)

      unless lexer
        return body
      end

      formatter = Rouge::Formatters::HTML.new(css_class: 'highlight')
      if ops[:linenum]
        formatter = Rouge::Formatters::HTMLTable.new(formatter,
                                                     table_class: 'highlight rouge-table',
                                                     start_line: first_line_num)
      end

      unless formatter
        return body
      end

      formatter.format(lexer.lex(body))
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
