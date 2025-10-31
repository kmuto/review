# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

module ReVIEW
  module AST
    class Compiler
      # BlockReader - Reads block content with nesting support
      #
      # This class handles reading block content from input,
      # managing nested blocks and tracking block depth.
      class BlockReader
        def initialize(compiler:, file_input:, parent_command:, start_location:, preserve_whitespace:)
          @compiler = compiler
          @f = file_input
          @parent_command = parent_command
          @start_location = start_location
          @preserve_whitespace = preserve_whitespace
          @lines = []
          @nested_blocks = []
          @block_depth = 1
        end

        # Read block content with nesting support
        #
        # @return [Array<Array<String>, Array<BlockData>>] lines and nested blocks
        def read
          while @f.next?
            line = read_line
            process_line(line)
            break if @block_depth == 0
          end

          validate_block_closed!
          [@lines, @nested_blocks]
        end

        private

        def read_line
          line = @f.gets
          unless line
            location_info = @start_location ? @start_location.format_for_error : ''
            raise CompileError, "Unexpected end of file in block //#{@parent_command} started#{location_info}"
          end

          update_location
          line
        end

        def update_location
          @compiler.update_current_location(@f)
        end

        def process_line(line)
          if closing_tag?(line)
            handle_closing_tag(line)
          elsif nested_block_command?(line)
            handle_nested_block(line)
          elsif preprocessor_directive?(line)
            # Skip preprocessor directives
          else
            handle_content_line(line)
          end
        end

        def closing_tag?(line)
          line.start_with?('//}')
        end

        def handle_closing_tag(line)
          @block_depth -= 1
          if @block_depth > 0
            # Nested termination tag - treat as content
            @lines << normalize_line(line)
          end
        end

        def nested_block_command?(line)
          line.match?(%r{\A//[a-z]+})
        end

        def handle_nested_block(line)
          nested_block_data = @compiler.read_block_command(@f, line)
          @nested_blocks << nested_block_data
        rescue CompileError => e
          raise CompileError, "#{e.message} (in nested block within //#{@parent_command})"
        end

        def preprocessor_directive?(line)
          /\A\#@/.match?(line)
        end

        def handle_content_line(line)
          @lines << normalize_line(line)
        end

        def normalize_line(line)
          if @preserve_whitespace
            line.chomp
          else
            line.rstrip
          end
        end

        def validate_block_closed!
          return if @block_depth == 0

          location_info = @start_location ? @start_location.format_for_error : ''
          raise CompileError, "Unclosed block //#{@parent_command} started#{location_info}"
        end
      end
    end
  end
end
