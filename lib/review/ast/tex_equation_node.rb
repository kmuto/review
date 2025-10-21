# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/ast/node'
require 'review/ast/caption_node'

module ReVIEW
  module AST
    # TexEquationNode - LaTeX mathematical equation block
    #
    # Represents LaTeX equation blocks like:
    # //texequation{
    # \int_{-\infty}^{\infty} e^{-x^2} dx = \sqrt{\pi}
    # //}
    #
    # //texequation[eq1][Caption]{
    # E = mc^2
    # //}
    class TexEquationNode < Node
      attr_accessor :caption_node
      attr_reader :id, :caption, :latex_content

      def initialize(location:, id: nil, caption: nil, caption_node: nil, latex_content: nil)
        super(location: location)
        @id = id
        @caption = caption
        @caption_node = caption_node
        @latex_content = latex_content || ''
      end

      # Check if this equation has an ID for referencing
      def id?
        !@id.nil? && !@id.empty?
      end

      # Check if this equation has a caption
      def caption?
        !(caption.nil? && caption_node.nil?)
      end

      # Get the LaTeX content without trailing newline
      def content
        @latex_content.chomp
      end

      # String representation for debugging
      def to_s
        "TexEquationNode(id: #{@id.inspect}, caption: #{@caption.inspect})"
      end
    end
  end
end
