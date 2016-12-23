#
# $Id: htmlutils.rb 2227 2006-05-13 00:09:08Z aamine $
#
# Copyright (c) 2002-2006 Minero Aoki
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

require 'cgi/util'
require 'rouge'
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
    alias_method :h, :escape_html

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
      @book.config["highlight"] &&
        @book.config["highlight"]["html"]
    end

    def highlight(ops)
      if @book.config["pygments"].present?
        raise ReVIEW::ConfigError, "'pygments:' in config.yml is obsoleted."
      end
      return ops[:body].to_s if !highlight?

      if @book.config["highlight"]["html"] == "pygments"
        highlight_pygments(ops)
      elsif @book.config["highlight"]["html"] == "rouge"
        highlight_rouge(ops)
      else
        raise ReVIEW::ConfigError, "unknown highlight method #{@book.config["highlight"]["html"]} in config.yml."
      end
    end

    def highlight_pygments(ops)
      body = ops[:body] || ''
      if @book.config["highlight"] && @book.config["highlight"]["lang"]
        lexer = @book.config["highlight"]["lang"] # default setting
      else
        lexer = 'text'
      end
      lexer = ops[:lexer] if ops[:lexer].present?
      format = ops[:format] || ''
      options = {:nowrap => true, :noclasses => true}
      if ops[:linenum]
        options[:nowrap] = false
        options[:linenos] = 'inline'
      end
      if ops[:options] && ops[:options].kind_of?(Hash)
        options.merge!(ops[:options])
      end

      begin
        require 'pygments'
        begin
          Pygments.highlight(unescape_html(body),
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

    def highlight_rouge(ops)
      body = ops[:body] || ''
      if ops[:lexer].present?
        lexer = ops[:lexer]
      elsif @book.config["highlight"] && @book.config["highlight"]["lang"]
        lexer = @book.config["highlight"]["lang"] # default setting
      else
        lexer = 'text'
      end
      format = ops[:format] || ''

      lexer = Rouge::Lexer.find(lexer)
      raise "unknown lexer #{lexer}" unless lexer

      #formatter = Rouge::Formatters::HTML.new()
      formatter = Rouge::Formatters::HTML.new(:css_class => 'highlight')
      if ops[:linenum]
        formatter = Rouge::Formatters::HTMLTable.new(formatter, :code_class => 'highlight rouge-code')
      end
      #formatter = Rouge::Formatters::HTMLLegacy.new(:css_class => "highlight #{lexer.tag}")
      #formatter = Rouge::Formatters::HTMLPygments.new(Rouge::Formatters::HTML.new, "highlight #{lexer.tag}")
      #formatter = Rouge::Formatters::HTMLInline.new(Rouge::Themes::Colorful.new)
      raise "unknown formatter #{formatter}" unless formatter

      text = unescape_html(body)
      formatter.format(lexer.lex(text))
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
