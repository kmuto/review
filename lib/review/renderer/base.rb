# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/ast/visitor'
require 'review/exception'

module ReVIEW
  module Renderer
    # Error class for renderer-specific errors
    class RenderError < ReVIEW::ApplicationError; end

    # Base class for all AST renderers.
    # This class extends the Visitor pattern to provide rendering capabilities
    # for converting AST nodes into various output formats.
    #
    # Subclasses should implement visit methods for specific node types:
    #   - visit_document(node)
    #   - visit_headline(node)
    #   - visit_paragraph(node)
    #   - visit_codeblock(node)
    #   - visit_table(node)
    #   - etc.
    #
    # Usage:
    #   class HtmlRenderer < ReVIEW::Renderer::Base
    #     def visit_headline(node)
    #       level = node.level
    #       caption = process_inline_content(node.caption)
    #       "<h#{level}>#{caption}</h#{level}>"
    #     end
    #   end
    #
    #   renderer = HtmlRenderer.new
    #   html_output = renderer.render(ast_root)
    class Base < ReVIEW::AST::Visitor
      attr_reader :chapter, :book, :config

      # Initialize the renderer with chapter context.
      # Book and config are automatically derived from the chapter.
      #
      # @param chapter [ReVIEW::Book::Chapter] Chapter context
      def initialize(chapter)
        @chapter = chapter
        @book = chapter&.book
        @config = @book&.config || {}
        super()
      end

      # Render an AST node to the target format.
      # This is the main entry point for rendering.
      #
      # @param ast_root [Object] The root AST node to render
      # @return [String] The rendered output
      def render(ast_root)
        result = visit(ast_root)
        post_process(result)
      end

      # Check if caption should be positioned at top for given type
      #
      # @param type [String] Element type (e.g., 'image', 'table', 'list', 'equation')
      # @return [Boolean] true if caption should be at top, false otherwise
      def caption_top?(type)
        config['caption_position'] && config['caption_position'][type] == 'top'
      end

      # Render all children of a node and join the results.
      # This is a common helper method used by all renderers and can be called
      # from helper classes like CodeBlockRenderer.
      #
      # @param node [Object] The parent node whose children should be rendered
      # @return [String] The joined rendered output of all children
      def render_children(node)
        return '' unless node.children

        node.children.map { |child| visit(child) }.join
      end

      private

      # Post-process the rendered result.
      # Subclasses can override this to perform final formatting,
      # cleanup, or validation.
      #
      # @param result [Object] The result from visiting the AST
      # @return [String] The final rendered output
      def post_process(result)
        result.to_s
      end

      # Handle inline elements within content.
      # This method processes inline markup like bold, italic, code, etc.
      #
      # @param node [Object] The node containing inline content
      # @return [String] The rendered inline content
      def render_inline_content(node)
        process_inline_content(node)
      end

      # Escape special characters for the target format.
      # Subclasses should override this method to provide format-specific escaping.
      #
      # @param str [String] The string to escape
      # @return [String] The escaped string
      def escape(str)
        str.to_s
      end

      # Generate an ID or label for a node.
      # This method creates consistent identifiers for elements that can be referenced.
      #
      # @param node [Object] The node to generate an ID for
      # @param prefix [String] Optional prefix for the ID
      # @return [String] The generated ID
      def generate_id(node, prefix = nil)
        id_parts = []
        id_parts << prefix if prefix

        if node.respond_to?(:id) && node.id
          id_parts << node.id
        elsif node.respond_to?(:label) && node.label
          id_parts << node.label
        end

        id_parts.join('-')
      end

      # Default visit methods for common node types.
      # These provide basic fallback behavior that subclasses can override.

      def visit_text(node)
        escape(node.content.to_s)
      end

      def visit_inline(node)
        content = process_inline_content(node)
        render_inline_element(node.inline_type, content, node)
      end

      # Render a specific inline element.
      #
      # @param type [String] The inline element type (e.g., 'b', 'i', 'code')
      # @param content [String] The content of the inline element
      # @param node [Object] The original inline node (for additional attributes)
      # @return [String] The rendered inline element
      def render_inline_element(_type, content, _node = nil)
        # Default implementation just returns the content
        content
      end

      # Parse metric option for images and tables
      #
      # @param type [String] Builder type (e.g., 'latex', 'html')
      # @param metric [String] Metric string (e.g., 'latex::width=80mm,scale=0.5')
      # @return [String] Processed metric string
      #
      # @example
      #   parse_metric('latex', 'latex::width=80mm') # => 'width=80mm'
      #   parse_metric('latex', 'scale=0.5') # => 'scale=0.5'
      #   parse_metric('html', 'latex::width=80mm') # => ''
      def parse_metric(type, metric)
        return '' if metric.nil? || metric.empty?

        params = metric.split(/,\s*/)
        results = []
        params.each do |param|
          # Check if param has builder prefix (e.g., "latex::")
          if /\A.+?::/.match?(param)
            # Skip if not for this builder type
            next unless /\A#{type}::/.match?(param)

            # Remove the builder prefix
            param = param.sub(/\A#{type}::/, '')
          end
          # Handle metric transformations if needed
          param2 = handle_metric(param)
          results.push(param2)
        end
        result_metric(results)
      end

      # Handle individual metric transformations
      #
      # @param str [String] Metric string (e.g., 'scale=0.5')
      # @return [String] Transformed metric string
      def handle_metric(str)
        str
      end

      # Combine metric results into final string
      #
      # @param array [Array<String>] Array of metric strings
      # @return [String] Combined metric string
      def result_metric(array)
        array.join(',')
      end
    end
  end
end
