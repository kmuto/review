# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'diff/lcs'

module ReVIEW
  # LATEXComparator compares two LaTeX strings, ignoring whitespace differences
  # and providing detailed diff information when content differs.
  class LATEXComparator
    class ComparisonResult
      attr_reader :equal, :differences, :normalized_latex1, :normalized_latex2, :line_diffs

      def initialize(equal, differences, normalized_latex1, normalized_latex2, line_diffs)
        @equal = equal
        @differences = differences
        @normalized_latex1 = normalized_latex1
        @normalized_latex2 = normalized_latex2
        @line_diffs = line_diffs
      end

      def equal?
        @equal
      end

      def different?
        !@equal
      end

      def summary
        if equal?
          'LaTeX content is identical'
        else
          "LaTeX content differs: #{@differences.length} difference(s) found"
        end
      end

      # Generate a pretty-printed diff output similar to HtmlDiff
      #
      # @return [String] Human-readable diff output
      def pretty_diff
        return '' if equal? || !@line_diffs

        output = []
        @line_diffs.each do |change|
          action = change.action # '-'(remove) '+'(add) '!'(change) '='(same)
          case action
          when '='
            # Skip unchanged lines for brevity
            next
          when '-'
            output << "- #{change.old_element.inspect}"
          when '+'
            output << "+ #{change.new_element.inspect}"
          when '!'
            output << "- #{change.old_element.inspect}"
            output << "+ #{change.new_element.inspect}"
          end
        end
        output.join("\n")
      end

      # Get a detailed diff report with line numbers
      #
      # @return [String] Detailed diff report
      def detailed_diff
        return "LaTeX content is identical\n" if equal?

        output = []
        output << "LaTeX content differs (#{@differences.length} difference(s) found)"
        output << ''

        if @line_diffs
          output << 'Line-by-line differences:'
          line_num = 0
          @line_diffs.each do |change|
            case change.action
            when '='
              line_num += 1
            when '-'
              output << "  Line #{line_num + 1} (removed): #{change.old_element}"
            when '+'
              line_num += 1
              output << "  Line #{line_num} (added): #{change.new_element}"
            when '!'
              line_num += 1
              output << "  Line #{line_num} (changed):"
              output << "    - #{change.old_element}"
              output << "    + #{change.new_element}"
            end
          end
        end

        output.join("\n")
      end
    end

    def initialize(options = {})
      @ignore_whitespace = options.fetch(:ignore_whitespace, true)
      @ignore_blank_lines = options.fetch(:ignore_blank_lines, true)
      @ignore_paragraph_breaks = options.fetch(:ignore_paragraph_breaks, true)
      @normalize_commands = options.fetch(:normalize_commands, true)
    end

    # Compare two LaTeX strings
    #
    # @param latex1 [String] First LaTeX string
    # @param latex2 [String] Second LaTeX string
    # @return [ComparisonResult] Comparison result
    def compare(latex1, latex2)
      normalized_latex1 = normalize_latex(latex1)
      normalized_latex2 = normalize_latex(latex2)

      # Generate line-by-line diff
      lines1 = normalized_latex1.split("\n")
      lines2 = normalized_latex2.split("\n")
      line_diffs = Diff::LCS.sdiff(lines1, lines2)

      differences = find_differences(normalized_latex1, normalized_latex2, line_diffs)
      equal = differences.empty?

      ComparisonResult.new(equal, differences, normalized_latex1, normalized_latex2, line_diffs)
    end

    # Quick comparison that returns boolean
    #
    # @param latex1 [String] First LaTeX string
    # @param latex2 [String] Second LaTeX string
    # @return [Boolean] True if LaTeX is equivalent
    def equal?(latex1, latex2)
      compare(latex1, latex2).equal?
    end

    private

    # Normalize LaTeX string for comparison
    def normalize_latex(latex)
      return '' if latex.nil? || latex.empty?

      normalized = latex.dup

      # Handle paragraph breaks before removing blank lines
      if @ignore_paragraph_breaks
        # Normalize paragraph breaks (multiple newlines) to single newlines
        normalized = normalized.gsub(/\n\n+/, "\n")
      end

      if @ignore_blank_lines
        # Remove blank lines (but preserve paragraph structure if configured)
        lines = normalized.split("\n")
        lines = lines.reject { |line| line.strip.empty? }
        normalized = lines.join("\n")
      end

      if @ignore_whitespace
        # Normalize whitespace around commands
        normalized = normalized.gsub(/\s*\\\s*/, '\\')
        # Normalize multiple spaces
        normalized = normalized.gsub(/\s+/, ' ')
        # Remove leading/trailing whitespace from lines
        lines = normalized.split("\n")
        lines = lines.map(&:strip)
        normalized = lines.join("\n")
        # Remove leading/trailing whitespace
        normalized = normalized.strip
      end

      if @normalize_commands
        # Normalize command spacing
        normalized = normalized.gsub(/\\([a-zA-Z]+)\s*\{/, '\\\\\\1{')
        # Normalize environment spacing
        normalized = normalized.gsub(/\\(begin|end)\s*\{([^}]+)\}/, '\\\\\\1{\\2}')
        # Add newlines around \begin{...} and \end{...}
        # This makes diffs more readable by putting each environment on its own line
        normalized = normalized.gsub(/([^\n])\\begin\{/, "\\1\n\\\\begin{")
        normalized = normalized.gsub(/\\begin\{([^}]+)\}([^\n])/, "\\\\begin{\\1}\n\\2")
        normalized = normalized.gsub(/([^\n])\\end\{/, "\\1\n\\\\end{")
        normalized = normalized.gsub(/\\end\{([^}]+)\}([^\n])/, "\\\\end{\\1}\n\\2")
      end

      normalized
    end

    # Find differences between normalized LaTeX strings
    def find_differences(latex1, latex2, line_diffs)
      differences = []

      if latex1 != latex2
        # Analyze line-level differences
        line_diffs.each_with_index do |change, idx|
          next if change.action == '='

          case change.action
          when '-'
            differences << {
              type: :line_removed,
              line_number: idx,
              content: change.old_element,
              description: "Line #{idx + 1} removed: #{change.old_element}"
            }
          when '+'
            differences << {
              type: :line_added,
              line_number: idx,
              content: change.new_element,
              description: "Line #{idx + 1} added: #{change.new_element}"
            }
          when '!'
            differences << {
              type: :line_changed,
              line_number: idx,
              old_content: change.old_element,
              new_content: change.new_element,
              description: "Line #{idx + 1} changed: #{change.old_element} -> #{change.new_element}"
            }
          end
        end

        # If no line-level differences were found but content differs,
        # add a generic content mismatch
        if differences.empty?
          differences << {
            type: :content_mismatch,
            expected: latex1,
            actual: latex2,
            description: 'LaTeX content differs (no line-level differences detected)'
          }
        end
      end

      differences
    end
  end
end
