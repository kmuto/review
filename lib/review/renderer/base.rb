# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/ast/visitor'
require 'review/exception'
require 'review/ast/text_formatter'

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
      # Initialize the renderer with chapter context.
      #
      # @param chapter [ReVIEW::Book::Chapter] Chapter context
      def initialize(chapter)
        @chapter = chapter
        @book = chapter&.book
        @config = @book&.config || {}
        super()
      end

      # Render an AST node to the target format.
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
      #
      # @param node [Object] The parent node whose children should be rendered
      # @return [String] The joined rendered output of all children
      def render_children(node)
        node.children.map { |child| visit(child) }.join
      end

      # Get TextFormatter instance for this renderer.
      # TextFormatter centralizes all I18n and text formatting logic.
      #
      # @return [ReVIEW::AST::TextFormatter] Text formatter instance
      def text_formatter
        @text_formatter ||= ReVIEW::AST::TextFormatter.new(
          format_type: format_type,
          config: @config,
          chapter: @chapter
        )
      end

      # Get the format type for this renderer.
      # Subclasses must override this method to specify their format.
      #
      # @return [Symbol] Format type (:html, :latex, :idgxml, :text, :top)
      def format_type
        raise NotImplementedError, "#{self.class} must implement #format_type"
      end

      private

      attr_reader :config

      # Post-process the rendered result.
      # Subclasses can override this to perform final formatting,
      # cleanup, or validation.
      #
      # @param result [Object] The result from visiting the AST
      # @return [String] The final rendered output
      def post_process(result)
        result.to_s
      end

      # Escape special characters for the target format.
      #
      # @param str [String] The string to escape
      # @return [String] The escaped string
      def escape(str)
        str.to_s
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

      # Visit a code block node.
      # This method uses dynamic method dispatch to call format-specific handlers.
      # Subclasses should implement visit_code_block_<type> methods for each code block type.
      #
      # @param node [Object] The code block node
      # @return [String] The rendered code block
      def visit_code_block(node)
        method_name = "visit_code_block_#{node.code_type}"
        if respond_to?(method_name, true)
          send(method_name, node)
        else
          raise NotImplementedError, "Unknown code block type: #{node.code_type}"
        end
      end

      # Visit a block node.
      # This method uses dynamic method dispatch to call format-specific handlers.
      # Subclasses should implement visit_block_<type> methods for each block type.
      #
      # @param node [Object] The block node
      # @return [String] The rendered block
      def visit_block(node)
        method_name = "visit_block_#{node.block_type}"
        if respond_to?(method_name, true)
          send(method_name, node)
        else
          raise NotImplementedError, "Unknown block type: #{node.block_type}"
        end
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

      # Extract text content from a node, handling various node types.
      # This is useful for extracting plain text from caption nodes or
      # inline content.
      #
      # @param node [Object] The node to extract text from
      # @return [String] The extracted text content
      def extract_text(node)
        case node
        when String
          node
        when nil
          ''
        else
          if node.children&.any?
            node.children.map { |child| extract_text(child) }.join
          elsif node.leaf_node?
            node.content.to_s
          else
            node.to_s
          end
        end
      end

      # Process inline content within a node.
      # This method visits all children of a node and returns the processed content.
      #
      # @param node [Object] The node containing inline content
      # @return [String] The processed inline content
      def process_inline_content(node)
        return '' unless node

        if node.children
          node.children.map { |child| visit(child) }.join
        else
          extract_text(node)
        end
      end
    end
  end
end
