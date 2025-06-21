# frozen_string_literal: true

require 'json'

module ReVIEW
  module AST
    module JSONSerializer
      # Options for JSON serialization
      class Options
        attr_accessor :pretty, :include_location, :include_empty_arrays, :indent, :simple_mode

        def initialize(include_empty_arrays: false, pretty: true, simple_mode: false, include_location: true)
          @pretty = pretty
          @include_empty_arrays = include_empty_arrays
          @include_location = include_location
          @indent = '  '
          @simple_mode = simple_mode
        end

        def to_h
          {
            pretty: pretty,
            include_location: include_location,
            include_empty_arrays: include_empty_arrays,
            indent: indent,
            simple_mode: simple_mode
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
          if options.simple_mode
            # Simple mode: direct serialization without calling node methods
            simple_serialize_node(node, options)
          else
            # Traditional mode: delegate to the node's own serialization method
            node.serialize_to_hash(options)
          end
        else
          node
        end
      end

      # Simple serialization for nodes (bypasses node's serialize_to_hash method)
      def simple_serialize_node(node, options)
        hash = { 'type' => node.class.name.split('::').last }

        # Skip location in simple mode unless explicitly requested
        if options.include_location && node.location
          hash['location'] = {
            'filename' => node.location.filename,
            'lineno' => node.location.lineno
          }
        end

        case node
        when DocumentNode
          hash['content'] = node.children.map { |child| serialize_to_hash(child, options) }
        when HeadlineNode
          hash['level'] = node.level
          hash['label'] = node.label
          hash['caption'] = extract_text(node.caption)
        when ParagraphNode
          hash['content'] = serialize_inline_content(node, options)
        when CodeBlockNode
          hash['caption'] = extract_text(node.caption)
          hash['lines'] = node.lines || []
          hash['id'] = node.id if node.respond_to?(:id) && node.id
          hash['lang'] = node.lang if node.respond_to?(:lang) && node.lang
          hash['numbered'] = node.respond_to?(:line_numbers) ? node.line_numbers : false
        when TableNode
          hash['caption'] = extract_text(node.caption)
          hash['id'] = node.id if node.respond_to?(:id) && node.id
          hash['headers'] = node.headers if node.respond_to?(:headers) && node.headers
          hash['rows'] = node.rows if node.respond_to?(:rows) && node.rows
        when ImageNode
          hash['caption'] = extract_text(node.caption)
          hash['id'] = node.id if node.respond_to?(:id) && node.id
          hash['metric'] = node.metric if node.respond_to?(:metric) && node.metric
        when ListNode
          list_type = determine_list_type(node)
          hash['type'] = list_type
          hash['items'] = process_list_items(node, list_type, options)
        when TextNode
          return node.content.to_s
        when InlineNode
          hash['element'] = node.inline_type
          hash['content'] = serialize_inline_content(node, options)
        when CaptionNode
          return extract_text(node)
        when ColumnNode
          hash['level'] = node.level
          hash['label'] = node.label
          hash['caption'] = extract_text(node.caption)
          hash['content'] = node.children.map { |child| serialize_to_hash(child, options) }
        when EmbedNode
          case node.embed_type
          when :block
            hash['embed_type'] = 'block'
            hash['arg'] = node.arg
            hash['lines'] = node.lines || []
          when :inline
            hash['embed_type'] = 'inline'
            hash['arg'] = node.arg
          when :raw
            hash['embed_type'] = 'raw'
            hash['content'] = node.arg.to_s
          end
        else
          # Generic handling
          if node.children && node.children.any?
            hash['children'] = node.children.map { |child| serialize_to_hash(child, options) }
          end
        end

        hash
      end

      def extract_text(node)
        case node
        when String
          node
        when nil
          ''
        else
          if node.respond_to?(:children) && node.children&.any?
            node.children.map { |child| extract_text(child) }.join
          elsif node.respond_to?(:content)
            node.content.to_s
          else
            node.to_s
          end
        end
      end

      def serialize_inline_content(node, options)
        return '' unless node

        if node.respond_to?(:children) && node.children
          result = []
          node.children.each do |child|
            serialized = serialize_to_hash(child, options)
            result << if serialized.is_a?(Hash) && serialized['type'] == 'InlineNode'
                        serialized.to_json
                      else
                        serialized.to_s
                      end
          end
          result.join
        else
          extract_text(node)
        end
      end

      def determine_list_type(node)
        if node.respond_to?(:list_type)
          case node.list_type.to_s
          when 'ul', 'unordered'
            'unordered_list'
          when 'ol', 'ordered'
            'ordered_list'
          when 'dl', 'definition'
            'definition_list'
          else
            'unordered_list'
          end
        else
          'unordered_list'
        end
      end

      def process_list_items(node, list_type, options)
        return [] unless node.respond_to?(:children) && node.children

        case list_type
        when 'unordered_list'
          node.children.map { |item| serialize_inline_content(item, options) }
        when 'ordered_list'
          node.children.map.with_index(1) do |item, index|
            {
              'number' => index.to_s,
              'content' => serialize_inline_content(item, options)
            }
          end
        when 'definition_list'
          items = []
          node.children.each do |item|
            next unless item.respond_to?(:children) && item.children.any?

            # First child is the term (dt)
            dt_node = item.children[0]
            term = if dt_node.is_a?(TextNode)
                     dt_node.content
                   else
                     serialize_inline_content(dt_node, options)
                   end

            # Remaining children are definition content (dd)
            definition = if item.children.size > 1
                           item.children[1..-1].map do |child|
                             if child.is_a?(TextNode)
                               child.content
                             else
                               serialize_inline_content(child, options)
                             end
                           end.join(' ')
                         else
                           ''
                         end

            items << {
              'term' => term,
              'definition' => definition
            }
          end
          items
        else
          node.children.map { |item| serialize_inline_content(item, options) }
        end
      end

      # Deserialization methods are available but not currently used in production
      # Commented out to reduce module complexity. Uncomment if needed.

      # def deserialize(json_string)
      #   hash = JSON.parse(json_string, symbolize_names: true)
      #   deserialize_from_hash(hash)
      # end

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
