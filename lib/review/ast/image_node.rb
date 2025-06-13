# frozen_string_literal: true

require 'review/ast/node'

module ReVIEW
  module AST
    class ImageNode < Node
      attr_accessor :id, :caption, :metric

      def initialize(location = nil)
        super
        @id = nil
        @caption = nil
        @metric = nil
      end

      def to_h
        super.merge(
          id: id,
          caption: caption,
          metric: metric
        )
      end
    end
  end
end
