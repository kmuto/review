# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/ast/node'

module ReVIEW
  module AST
    # FootnoteNode represents a footnote definition in the AST
    #
    # This node corresponds to the //footnote command in Re:VIEW syntax.
    # It stores the footnote ID and content for proper indexing and rendering.
    class FootnoteNode < Node
      attr_reader :id, :content, :footnote_type

      def initialize(location:, id:, content: nil, footnote_type: :footnote)
        super(location: location)
        @id = id
        @content = content
        @footnote_type = footnote_type # :footnote or :endnote
      end

      def self.from_doc(doc, location)
        node = new(
          location: location,
          id: doc['id'],
          content: doc['content'],
          footnote_type: (doc['footnote_type'] || 'footnote').to_sym
        )
        load_children_from_doc(doc, node, location)
        node
      end
    end
  end
end
