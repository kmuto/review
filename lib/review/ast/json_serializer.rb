# frozen_string_literal: true

require 'json'

module ReVIEW
  module AST
    module JSONSerializer
      # Options for JSON serialization
      class Options
        attr_accessor :pretty, :include_location, :include_empty_arrays, :indent

        def initialize
          @pretty = true
          @include_location = true
          @include_empty_arrays = false
          @indent = '  '
        end

        def to_h
          {
            pretty: pretty,
            include_location: include_location,
            include_empty_arrays: include_empty_arrays,
            indent: indent
          }
        end
      end

      module_function

      # Serialize AST node to JSON
      def serialize(node, options = Options.new)
        hash = serialize_to_hash(node, options)
        if options.pretty
          JSON.pretty_generate(hash, indent: options.indent)
        else
          JSON.generate(hash)
        end
      end

      # Serialize AST node to Hash
      def serialize_to_hash(node, options = Options.new)
        case node
        when Array
          node.map { |item| serialize_to_hash(item, options) }
        when Hash
          node.transform_values { |value| serialize_to_hash(value, options) }
        when ReVIEW::AST::Node
          hash = {
            type: node.class.name.split('::').last
          }

          # Include location information
          if options.include_location && node.location
            hash[:location] = serialize_location(node.location)
          end

          # Add node-specific properties
          hash.merge!(serialize_node_properties(node, options))

          # Serialize child nodes
          if node.children && (options.include_empty_arrays || node.children.any?)
            hash[:children] = node.children.map { |child| serialize_to_hash(child, options) }
          end

          hash
        else
          node
        end
      end

      # Serialize location information
      def serialize_location(location)
        begin
          {
            filename: location.respond_to?(:filename) ? location.filename : nil,
            lineno: location.respond_to?(:lineno) ? location.lineno : nil
          }
        rescue StandardError
          {
            filename: nil,
            lineno: nil
          }
        end
      end

      # Serialize node-specific properties
      def serialize_node_properties(node, options)
        case node
        when ReVIEW::AST::HeadlineNode
          {
            level: node.level,
            label: node.label,
            caption: node.caption
          }
        when ReVIEW::AST::ParagraphNode
          {
            content: node.content
          }
        when ReVIEW::AST::InlineNode
          {
            inline_type: node.inline_type,
            args: node.args
          }
        when ReVIEW::AST::TextNode # rubocop:disable Lint/DuplicateBranch
          {
            content: node.content
          }
        when ReVIEW::AST::DocumentNode
          hash = { title: node.title }
          if options.include_empty_arrays || (node.chapters && node.chapters.any?)
            hash[:chapters] = node.chapters&.map { |chapter| serialize_to_hash(chapter, options) } || []
          end
          hash
        when ReVIEW::AST::CodeBlockNode
          {
            lang: node.lang,
            id: node.id,
            caption: node.caption,
            lines: node.lines,
            line_numbers: node.line_numbers
          }
        when ReVIEW::AST::ImageNode
          {
            id: node.id,
            caption: node.caption,
            metric: node.metric
          }
        when ReVIEW::AST::TableNode
          {
            id: node.id,
            caption: node.caption,
            headers: node.headers,
            rows: node.rows
          }
        when ReVIEW::AST::ListNode
          hash = { list_type: node.list_type }
          if options.include_empty_arrays || (node.items && node.items.any?)
            hash[:items] = node.items&.map { |item| serialize_to_hash(item, options) } || []
          end
          hash
        when ReVIEW::AST::ListItemNode
          {
            content: node.content,
            level: node.level
          }
        when ReVIEW::AST::EmbedNode
          {
            lines: node.lines,
            arg: node.arg,
            embed_type: node.embed_type
          }
        else
          {}
        end
      end

      # Restore AST from JSON string (basic implementation)
      def deserialize(json_string)
        hash = JSON.parse(json_string, symbolize_names: true)
        deserialize_from_hash(hash)
      end

      # Restore AST node from Hash
      def deserialize_from_hash(hash)
        return nil unless hash.is_a?(Hash) && hash[:type]

        node_class = ReVIEW::AST.const_get(hash[:type])
        location = deserialize_location(hash[:location]) if hash[:location]
        node = node_class.new(location)

        # Restore node-specific properties
        restore_node_properties(node, hash)

        # Restore child nodes
        if hash[:children]
          hash[:children].each do |child_hash|
            child = deserialize_from_hash(child_hash)
            node.add_child(child) if child
          end
        end

        node
      end

      # Restore location information
      def deserialize_location(location_hash)
        return nil unless location_hash.is_a?(Hash)

        # Create simple Location struct
        Struct.new(:filename, :lineno).new(
          location_hash[:filename],
          location_hash[:lineno]
        )
      end

      # Restore node-specific properties
      def restore_node_properties(node, hash)
        case node
        when ReVIEW::AST::HeadlineNode
          node.level = hash[:level]
          node.label = hash[:label]
          node.caption = hash[:caption]
        when ReVIEW::AST::ParagraphNode
          node.content = hash[:content]
        when ReVIEW::AST::InlineNode
          node.inline_type = hash[:inline_type]
          node.args = hash[:args]
        when ReVIEW::AST::TextNode # rubocop:disable Lint/DuplicateBranch
          node.content = hash[:content]
        when ReVIEW::AST::DocumentNode
          node.title = hash[:title]
          node.chapters = hash[:chapters] || []
        when ReVIEW::AST::CodeBlockNode
          node.lang = hash[:lang]
          node.id = hash[:id]
          node.caption = hash[:caption]
          node.lines = hash[:lines] || []
          node.line_numbers = hash[:line_numbers] || false
        when ReVIEW::AST::ImageNode
          node.id = hash[:id]
          node.caption = hash[:caption]
          node.metric = hash[:metric]
        when ReVIEW::AST::TableNode
          node.id = hash[:id]
          node.caption = hash[:caption]
          node.headers = hash[:headers] || []
          node.rows = hash[:rows] || []
        when ReVIEW::AST::ListNode
          node.list_type = hash[:list_type]
          node.items = hash[:items] || []
        when ReVIEW::AST::ListItemNode
          node.content = hash[:content]
          node.level = hash[:level] || 1
        when ReVIEW::AST::EmbedNode
          node.lines = hash[:lines] || []
          node.arg = hash[:arg]
          node.embed_type = hash[:embed_type] || :block
        end
      end

      # JSON schema definition for validation
      def json_schema
        {
          '$schema' => 'http://json-schema.org/draft-07/schema#',
          'title' => 'ReVIEW AST JSON Schema',
          'type' => 'object',
          'required' => ['type'],
          'properties' => {
            'type' => {
              'type' => 'string',
              'enum' => %w[
                DocumentNode HeadlineNode ParagraphNode InlineNode TextNode
                CodeBlockNode ImageNode TableNode ListNode ListItemNode EmbedNode
              ]
            },
            'location' => {
              'type' => 'object',
              'properties' => {
                'filename' => { 'type' => ['string', 'null'] },
                'lineno' => { 'type' => ['integer', 'null'] }
              }
            },
            'children' => {
              'type' => 'array',
              'items' => { '$ref' => '#' }
            }
          },
          'additionalProperties' => true
        }
      end
    end
  end
end
