# frozen_string_literal: true

require_relative 'node'
require_relative 'caption_node'
require_relative 'captionable'

module ReVIEW
  module AST
    class CodeBlockNode < Node
      include Captionable

      attr_accessor :first_line_num
      attr_reader :lang, :line_numbers, :code_type

      def initialize(location:, lang: nil, id: nil, caption_node: nil, line_numbers: false, code_type: nil, first_line_num: nil, **kwargs)
        super(location: location, id: id, **kwargs)
        @lang = lang
        @caption_node = caption_node
        @line_numbers = line_numbers
        @code_type = code_type
        @first_line_num = first_line_num
        @children = []
      end

      attr_reader :children

      # Get original lines as array (for builders that don't need inline processing)
      def original_lines
        return [] unless original_text

        original_text.split("\n")
      end

      # Get processed lines by reconstructing from AST (for builders that need inline processing)
      def processed_lines
        children.map do |line_node|
          line_node.children.map do |child|
            case child
            when AST::TextNode
              child.content
            when AST::InlineNode
              # Reconstruct Re:VIEW syntax from original args (preserve original IDs)
              content = if child.args.any?
                          child.args.first
                        elsif child.children&.any?
                          child.children.map do |grandchild|
                            grandchild.leaf_node? ? grandchild.content : grandchild.to_s
                          end.join
                        else
                          ''
                        end
              "@<#{child.inline_type}>{#{content}}"
            else
              child.to_s
            end
          end.join
        end
      end

      def to_h
        result = super.merge(
          lang: lang,
          caption_node: caption_node&.to_h,
          line_numbers: line_numbers,
          children: children.map(&:to_h)
        )
        result[:code_type] = code_type if code_type
        result[:first_line_num] = first_line_num if first_line_num
        result[:original_text] = original_text if original_text
        result
      end

      def self.deserialize_from_hash(hash)
        node = new(
          location: ReVIEW::AST::JSONSerializer.restore_location(hash),
          id: hash['id'],
          caption_node: deserialize_caption_from_hash(hash),
          lang: hash['lang'],
          line_numbers: hash['numbered'] || hash['line_numbers'] || false,
          code_type: hash['code_type'],
          original_text: hash['original_text']
        )
        if hash['children']
          hash['children'].each do |child_hash|
            child = ReVIEW::AST::JSONSerializer.deserialize_from_hash(child_hash)
            node.add_child(child) if child.is_a?(ReVIEW::AST::Node)
          end
        end
        node
      end

      private

      def serialize_properties(hash, options)
        hash[:id] = id if id && !id.empty?
        hash[:lang] = lang
        serialize_caption_to_hash(hash, options)
        hash[:line_numbers] = line_numbers
        hash[:code_type] = code_type if code_type
        hash[:first_line_num] = first_line_num if first_line_num
        hash[:original_text] = original_text if original_text
        hash[:children] = children.map { |child| child.serialize_to_hash(options) } if children&.any?
        hash
      end
    end
  end
end
