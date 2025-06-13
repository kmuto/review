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
    end
  end
end
