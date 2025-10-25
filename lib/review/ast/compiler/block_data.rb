# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

module ReVIEW
  module AST
    class Compiler
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
      # @param location [Location] Source location information for error reporting
      BlockData = Struct.new(:name, :args, :lines, :nested_blocks, :location, keyword_init: true) do
        def initialize(name:, args: [], lines: [], nested_blocks: [], location: nil)
          # Type validation
          # Ensure args, lines, nested_blocks are always Arrays
          ensure_array!(args, 'args')
          ensure_array!(lines, 'lines')
          ensure_array!(nested_blocks, 'nested_blocks')

          # Initialize Struct (using keyword_init: true, so pass as hash)
          super
        end

        # Check if this block contains nested block commands
        #
        # @return [Boolean] true if nested_blocks is not empty
        def nested_blocks?
          nested_blocks && nested_blocks.any?
        end

        # Get the total number of content lines (excluding nested blocks)
        #
        # @return [Integer] number of lines
        def line_count
          lines.size
        end

        # Check if the block has any content lines
        #
        # @return [Boolean] true if lines is not empty
        def content?
          lines.any?
        end

        # Get argument at specified index safely
        #
        # @param index [Integer] argument index
        # @return [String, nil] argument value or nil if not found
        def arg(index)
          return nil unless args && index && index.is_a?(Integer) && index >= 0 && args.size > index

          args[index]
        end

        # Convert to hash for debugging/serialization
        #
        # @return [Hash] hash representation of the block data
        def to_h
          {
            name: name,
            args: args,
            lines: lines,
            nested_blocks: nested_blocks.map(&:to_h),
            location: location&.to_h,
            has_nested_blocks: nested_blocks?,
            line_count: line_count
          }
        end

        # String representation for debugging
        #
        # @return [String] debug string
        def inspect
          "#<#{self.class} name=#{name} args=#{args.inspect} lines=#{line_count} nested=#{nested_blocks.size}>"
        end

        private

        # Ensure value is an Array
        # Raises error if value is nil or not an Array
        #
        # @param value [Object] Value to validate
        # @param field_name [String] Field name for error messages
        # @raise [ArgumentError] If value is not an Array
        def ensure_array!(value, field_name)
          unless value.is_a?(Array)
            raise ArgumentError, "BlockData #{field_name} must be an Array, got #{value.class}: #{value.inspect}"
          end
        end
      end
    end
  end
end
