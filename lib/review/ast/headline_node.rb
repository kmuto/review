# frozen_string_literal: true

require 'review/ast/node'

module ReVIEW
  module AST
    class HeadlineNode < Node
      attr_accessor :level, :label, :caption, :type

      def initialize(location = nil)
        super
        @level = nil
        @label = nil
        @caption = nil
        @type = nil
      end

      def to_h
        super.merge(
          level: level,
          label: label,
          caption: caption,
          type: type
        )
      end
    end
  end
end
