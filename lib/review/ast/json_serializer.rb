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
          serialize_ast_node_to_hash(node, options)
        else
          node
        end
      end

      # Serialize AST Node to Hash with specific ordering
      def serialize_ast_node_to_hash(node, options)
        # Start with type
        hash = {
          type: node.class.name.split('::').last
        }

        # Include location information
        if options.include_location && node.location
          hash[:location] = serialize_location(node.location)
        end

        # Handle specific node types with custom serialization
        case node
        when ReVIEW::AST::InlineNode
          serialize_inline_node(node, hash, options)
        when ReVIEW::AST::TextNode
          serialize_text_node(node, hash)
        when ReVIEW::AST::DocumentNode
          serialize_document_node(node, hash, options)
        when ReVIEW::AST::ParagraphNode
          serialize_paragraph_node(node, hash, options)
        when ReVIEW::AST::CodeBlockNode
          serialize_code_block_node(node, hash)
        else
          serialize_generic_node(node, hash, options)
        end
      end

      # Serialize InlineNode
      def serialize_inline_node(node, hash, options)
        hash[:children] = node.children.map { |child| serialize_to_hash(child, options) }
        hash[:inline_type] = node.inline_type
        hash[:args] = node.args
        hash
      end

      # Serialize TextNode
      def serialize_text_node(node, hash)
        hash[:children] = []
        hash[:content] = node.content
        hash
      end

      # Serialize DocumentNode
      def serialize_document_node(node, hash, options)
        hash[:children] = node.children.map { |child| serialize_to_hash(child, options) }
        hash[:title] = node.title
        if options.include_empty_arrays || (node.chapters && node.chapters.any?)
          hash[:chapters] = node.chapters&.map { |chapter| serialize_to_hash(chapter, options) } || []
        end
        hash
      end

      # Serialize ParagraphNode
      def serialize_paragraph_node(node, hash, options)
        hash[:children] = node.children.map { |child| serialize_to_hash(child, options) }
        hash
      end

      # Serialize CodeBlockNode
      def serialize_code_block_node(node, hash)
        hash[:children] = []
        hash[:lang] = node.lang
        hash[:id] = node.id
        hash[:caption] = node.caption
        hash[:lines] = node.lines
        hash[:line_numbers] = node.line_numbers
        hash
      end

      # Serialize generic Node
      def serialize_generic_node(node, hash, options)
        hash.merge!(serialize_node_properties(node, options))
        # Serialize child nodes
        if node.children && (options.include_empty_arrays || node.children.any?)
          hash[:children] = node.children.map { |child| serialize_to_hash(child, options) }
        end
        hash
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
          serialize_headline_properties(node)
        when ReVIEW::AST::ParagraphNode
          serialize_paragraph_properties
        when ReVIEW::AST::InlineNode
          serialize_inline_properties(node)
        when ReVIEW::AST::TextNode
          serialize_text_properties(node)
        when ReVIEW::AST::DocumentNode
          serialize_document_properties(node, options)
        when ReVIEW::AST::CodeBlockNode
          serialize_code_block_properties(node)
        when ReVIEW::AST::ImageNode
          serialize_image_properties(node)
        when ReVIEW::AST::TableNode
          serialize_table_properties(node)
        when ReVIEW::AST::ListNode
          serialize_list_properties(node, options)
        when ReVIEW::AST::ListItemNode
          serialize_list_item_properties(node)
        when ReVIEW::AST::EmbedNode
          serialize_embed_properties(node)
        else
          serialize_generic_properties(node)
        end
      end

      # Individual property serialization methods
      def serialize_headline_properties(node)
        {
          level: node.level,
          label: node.label,
          caption: node.caption
        }
      end

      def serialize_paragraph_properties
        {
          # ParagraphNode has no additional properties beyond base Node
        }
      end

      def serialize_inline_properties(node)
        {
          inline_type: node.inline_type,
          args: node.args
        }
      end

      def serialize_text_properties(node)
        {
          content: node.content
        }
      end

      def serialize_document_properties(node, options)
        hash = { title: node.title }
        if options.include_empty_arrays || (node.chapters && node.chapters.any?)
          hash[:chapters] = node.chapters&.map { |chapter| serialize_to_hash(chapter, options) } || []
        end
        hash
      end

      def serialize_code_block_properties(node)
        {
          lang: node.lang,
          id: node.id,
          caption: node.caption,
          lines: node.lines,
          line_numbers: node.line_numbers
        }
      end

      def serialize_image_properties(node)
        {
          id: node.id,
          caption: node.caption,
          metric: node.metric
        }
      end

      def serialize_table_properties(node)
        {
          id: node.id,
          caption: node.caption,
          headers: node.headers,
          rows: node.rows
        }
      end

      def serialize_list_properties(node, options)
        hash = { list_type: node.list_type }
        if options.include_empty_arrays || (node.items && node.items.any?)
          hash[:items] = node.items&.map { |item| serialize_to_hash(item, options) } || []
        end
        hash
      end

      def serialize_list_item_properties(node)
        {
          content: node.content,
          level: node.level
        }
      end

      def serialize_embed_properties(node)
        {
          lines: node.lines,
          arg: node.arg,
          embed_type: node.embed_type
        }
      end

      def serialize_generic_properties(node)
        # Handle generic Node instances (used for read, minicolumn, etc.)
        if node.instance_of?(ReVIEW::AST::Node)
          result = {}
          result[:node_type] = node.type if node.type && !node.type.empty?
          result[:id] = node.id if node.id && !node.id.empty?
          result[:content] = node.content if node.content && !node.content.empty?
          result
        else
          {}
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
