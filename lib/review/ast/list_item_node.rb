# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/ast/node'

module ReVIEW
  module AST
    # Node representing a list item
    class ListItemNode < Node
      attr_reader :level, :content, :number

      def initialize(location:, level: nil, content: nil, number: nil)
        super(location: location)
        @level = level
        @content = content
        @number = number
      end

      def type
        'ListItemNode'
      end

      def as_json
        json = super
        json.delete('type') # ListItemNode doesn't need type in JSON output
        json
      end
    end
  end
end
