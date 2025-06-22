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

      # Deserialize JSON string to AST nodes
      def deserialize(json_string)
        hash = JSON.parse(json_string)
        deserialize_from_hash(hash)
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

          case node_type
          when 'DocumentNode'
            node = DocumentNode.new
            if hash['content'] || hash['children']
              children = (hash['content'] || hash['children'] || []).map { |child| deserialize_from_hash(child) }
              children.each { |child| node.add_child(child) if child.is_a?(Node) }
            end
            node
          when 'HeadlineNode'
            HeadlineNode.new(
              level: hash['level'],
              label: hash['label'],
              caption: hash['caption']
            )
          when 'ParagraphNode'
            node = ParagraphNode.new
            if hash['content']
              # Handle inline content
              if hash['content'].is_a?(String)
                node.add_child(TextNode.new(content: hash['content']))
              elsif hash['content'].is_a?(Array)
                hash['content'].each do |item|
                  child = deserialize_from_hash(item)
                  node.add_child(child) if child.is_a?(Node)
                end
              end
            elsif hash['children']
              hash['children'].each do |child_hash|
                child = deserialize_from_hash(child_hash)
                node.add_child(child) if child.is_a?(Node)
              end
            end
            node
          when 'TextNode'
            TextNode.new(content: hash['content'] || '')
          when 'InlineNode'
            node = InlineNode.new(inline_type: hash['element'] || hash['inline_type'])
            if hash['content']
              if hash['content'].is_a?(String)
                node.add_child(TextNode.new(content: hash['content']))
              elsif hash['content'].is_a?(Array)
                hash['content'].each do |item|
                  child = deserialize_from_hash(item)
                  node.add_child(child) if child.is_a?(Node)
                end
              end
            end
            if hash['args']
              node.args = hash['args']
            end
            node
          when 'CodeBlockNode'
            CodeBlockNode.new(
              id: hash['id'],
              caption: hash['caption'],
              lines: hash['lines'] || [],
              lang: hash['lang'],
              line_numbers: hash['numbered'] || false
            )
          when 'TableNode'
            TableNode.new(
              id: hash['id'],
              caption: hash['caption'],
              headers: hash['headers'] || [],
              rows: hash['rows'] || [],
              table_type: hash['table_type'] || :table
            )
          when 'ImageNode'
            ImageNode.new(
              id: hash['id'],
              caption: hash['caption'],
              metric: hash['metric']
            )
          when 'ListNode', 'unordered_list', 'ordered_list', 'definition_list'
            list_type = case hash['type']
                        when 'unordered_list' then :ul
                        when 'ordered_list' then :ol
                        when 'definition_list' then :dl
                        else :ul
                        end
            node = ListNode.new(list_type: list_type)
            
            # Process list items
            if hash['items']
              hash['items'].each_with_index do |item, index|
                if item.is_a?(String)
                  # Simple text item
                  item_node = ListItemNode.new(level: 1)
                  item_node.add_child(TextNode.new(content: item))
                  node.add_child(item_node)
                elsif item.is_a?(Hash)
                  if item['content']
                    # Ordered list item with number
                    item_node = ListItemNode.new(level: 1, number: item['number'])
                    item_node.add_child(TextNode.new(content: item['content']))
                    node.add_child(item_node)
                  elsif item['term'] && item['definition']
                    # Definition list item
                    item_node = ListItemNode.new(level: 1)
                    item_node.add_child(TextNode.new(content: item['term']))
                    item_node.add_child(TextNode.new(content: item['definition']))
                    node.add_child(item_node)
                  end
                end
              end
            elsif hash['children']
              hash['children'].each do |child_hash|
                child = deserialize_from_hash(child_hash)
                node.add_child(child) if child.is_a?(Node)
              end
            end
            node
          when 'ListItemNode'
            node = ListItemNode.new(
              level: hash['level'] || 1,
              number: hash['number']
            )
            if hash['children']
              hash['children'].each do |child_hash|
                child = deserialize_from_hash(child_hash)
                node.add_child(child) if child.is_a?(Node)
              end
            end
            node
          when 'MinicolumnNode'
            node = MinicolumnNode.new(
              minicolumn_type: hash['minicolumn_type'] || hash['column_type'],
              caption: hash['caption']
            )
            if hash['children'] || hash['content']
              children = (hash['children'] || hash['content'] || []).map { |child| deserialize_from_hash(child) }
              children.each { |child| node.add_child(child) if child.is_a?(Node) }
            end
            node
          when 'BlockNode'
            node = BlockNode.new(block_type: hash['block_type'] || :quote)
            if hash['children']
              hash['children'].each do |child_hash|
                child = deserialize_from_hash(child_hash)
                node.add_child(child) if child.is_a?(Node)
              end
            end
            node
          when 'EmbedNode'
            EmbedNode.new(
              embed_type: hash['embed_type']&.to_sym || :inline,
              arg: hash['arg'],
              lines: hash['lines']
            )
          when 'ColumnNode'
            ColumnNode.new(
              level: hash['level'],
              label: hash['label'],
              caption: hash['caption'],
              column_type: hash['column_type']
            )
          else
            # Unknown node type, create generic node
            node = Node.new
            if hash['children']
              hash['children'].each do |child_hash|
                child = deserialize_from_hash(child_hash)
                node.add_child(child) if child.is_a?(Node)
              end
            end
            node
          end
        else
          hash
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
