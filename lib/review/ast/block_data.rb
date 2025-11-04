# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

module ReVIEW
  module AST
    # Block command data structure for separating IO reading from block processing
    #
    # This struct encapsulates all information about a block command that has been
    # read from input, including any nested block commands. It serves as the interface
    # between Compiler (IO responsibility) and BlockProcessor (processing responsibility).
    #
    # @param name [Symbol] Block command name (e.g., :list, :note, :table)
    # @param args [Array<String>] Parsed arguments from the command line
    # @param lines [Array<String>] Content lines within the block
    # @param nested_blocks [Array<BlockData>] Any nested block commands found within this block
    # @param location [SnapshotLocation] Source location information for error reporting
    BlockData = Struct.new(:name, :args, :lines, :nested_blocks, :location, keyword_init: true) do
      def nested_blocks?
        nested_blocks && nested_blocks.any?
      end

      def line_count
        lines.size
      end

      def content?
        lines&.any?
      end

      # Get argument at specified index safely
      #
      # @param index [Integer] argument index
      # @return [String, nil] argument value or nil if not found
      def arg(index)
        return nil unless args && index && index >= 0

        args[index]
      end

      def inspect
        "#<#{self.class} name=#{name} args=#{args.inspect} lines=#{line_count} nested=#{nested_blocks.size}>"
      end
    end
  end
end
