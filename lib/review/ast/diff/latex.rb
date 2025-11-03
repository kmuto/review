# frozen_string_literal: true

require 'diff/lcs'
require_relative 'result'

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

module ReVIEW
  module AST
    module Diff
      # Latex comparator with configurable normalization options
      #
      # Compares LaTeX strings with options to ignore whitespace differences,
      # blank lines, and normalize command formatting.
      class Latex
        # @param ignore_whitespace [Boolean] Normalize whitespace for comparison
        # @param ignore_blank_lines [Boolean] Remove blank lines before comparison
        # @param ignore_paragraph_breaks [Boolean] Normalize paragraph breaks
        # @param normalize_commands [Boolean] Normalize LaTeX command formatting
        def initialize(ignore_whitespace: true, ignore_blank_lines: true,
                       ignore_paragraph_breaks: true, normalize_commands: true)
          @ignore_whitespace = ignore_whitespace
          @ignore_blank_lines = ignore_blank_lines
          @ignore_paragraph_breaks = ignore_paragraph_breaks
          @normalize_commands = normalize_commands
        end

        # Compare two LaTeX strings
        # @param left [String] First LaTeX content
        # @param right [String] Second LaTeX content
        # @return [Result] Comparison result
        def compare(left, right)
          normalized_left = normalize_latex(left)
          normalized_right = normalize_latex(right)

          # Generate line-by-line diff
          lines_left = normalized_left.split("\n")
          lines_right = normalized_right.split("\n")
          changes = ::Diff::LCS.sdiff(lines_left, lines_right)

          # For LaTeX, signatures are the normalized strings themselves
          Result.new(normalized_left, normalized_right, changes)
        end

        # Quick equality check
        # @param left [String] First LaTeX content
        # @param right [String] Second LaTeX content
        # @return [Boolean] true if contents are equivalent
        def equal?(left, right)
          compare(left, right).equal?
        end

        # Get pretty diff output
        # @param left [String] First LaTeX content
        # @param right [String] Second LaTeX content
        # @return [String] Formatted diff
        def diff(left, right)
          compare(left, right).pretty_diff
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
      end
    end
  end
end
