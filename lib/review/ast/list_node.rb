# frozen_string_literal: true

require 'review/ast/node'

module ReVIEW
  module AST
    class ListNode < Node
      attr_reader :list_type
      attr_accessor :start_number, :olnum_start

      def initialize(location: nil, list_type: nil, start_number: nil, olnum_start: nil, **kwargs)
        super(location: location, **kwargs)
        @list_type = list_type # :ul, :ol, :dl
        @start_number = start_number
        @olnum_start = olnum_start # InDesign's olnum starting value (for IDGXML)
      end

      # Convenience methods for type checking
      def ol?
        list_type == :ol
      end

      def ul?
        list_type == :ul
      end

      def dl?
        list_type == :dl
      end

      def to_h
        result = super.merge(
          list_type: list_type
        )
        result[:start_number] = start_number if start_number && start_number != 1
        result
      end

      private

      def serialize_properties(hash, options)
        hash[:list_type] = list_type
        hash[:start_number] = start_number if start_number && start_number != 1
        if options.include_empty_arrays || children.any?
          hash[:children] = children.map { |child| child.serialize_to_hash(options) }
        end
        hash
      end
    end

    class ListItemNode < Node
      attr_reader :level, :number, :item_type, :term_children
      attr_accessor :item_number

      def initialize(location: nil, level: 1, number: nil, item_type: nil, term_children: [], **kwargs)
        super(location: location, **kwargs)
        @level = level
        @number = number
        @item_type = item_type # :dt, :dd, or nil for regular list items
        @term_children = term_children # For definition lists: stores processed term content separately
        @item_number = nil # Absolute item number for ordered lists (set by ListItemNumberingProcessor)
      end

      def to_h
        result = super.merge(
          level: level
        )
        result[:number] = number if number
        result[:item_type] = item_type if item_type
        result[:term_children] = term_children.map(&:to_h) if term_children.any?
        result
      end

      # Convenience methods for type checking
      def definition_term?
        item_type == :dt
      end

      def definition_desc?
        item_type == :dd
      end

      private

      def serialize_properties(hash, options)
        hash[:children] = children.map { |child| child.serialize_to_hash(options) } if children.any?
        hash[:term_children] = term_children.map { |child| child.serialize_to_hash(options) } if term_children.any?
        hash[:level] = level
        hash[:number] = number if number
        hash[:item_type] = item_type if item_type
        hash
      end
    end
  end
end
