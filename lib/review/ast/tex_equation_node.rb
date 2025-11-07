# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require_relative 'node'
require_relative 'caption_node'

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
      attr_reader :id, :latex_content

      def initialize(location:, id: nil, caption_node: nil, latex_content: nil)
        super(location: location)
        @id = id
        @caption_node = caption_node
        @latex_content = latex_content || ''
      end

      def caption_text
        caption_node&.to_text || ''
      end

      def id?
        !@id.nil? && !@id.empty?
      end

      def caption?
        !caption_node.nil?
      end

      # Get the LaTeX content without trailing newline
      def content
        @latex_content.chomp
      end

      def to_s
        "TexEquationNode(id: #{@id.inspect}, caption_node: #{@caption_node.inspect})"
      end
    end
  end
end
