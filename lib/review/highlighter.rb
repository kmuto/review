# frozen_string_literal: true

# Copyright (c) 2025 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/loggable'
require 'review/exception'

module ReVIEW
  class Highlighter
    include ReVIEW::Loggable

    attr_reader :config

    def initialize(config = {})
      @config = config
      @logger = ReVIEW.logger
    end

    def highlight?(format = 'html')
      return false unless @config.key?('highlight') && @config['highlight'].is_a?(Hash)

      case format
      when 'html'
        @config['highlight']['html']
      when 'latex', 'tex'
        @config['highlight']['latex']
      else
        false
      end
    end

    def highlight(body:, lexer: nil, format: 'html', linenum: false, options: {}, location: nil)
      return body unless highlight?(format)

      case format
      when 'html'
        highlight_html(body: body, lexer: lexer, linenum: linenum, options: options, location: location)
      when 'latex', 'tex'
        highlight_latex(body: body, lexer: lexer, linenum: linenum, options: options, location: location)
      else
        raise ReVIEW::ConfigError, "unknown format #{format}."
      end
    end

    def highlight_html(body:, lexer: nil, linenum: false, options: {}, location: nil)
      highlighter = @config.dig('highlight', 'html')

      case highlighter
      when 'rouge'
        highlight_rouge(body: body, lexer: lexer, linenum: linenum, options: options, location: location)
      when 'pygments'
        highlight_pygments(body: body, lexer: lexer, linenum: linenum, options: options, location: location)
      else
        raise ReVIEW::ConfigError, "unknown highlight method #{highlighter} in config.yml."
      end
    end

    def highlight_latex(body:, lexer: nil, linenum: false, options: {}, location: nil) # rubocop:disable Lint/UnusedMethodArgument
      body
    end

    def highlight_rouge(body:, lexer: nil, linenum: false, options: {}, location: nil)
      require 'rouge'
      rouge_lexer = find_rouge_lexer(lexer)
      unless rouge_lexer
        return body
      end

      tokens = rouge_lexer.lex(body)

      if linenum
        base_formatter = Rouge::Formatters::HTML.new(css_class: 'highlight')
        start_line = options[:linenostart] || 1
        formatter = Rouge::Formatters::HTMLTable.new(
          base_formatter,
          table_class: 'highlight rouge-table',
          start_line: start_line
        )
      else
        formatter = Rouge::Formatters::HTML.new(css_class: 'highlight')
      end

      formatter.format(tokens)
    end

    def highlight_pygments(body:, lexer: nil, linenum: false, options: {}, location: nil)
      require 'pygments'

      pygments_options = build_pygments_options(
        linenum: linenum,
        options: options
      )

      Pygments.highlight(body,
                         lexer: lexer,
                         formatter: 'html',
                         options: pygments_options)
    rescue LoadError
      warn 'Pygments is not available. Install pygments.rb gem.', location: location
      body
    rescue MentosError
      warn "Pygments lexer error for language: #{lexer}", location: location
      body
    end

    def find_rouge_lexer(lexer_name)
      lexer = lexer_name || @config.dig('highlight', 'lang') || 'text'
      Rouge::Lexer.find(lexer)
    end

    def build_pygments_options(linenum: false, options: {})
      pygments_options = {
        nowrap: true,
        noclasses: true
      }

      if linenum
        pygments_options[:nowrap] = false
        pygments_options[:linenos] = 'inline'
      end

      if options.is_a?(Hash)
        pygments_options.merge!(options)
      end

      pygments_options
    end

    def rouge_available?
      require 'rouge'
      true
    rescue LoadError
      false
    end

    def pygments_available?
      require 'pygments'
      true
    rescue LoadError
      false
    end
  end
end
