# frozen_string_literal: true

require 'cgi'

module ReVIEW
  # HTML escape utility methods for AST/Renderer
  # This module provides basic HTML escaping methods used by HTML Renderer classes.
  # For Builder classes, use HTMLUtils or LaTeXUtils instead.
  module HtmlEscapeUtils
    # HTML content escaping using CGI.escapeHTML
    def escape_content(str)
      CGI.escapeHTML(str.to_s)
    end

    # URL escaping using CGI.escape
    # Note: LaTeXUtils has its own escape_url implementation for LaTeX-specific needs
    def escape_url(str)
      CGI.escape(str.to_s)
    end
  end
end
