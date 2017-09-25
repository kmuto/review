#
# Copyright (c) 2006-2017 Minero Aoki, Kenshi Muto
#               2002-2006 Minero Aoki
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

require 'cgi/util'
module ReVIEW
  module HTMLUtils
    ESC = {
      '&' => '&amp;',
      '<' => '&lt;',
      '>' => '&gt;',
      '"' => '&quot;'
    } # .freeze

    def escape_html(str)
      t = ESC
      str.gsub(/[&"<>]/) { |c| t[c] }
    end

    alias_method :escape, :escape_html
    alias_method :h, :escape_html

    def unescape_html(str)
      # FIXME: better code
      str.gsub('&quot;', '"').gsub('&gt;', '>').gsub('&lt;', '<').gsub('&amp;', '&')
    end

    alias_method :unescape, :unescape_html

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
      if @book.config['highlight'] && @book.config['highlight']['lang']
        lexer = @book.config['highlight']['lang'] # default setting
      else
        lexer = 'text'
      end
      lexer = ops[:lexer] if ops[:lexer].present?
      format = ops[:format] || ''
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
          Pygments.highlight(unescape_html(body),
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
      if ops[:lexer].present?
        lexer = ops[:lexer]
      elsif @book.config['highlight'] && @book.config['highlight']['lang']
        lexer = @book.config['highlight']['lang'] # default setting
      else
        lexer = 'text'
      end
      # format = ops[:format] || ''

      first_line_num = 1 ## default
      if ops[:options] && ops[:options][:linenostart]
        first_line_num = ops[:options][:linenostart]
      end

      require 'rouge'
      lexer = Rouge::Lexer.find(lexer)
      raise "unknown lexer #{lexer}" unless lexer

      formatter = Rouge::Formatters::HTML.new(css_class: 'highlight')
      if ops[:linenum]
        formatter = Rouge::Formatters::HTMLTable.new(formatter,
                                                     table_class: 'highlight rouge-table',
                                                     start_line: first_line_num)
      end
      raise "unknown formatter #{formatter}" unless formatter

      text = unescape_html(body)
      formatter.format(lexer.lex(text))
    end

    def normalize_id(id)
      if id =~ /\A[a-z][a-z0-9_.-]*\Z/i
        id
      elsif id =~ /\A[0-9_.-][a-z0-9_.-]*\Z/i
        "id_#{id}" # dummy prefix
      else
        "id_#{CGI.escape(id.gsub('_', '__')).gsub('%', '_').gsub('+', '-')}" # escape all
      end
    end
  end
end # module ReVIEW
