# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

# Renderer module for converting AST nodes to various output formats.
# This module provides a cleaner, more maintainable approach to output
# generation compared to the traditional Builder pattern.
#
# The renderer approach separates concerns:
# - AST generation (handled by Compiler)
# - Format-specific rendering (handled by Renderer subclasses)
#
# Usage:
#   # JSON output
#   json_renderer = ReVIEW::Renderer::JSONRenderer.new
#   json_output = json_renderer.render(ast_root)
#
#   # HTML output
#   html_renderer = ReVIEW::Renderer::HTMLRenderer.new
#   html_output = html_renderer.render(ast_root)

module ReVIEW
  module Renderer
    # Load renderer classes
    autoload :Base, 'review/renderer/base'
    autoload :JSONRenderer, 'review/renderer/json_renderer'
  end
end
