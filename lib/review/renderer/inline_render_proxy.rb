# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

module ReVIEW
  module Renderer
    # Shared proxy class that provides minimal interface to renderer for InlineContext classes.
    # This proxy limits access to renderer methods, exposing only what's needed for inline rendering.
    #
    # This class is used by HTML, LaTeX, and IDGXML InlineContext classes to prevent
    # tight coupling between InlineElementHandler and the full renderer interface.
    #
    # Common methods (always available):
    # - render_children(node): Render all children of a node
    # - text_formatter: Access to TextFormatter instance
    #
    # Optional methods (available if renderer supports them):
    # - rendering_context: Current rendering context (for LaTeX footnote handling)
    # - render_caption_inline(caption_node): Render caption with inline markup (for LaTeX/IDGXML)
    # - increment_texinlineequation: Increment equation counter (for IDGXML math rendering)
    class InlineRenderProxy
      def initialize(renderer)
        @renderer = renderer
      end

      # Render all children of a node and join the results
      # @param node [Object] The parent node whose children should be rendered
      # @return [String] The joined rendered output of all children
      def render_children(node)
        @renderer.render_children(node)
      end

      # Get TextFormatter instance from the renderer
      # @return [ReVIEW::Renderer::TextFormatter] Text formatter instance
      def text_formatter
        @renderer.text_formatter
      end

      # Get current rendering context (LaTeX-specific feature)
      # @return [RenderingContext, nil] Current rendering context if available
      def rendering_context
        @renderer.rendering_context if @renderer.respond_to?(:rendering_context)
      end

      # Render caption with inline markup (LaTeX/IDGXML-specific feature)
      # @param caption_node [Object] Caption node to render
      # @return [String, nil] Rendered caption if available
      def render_caption_inline(caption_node)
        if @renderer.respond_to?(:render_caption_inline)
          @renderer.render_caption_inline(caption_node)
        end
      end

      # Increment inline equation counter (IDGXML-specific feature)
      # @return [Integer, nil] Counter value if available
      def increment_texinlineequation
        if @renderer.respond_to?(:increment_texinlineequation)
          @renderer.increment_texinlineequation
        end
      end
    end
  end
end
