# frozen_string_literal: true

require 'json'

module ReVIEW
  module AST
    module JSONSerializer # rubocop:disable Metrics/ModuleLength
      # Options for JSON serialization
      class Options
        attr_accessor :pretty, :include_location, :indent

        def initialize(pretty: true, include_location: true)
          @pretty = pretty
          @include_location = include_location
          @indent = '  '
        end

        def to_h
          {
            pretty: pretty,
            include_location: include_location,
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
      def deserialize_from_hash(hash) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
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

          case node_type
          when 'DocumentNode'
            node = ReVIEW::AST::DocumentNode.new(location: restore_location(hash))
            if hash['content'] || hash['children']
              children = (hash['content'] || hash['children'] || []).map { |child| deserialize_from_hash(child) }
              children.each { |child| node.add_child(child) if child.is_a?(ReVIEW::AST::Node) }
            end
            node
          when 'HeadlineNode'
            _, caption_node = deserialize_caption_fields(hash)
            ReVIEW::AST::HeadlineNode.new(
              location: restore_location(hash),
              level: hash['level'],
              label: hash['label'],
              caption_node: caption_node
            )
          when 'ParagraphNode'
            node = ReVIEW::AST::ParagraphNode.new(location: restore_location(hash))
            if hash['children']
              hash['children'].each do |child_hash|
                child = deserialize_from_hash(child_hash)
                if child.is_a?(ReVIEW::AST::Node)
                  node.add_child(child)
                elsif child.is_a?(String)
                  # Convert plain string to TextNode
                  node.add_child(ReVIEW::AST::TextNode.new(location: restore_location(hash), content: child))
                end
              end
            end
            node
          when 'TextNode'
            ReVIEW::AST::TextNode.new(location: restore_location(hash), content: hash['content'] || '')
          when 'CaptionNode'
            node = ReVIEW::AST::CaptionNode.new(location: restore_location(hash))
            if hash['children']
              hash['children'].each do |child_hash|
                child = deserialize_from_hash(child_hash)
                if child.is_a?(ReVIEW::AST::Node)
                  node.add_child(child)
                elsif child.is_a?(String)
                  # Convert plain string to TextNode
                  node.add_child(ReVIEW::AST::TextNode.new(location: restore_location(hash), content: child))
                end
              end
            end
            node
          when 'InlineNode'
            node = ReVIEW::AST::InlineNode.new(
              location: restore_location(hash),
              inline_type: hash['element'] || hash['inline_type'],
              args: hash['args'] || []
            )
            if hash['children']
              hash['children'].each do |child_hash|
                child = deserialize_from_hash(child_hash)
                node.add_child(child) if child.is_a?(ReVIEW::AST::Node)
              end
            end
            node
          when 'CodeBlockNode'
            _, caption_node = deserialize_caption_fields(hash)
            node = ReVIEW::AST::CodeBlockNode.new(
              location: restore_location(hash),
              id: hash['id'],
              caption_node: caption_node,
              lang: hash['lang'],
              line_numbers: hash['numbered'] || hash['line_numbers'] || false,
              code_type: hash['code_type'],
              original_text: hash['original_text']
            )
            if hash['children']
              hash['children'].each do |child_hash|
                child = deserialize_from_hash(child_hash)
                node.add_child(child) if child.is_a?(ReVIEW::AST::Node)
              end
            end
            node
          when 'TableNode'
            _, caption_node = deserialize_caption_fields(hash)
            node = ReVIEW::AST::TableNode.new(
              location: restore_location(hash),
              id: hash['id'],
              caption_node: caption_node,
              table_type: hash['table_type'] || :table,
              metric: hash['metric']
            )
            # Process header and body rows
            (hash['header_rows'] || []).each do |row_hash|
              row = deserialize_from_hash(row_hash)
              node.add_header_row(row) if row.is_a?(ReVIEW::AST::TableRowNode)
            end
            (hash['body_rows'] || []).each do |row_hash|
              row = deserialize_from_hash(row_hash)
              node.add_body_row(row) if row.is_a?(ReVIEW::AST::TableRowNode)
            end

            node
          when 'ImageNode'
            _, caption_node = deserialize_caption_fields(hash)
            ReVIEW::AST::ImageNode.new(
              location: restore_location(hash),
              id: hash['id'],
              caption_node: caption_node,
              metric: hash['metric']
            )
          when 'ListNode'
            node = ReVIEW::AST::ListNode.new(location: restore_location(hash), list_type: hash['list_type'].to_sym)

            # Process children (should be ListItemNode objects)
            if hash['children']
              hash['children'].each do |child_hash|
                child = deserialize_from_hash(child_hash)
                node.add_child(child) if child.is_a?(ReVIEW::AST::Node)
              end
            end
            node
          when 'ListItemNode'
            node = ReVIEW::AST::ListItemNode.new(
              location: restore_location(hash),
              level: hash['level'] || 1,
              number: hash['number']
            )
            if hash['children']
              hash['children'].each do |child_hash|
                child = deserialize_from_hash(child_hash)
                node.add_child(child) if child.is_a?(ReVIEW::AST::Node)
              end
            end
            node
          when 'MinicolumnNode'
            _, caption_node = deserialize_caption_fields(hash)
            node = ReVIEW::AST::MinicolumnNode.new(
              location: restore_location(hash),
              minicolumn_type: hash['minicolumn_type'] || hash['column_type'],
              caption_node: caption_node
            )
            if hash['children'] || hash['content']
              children = (hash['children'] || hash['content'] || []).map { |child| deserialize_from_hash(child) }
              children.each { |child| node.add_child(child) if child.is_a?(ReVIEW::AST::Node) }
            end
            node
          when 'BlockNode'
            block_type = hash['block_type'] ? hash['block_type'].to_sym : :quote
            _, caption_node = deserialize_caption_fields(hash)
            node = ReVIEW::AST::BlockNode.new(
              location: restore_location(hash),
              block_type: block_type,
              args: hash['args'],
              caption_node: caption_node
            )
            if hash['children']
              hash['children'].each do |child_hash|
                child = deserialize_from_hash(child_hash)
                node.add_child(child) if child.is_a?(ReVIEW::AST::Node)
              end
            end
            node
          when 'EmbedNode'
            ReVIEW::AST::EmbedNode.new(
              location: restore_location(hash),
              embed_type: hash['embed_type']&.to_sym || :inline,
              target_builders: hash['target_builders'],
              content: hash['content']
            )
          when 'CodeLineNode'
            node = ReVIEW::AST::CodeLineNode.new(
              location: restore_location(hash),
              line_number: hash['line_number'],
              original_text: hash['original_text']
            )
            if hash['children']
              hash['children'].each do |child_hash|
                child = deserialize_from_hash(child_hash)
                node.add_child(child) if child.is_a?(ReVIEW::AST::Node)
              end
            end
            node
          when 'TableRowNode'
            row_type = hash['row_type']&.to_sym || :body
            node = ReVIEW::AST::TableRowNode.new(
              location: restore_location(hash),
              row_type: row_type
            )
            if hash['children']
              hash['children'].each do |child_hash|
                child = deserialize_from_hash(child_hash)
                node.add_child(child) if child.is_a?(ReVIEW::AST::Node)
              end
            end
            node
          when 'TableCellNode'
            node = ReVIEW::AST::TableCellNode.new(location: restore_location(hash))
            if hash['children']
              hash['children'].each do |child_hash|
                child = deserialize_from_hash(child_hash)
                node.add_child(child) if child.is_a?(ReVIEW::AST::Node)
              end
            end
            node
          when 'ColumnNode'
            _, caption_node = deserialize_caption_fields(hash)
            node = ReVIEW::AST::ColumnNode.new(
              location: restore_location(hash),
              level: hash['level'],
              label: hash['label'],
              caption_node: caption_node,
              column_type: hash['column_type']
            )
            if hash['children'] || hash['content']
              children = (hash['children'] || hash['content'] || []).map { |child| deserialize_from_hash(child) }
              children.each { |child| node.add_child(child) if child.is_a?(ReVIEW::AST::Node) }
            end
            node
          else
            # Unknown node type - raise an error as this indicates a deserialization problem
            raise StandardError, "Unknown node type: #{node_type}. Cannot deserialize JSON with unknown node type."
          end
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
