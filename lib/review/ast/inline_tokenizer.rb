# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/exception'

module ReVIEW
  module AST
    # Token classes using Struct for immutable, structured tokens

    # Text token for plain text content
    TextToken = Struct.new(:content, keyword_init: true) do
      def type
        :text
      end
    end

    # Inline element token for @<command>{content} syntax
    InlineToken = Struct.new(:command, :content, :start_pos, :end_pos, keyword_init: true) do
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
    # ## Supported Inline Element Syntax
    #
    # ### Brace Syntax
    # - @<command>{content} - Basic inline element with braces
    # - @<command>{} - Empty content is allowed
    #
    # ### Fence Syntax
    # - @<command>$content$ - Dollar-delimited fence syntax
    # - @<command>|content| - Pipe-delimited fence syntax
    #
    # ## Command Name Rules
    # - Only ASCII lowercase letters [a-z] are allowed
    # - Cannot be empty
    # - Cannot start with numbers or contain uppercase/symbols
    #
    # ## Escape Sequence Rules (Consistent Across All Inline Elements)
    #
    # The tokenizer implements consistent escape rules for all inline element types
    # (@<code>, @<m>, @<b>, etc.) regardless of their semantic meaning:
    #
    # ### Supported Escape Sequences
    # - `\}` → `}` - Escape closing brace to include literal brace in content
    # - `\\` → `\` - Escape backslash to include literal backslash in content
    # - `\@` → `@` - Escape at-sign to include literal at-sign in content
    # - `\{` → `\{` - Opening brace is NOT escaped (preserved as-is)
    # - `\x` → `\x` - Other characters after backslash are preserved as-is
    #
    # ### Termination Rules
    # - Brace elements: Terminated by the FIRST unescaped `}` character
    # - Fence elements: Terminated by the matching fence delimiter
    # - Line breaks are not allowed within inline elements
    #
    # ### No Automatic Brace Balancing
    # - The tokenizer does NOT perform automatic brace balancing
    # - Nested braces must be properly escaped using `\}` when they should be literal
    # - This ensures consistent behavior across all inline element types
    #
    # ## Usage Examples
    #
    # ### LaTeX Math (all braces must be escaped)
    # ```
    # @<m>{\sum_{i=1\}^{n\} x_i}  # Correct: produces \sum_{i=1}^{n} x_i
    # @<m>{\sum_{i=1}^{n} x_i}    # Wrong: terminates at first }
    # ```
    #
    # ### Unbalanced Code (escape literal braces)
    # ```
    # @<code>{if (x > 0) \{ print("positive")}  # Correct: literal { in output
    # @<code>{array[0\]}                        # Correct: literal } in output
    # ```
    #
    # ### JSON Strings (escape all braces)
    # ```
    # @<code>{JSON.parse("\{\"key\": \"value\"\}")}  # Correct: all braces escaped
    # ```
    #
    # ## Error Handling
    # - Unclosed inline elements raise InlineTokenizeError with location info
    # - Invalid command names raise InlineTokenizeError
    # - Line breaks within elements raise InlineTokenizeError
    # - Nested fence syntax raises InlineTokenizeError for clarity
    #
    # Responsibilities:
    # - Parse inline markup strings into tokens
    # - Apply consistent escape sequence rules
    # - Support multiple delimiter types (braces, fences)
    # - Maintain position tracking for error reporting
    # - Enforce consistent termination rules for all element types
    class InlineTokenizer
      # Tokenize string into inline elements and text parts
      # @param str [String] The input string to tokenize
      # @param location [SnapshotLocation] Current file location for error reporting
      # @return [Array<Token>] Array of Token objects (TextToken or InlineToken)
      def tokenize(str, location: nil)
        @location = location
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
              raise ReVIEW::AST::InlineTokenizeError, "Invalid command name '#{command}': command name cannot be empty"
            elsif !command.match(/\A[a-z]+\z/)
              raise ReVIEW::AST::InlineTokenizeError, "Invalid command name '#{command}': only ASCII lowercase letters are allowed"
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
          content, end_pos = parse_brace_content(str, content_start, start_pos)
        when '$', '|'
          content, end_pos = parse_fence_content(str, content_start, delimiter, start_pos)
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

      # Parse content within braces with consistent escape rules
      #
      # This method implements the core escape sequence processing for brace syntax.
      # It processes characters sequentially until the first unescaped '}' is found.
      #
      # ## Escape Processing Rules
      # - `\}` → `}` (escaped closing brace becomes literal)
      # - `\\` → `\` (escaped backslash becomes literal)
      # - `\@` → `@` (escaped at-sign becomes literal)
      # - `\{` → `\{` (opening brace preserved as-is, not escaped)
      # - `\x` → `\x` (other chars after backslash preserved as-is)
      #
      # ## Termination
      # - Always terminates at the FIRST unescaped `}` character
      # - Does NOT perform automatic brace balancing
      # - Line breaks within content raise an error
      #
      # @param str [String] The input string being parsed
      # @param start_pos [Integer] Position after the opening '{'
      # @param element_start [Integer] Position of the '@<' for error reporting
      # @return [Array<String, Integer>] Content and end position, or raises error
      def parse_brace_content(str, start_pos, element_start = nil)
        content = ''
        pos = start_pos

        # Use provided element_start or calculate it
        element_start ||= start_pos - 5 # fallback estimate

        while pos < str.length
          char = str[pos]

          case char
          when "\n", "\r"
            # Line breaks are not allowed within inline elements
            error_msg = 'Line breaks are not allowed within inline elements'
            error_msg += format_location_info_simple(str, element_start)
            raise ReVIEW::AST::InlineTokenizeError, error_msg
          when '\\'
            # Handle escaped character - implements consistent escape rules
            if pos + 1 < str.length
              next_char = str[pos + 1]
              content += case next_char
                         when '}'
                           # \} → } : Escape closing brace (allows literal } in content)
                           '}'
                         when '\\'
                           # \\ → \ : Escape backslash (allows literal \ in content)
                           '\\'
                         when '@'
                           # \@ → @ : Escape at-sign (allows literal @ in content)
                           '@'
                         else
                           # \x → \x : Other characters are NOT escaped (preserve as-is)
                           # This includes \{ which remains \{ (opening brace not escaped)
                           char + next_char
                         end
              pos += 2
            else
              # Backslash at end of string - preserve as-is
              content += char
              pos += 1
            end
          when '}'
            # First unescaped } terminates the inline element (consistent termination rule)
            # No brace balancing is performed - this ensures predictable behavior
            return [content, pos + 1]
          else
            # Regular character - add to content as-is
            content += char
            pos += 1
          end
        end

        # If we reach here, no closing brace was found (reached end of string)
        error_msg = 'Unclosed inline element braces'
        error_msg += format_location_info_simple(str, element_start)
        raise ReVIEW::AST::InlineTokenizeError, error_msg
      end

      # Parse content within fence delimiters
      def parse_fence_content(str, start_pos, delimiter, element_start = nil)
        # Use provided element_start or calculate it
        element_start ||= start_pos - 5 # fallback estimate

        end_pos = str.index(delimiter, start_pos)
        unless end_pos
          error_msg = 'Unclosed inline element fence'
          error_msg += format_location_info_simple(str, element_start)
          raise ReVIEW::AST::InlineTokenizeError, error_msg
        end

        content = str[start_pos...end_pos]

        # Check for line breaks in fence content
        if content.include?("\n") || content.include?("\r")
          error_msg = 'Line breaks are not allowed within inline elements'
          error_msg += format_location_info_simple(str, element_start)
          raise ReVIEW::AST::InlineTokenizeError, error_msg
        end

        # Check for nested fence syntax which can be confusing
        if /@<[a-z]+>[{$|]/.match?(content)
          error_msg = 'Nested inline elements within fence syntax are not allowed'
          error_msg += format_location_info_simple(str, element_start)
          raise ReVIEW::AST::InlineTokenizeError, error_msg
        end

        [content, end_pos + 1]
      end

      # Extract a preview of the problematic element for error display
      def extract_element_preview(str, start_pos)
        # Start from the @< position
        preview_start = start_pos

        # Find the end of the element or a reasonable preview length
        max_preview_length = 50
        preview_end = [start_pos + max_preview_length, str.length].min

        # For fence elements, look for matching delimiters beyond the opening one
        matched = /\A@<[a-z]+>([$|])/.match(str[start_pos..-1])
        if matched
          delimiter = matched[0]
          delimiter_pos = start_pos + matched.end(0) - 1

          # Look for the closing delimiter
          closing_pos = str.index(delimiter, delimiter_pos + 1)
          preview_end = if closing_pos && closing_pos <= start_pos + max_preview_length
                          # Found a proper closing delimiter within reasonable range
                          closing_pos + 1
                        else
                          # No closing delimiter found or too far - show more content
                          [start_pos + max_preview_length, str.length].min
                        end
        else
          # For brace elements, look for the closing brace
          brace_pos = str.index('}', start_pos + 1)
          if brace_pos && brace_pos <= start_pos + max_preview_length
            preview_end = brace_pos + 1
          end
        end

        preview = str[preview_start...preview_end]

        # Add ellipsis if we truncated and don't end with a delimiter
        if preview_end < str.length && !preview.match?(/[}$|]\z/)
          preview += '...'
        end

        preview
      end

      # Simple format for location info when called from tokenize method
      def format_location_info_simple(str, element_pos)
        info = ''

        # Add element information
        element_preview = extract_element_preview(str, element_pos)
        info += " in element: #{element_preview}"

        # Add file location if available
        info += @location.format_for_error if @location

        info
      end
    end
  end
end
