# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/exception'

module ReVIEW
  module AST
    # Token classes using Ruby 3.2+ Data class for immutable, structured tokens

    # Text token for plain text content
    TextToken = Data.define(:content) do
      def type
        :text
      end
    end

    # Inline element token for @<command>{content} syntax
    InlineToken = Data.define(:command, :content, :start_pos, :end_pos) do
      def type
        :inline
      end
    end
    # InlineTokenizer - Tokenizes inline markup syntax into structured tokens
    #
    # This class handles the parsing of Re:VIEW inline markup syntax and converts
    # it into a sequence of tokens that can be processed by the InlineProcessor.
    # It supports both brace syntax (@<cmd>{...}) and fence syntax (@<cmd>$...$, @<cmd>|...|).
    #
    # Responsibilities:
    # - Parse inline markup strings into tokens
    # - Handle escaped characters and nested braces
    # - Support multiple delimiter types (braces, fences)
    # - Maintain position tracking for error reporting
    class InlineTokenizer
      # Tokenize string into inline elements and text parts
      # @param str [String] The input string to tokenize
      # @return [Array<Token>] Array of Token objects (TextToken or InlineToken)
      def tokenize(str)
        tokens = []
        pos = 0

        while pos < str.length
          # Look for any @<...> pattern first to catch invalid command names
          match = str.match(/@<([^>]*)>([{$|])/, pos)

          if match
            # Add text before the match as plain text token
            if match.begin(0) > pos
              text_content = str[pos...match.begin(0)]
              tokens << TextToken.new(content: text_content) unless text_content.empty?
            end

            # Validate command name - only ASCII lowercase letters allowed
            command = match[1]
            if command.empty?
              raise ReVIEW::InlineTokenizeError, "Invalid command name '#{command}': command name cannot be empty"
            elsif !command.match(/\A[a-z]+\z/)
              raise ReVIEW::InlineTokenizeError, "Invalid command name '#{command}': only ASCII lowercase letters are allowed"
            end

            # Parse the inline element
            inline_token = parse_inline_element_at(str, match.begin(0))
            if inline_token
              tokens << inline_token
              pos = inline_token.end_pos
            else
              # Failed to parse as inline element, treat as text
              tokens << TextToken.new(content: match[0])
              pos = match.end(0)
            end
          else
            # No more inline elements, add remaining text
            remaining_text = str[pos..-1]
            tokens << TextToken.new(content: remaining_text) unless remaining_text.empty?
            break
          end
        end

        tokens
      end

      private

      # Parse inline element at specific position
      def parse_inline_element_at(str, start_pos)
        # Match @<command> part from the specified position - only ASCII lowercase letters allowed
        substring = str[start_pos..-1]
        command_match = substring.match(/\A@<([a-z]+)>([{$|])/)
        return nil unless command_match

        command = command_match[1]

        # Command name validation is now enforced by the regex pattern
        # Only ASCII lowercase letters [a-z] are allowed

        delimiter = command_match[2]
        content_start = start_pos + command_match[0].length

        # Find matching closing delimiter
        case delimiter
        when '{'
          content, end_pos = parse_brace_content(str, content_start)
        when '$', '|'
          content, end_pos = parse_fence_content(str, content_start, delimiter)
        else
          return nil
        end

        return nil unless content && end_pos

        InlineToken.new(
          command: command,
          content: content,
          start_pos: start_pos,
          end_pos: end_pos
        )
      end

      # Parse content within braces, handling escaped braces
      def parse_brace_content(str, start_pos)
        content = ''
        pos = start_pos
        brace_count = 1

        while pos < str.length && brace_count > 0
          char = str[pos]

          case char
          when "\n", "\r"
            # Line breaks are not allowed within inline elements
            raise ReVIEW::InlineTokenizeError, 'Line breaks are not allowed within inline elements'
          when '\\'
            # Handle escaped character
            if pos + 1 < str.length
              content += char + str[pos + 1]
              pos += 2
            else
              content += char
              pos += 1
            end
          when '{'
            brace_count += 1
            content += char
            pos += 1
          when '}'
            brace_count -= 1
            if brace_count > 0
              content += char
            end
            pos += 1
          else
            content += char
            pos += 1
          end
        end

        # Return content and end position if properly closed
        if brace_count == 0
          [content, pos]
        else
          raise ReVIEW::InlineTokenizeError, 'Unclosed inline element braces'
        end
      end

      # Parse content within fence delimiters
      def parse_fence_content(str, start_pos, delimiter)
        end_pos = str.index(delimiter, start_pos)
        unless end_pos
          raise ReVIEW::InlineTokenizeError, 'Unclosed inline element fence'
        end

        content = str[start_pos...end_pos]

        # Check for line breaks in fence content
        if content.include?("\n") || content.include?("\r")
          raise ReVIEW::InlineTokenizeError, 'Line breaks are not allowed within inline elements'
        end

        # Check for nested fence syntax which can be confusing
        if /@<[a-z]+>[{$|]/.match?(content)
          raise ReVIEW::InlineTokenizeError, 'Nested inline elements within fence syntax are not allowed'
        end

        [content, end_pos + 1]
      end
    end
  end
end
