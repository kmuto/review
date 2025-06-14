# frozen_string_literal: true

require 'review/ast/node'

module ReVIEW
  module AST
    class DocumentNode < Node
      attr_accessor :title, :chapters

      def initialize(location = nil)
        super
        @title = nil
        @chapters = []
      end

      def to_h
        super.merge(
          title: title,
          chapters: chapters&.map(&:to_h)
        )
      end

      protected

      def serialize_properties(hash, options)
        hash[:children] = children.map { |child| child.serialize_to_hash(options) }
        hash[:title] = title
        if options.include_empty_arrays || (chapters && chapters.any?)
          hash[:chapters] = chapters&.map { |chapter| chapter.serialize_to_hash(options) } || []
        end
        hash
      end
    end
  end
end
