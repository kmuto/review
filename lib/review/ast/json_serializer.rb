# frozen_string_literal: true

require 'json'

module ReVIEW
  module AST
    module JSONSerializer
      # Options for JSON serialization
      class Options
        attr_accessor :pretty, :include_location, :indent

        def initialize(pretty: true, include_location: true)
          @pretty = pretty
          @include_location = include_location
          @indent = '  '
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
          # Delegate to the node's own serialization method
          node.serialize_to_hash(options)
        else
          node
        end
      end

      # Deserialize JSON string to AST nodes
      def deserialize(json_string)
        hash = JSON.parse(json_string)
        deserialize_from_hash(hash)
      end

      def deserialize_caption_fields(hash)
        caption_value = hash['caption']
        caption_node_value = hash['caption_node']

        caption_node = if caption_node_value
                         deserialize_from_hash(caption_node_value)
                       elsif caption_value.is_a?(Hash) || caption_value.is_a?(Array)
                         deserialize_from_hash(caption_value)
                       end

        caption_string = caption_value.is_a?(String) ? caption_value : nil

        [caption_string, caption_node]
      end

      # Helper method to create location from hash or use a default
      def restore_location(hash)
        location_data = hash['location']
        return nil unless location_data && location_data.is_a?(Hash)

        filename = location_data['filename']
        lineno = location_data['lineno']
        return nil unless filename && lineno

        ReVIEW::SnapshotLocation.new(filename, lineno)
      end

      # Deserialize hash to AST node
      def deserialize_from_hash(hash)
        return nil unless hash

        case hash
        when Array
          hash.map { |item| deserialize_from_hash(item) }
        when String
          # Plain string is treated as text content
          hash
        when Hash
          node_type = hash['type']
          return hash.to_s unless node_type

          # Check if the node class exists
          begin
            node_class = ReVIEW::AST.const_get(node_type)
          rescue NameError
            raise StandardError, "Unknown node type: #{node_type}. Cannot deserialize JSON with unknown node type."
          end

          # Verify it's actually a node class
          unless node_class.respond_to?(:deserialize_from_hash)
            raise StandardError, "Node class #{node_type} does not implement deserialize_from_hash method."
          end

          # Delegate to the node class
          node_class.deserialize_from_hash(hash)
        else
          raise StandardError, "invalid hash: `#{hash}`"
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
                CodeBlockNode ImageNode TableNode ListNode ListItemNode EmbedNode ColumnNode
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
