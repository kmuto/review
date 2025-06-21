# frozen_string_literal: true

require 'review/ast/node'

module ReVIEW
  module AST
    # Represents a caption that can contain both text and inline elements
    class CaptionNode < Node
      # Parser class for caption processing
      class Parser
        def initialize(location: nil, inline_processor: nil)
          @location = location
          @inline_processor = inline_processor
        end

        def parse(caption)
          return nil if caption.nil? || caption == ''
          return caption if caption.is_a?(CaptionNode)

          case caption
          when String
            parse_string(caption)
          when Array
            parse_array(caption)
          else
            parse_fallback(caption)
          end
        end

        private

        def parse_string(caption)
          caption_node = CaptionNode.new(location: @location)
          if @inline_processor && caption.include?('@<')
            @inline_processor.parse_inline_elements(caption, caption_node)
          else
            caption_node.add_child(TextNode.new(location: @location, content: caption))
          end
          caption_node
        end

        def parse_array(caption)
          return nil if caption.empty?

          caption_node = CaptionNode.new(location: @location)
          caption.each { |child| caption_node.add_child(child) }
          caption_node
        end

        def parse_fallback(caption)
          return nil if caption.to_s.empty?

          caption_node = CaptionNode.new(location: @location)
          caption_node.add_child(TextNode.new(location: @location, content: caption.to_s))
          caption_node
        end
      end

      # Factory method for creating CaptionNode from various input types
      def self.parse(caption, location: nil, inline_processor: nil)
        parser = Parser.new(location: location, inline_processor: inline_processor)
        parser.parse(caption)
      end

      def initialize(location: nil, **kwargs)
        super
      end

      # Convert caption to plain text format for legacy Builder compatibility
      def to_text
        return '' if children.empty?

        children.map { |child| render_node_as_text(child) }.join
      end

      # Check if caption contains any inline elements
      def contains_inline?
        children.any? { |child| child.is_a?(InlineNode) }
      end

      # Check if caption is empty
      def empty?
        children.empty? || children.all? { |child| child.respond_to?(:content) && child.content.to_s.strip.empty? }
      end

      # Override serialize_to_hash to return CaptionNode structure
      def serialize_to_hash(options)
        if children.empty?
          ''
        else
          # Return full CaptionNode structure
          super
        end
      end

      private

      # Recursively render AST nodes as Re:VIEW markup text
      def render_node_as_text(node)
        case node
        when TextNode
          node.content
        when InlineNode
          # Convert back to Re:VIEW markup for Builder processing
          content = node.children.map { |child| render_node_as_text(child) }.join
          "@<#{node.inline_type}>{#{content}}"
        else
          node.respond_to?(:content) ? node.content.to_s : ''
        end
      end
    end
  end
end
