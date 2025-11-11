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
      # Markdown comparator with configurable normalization options
      #
      # Compares Markdown strings with options to ignore whitespace differences,
      # blank lines, and normalize formatting.
      class Markdown
        # @param ignore_whitespace [Boolean] Normalize whitespace for comparison
        # @param ignore_blank_lines [Boolean] Remove blank lines before comparison
        # @param ignore_paragraph_breaks [Boolean] Normalize paragraph breaks
        # @param normalize_headings [Boolean] Normalize heading formatting
        # @param normalize_lists [Boolean] Normalize list formatting
        def initialize(ignore_whitespace: true, ignore_blank_lines: true,
                       ignore_paragraph_breaks: true, normalize_headings: true,
                       normalize_lists: true)
          @ignore_whitespace = ignore_whitespace
          @ignore_blank_lines = ignore_blank_lines
          @ignore_paragraph_breaks = ignore_paragraph_breaks
          @normalize_headings = normalize_headings
          @normalize_lists = normalize_lists
        end

        # Compare two Markdown strings
        # @param left [String] First Markdown content
        # @param right [String] Second Markdown content
        # @return [Result] Comparison result
        def compare(left, right)
          normalized_left = normalize_markdown(left)
          normalized_right = normalize_markdown(right)

          # Generate line-by-line diff
          lines_left = normalized_left.split("\n")
          lines_right = normalized_right.split("\n")
          changes = ::Diff::LCS.sdiff(lines_left, lines_right)

          # For Markdown, signatures are the normalized strings themselves
          Result.new(normalized_left, normalized_right, changes)
        end

        # Quick equality check
        # @param left [String] First Markdown content
        # @param right [String] Second Markdown content
        # @return [Boolean] true if contents are equivalent
        def equal?(left, right)
          compare(left, right).equal?
        end

        # Get pretty diff output
        # @param left [String] First Markdown content
        # @param right [String] Second Markdown content
        # @return [String] Formatted diff
        def diff(left, right)
          compare(left, right).pretty_diff
        end

        private

        # Normalize Markdown string for comparison
        def normalize_markdown(markdown)
          return '' if markdown.nil? || markdown.empty?

          normalized = markdown.dup

          # Handle paragraph breaks before removing blank lines
          if @ignore_paragraph_breaks
            # Normalize paragraph breaks (multiple newlines) to double newlines
            normalized = normalized.gsub(/\n\n+/, "\n\n")
          end

          if @ignore_blank_lines
            # Remove completely blank lines (but preserve paragraph structure if configured)
            lines = normalized.split("\n")
            lines = lines.reject { |line| line.strip.empty? }
            normalized = lines.join("\n")
          end

          if @ignore_whitespace
            # Normalize multiple spaces to single space
            normalized = normalized.gsub(/[ \t]+/, ' ')
            # Remove leading/trailing whitespace from lines
            lines = normalized.split("\n")
            lines = lines.map(&:strip)
            normalized = lines.join("\n")
            # Remove leading/trailing whitespace from entire content
            normalized = normalized.strip
          end

          if @normalize_headings
            # Normalize ATX-style headings (ensure space after #)
            normalized = normalized.gsub(/^(#+)([^# \n])/, '\1 \2')
            # Normalize trailing # in headings (remove them)
            normalized = normalized.gsub(/^(#+\s+.+?)\s*#+\s*$/, '\1')
          end

          if @normalize_lists
            # Normalize unordered list markers (* - +) to consistent marker (*)
            normalized = normalized.gsub(/^(\s*)[-+]\s+/, '\1* ')
            # Normalize list item spacing (ensure single space after marker)
            normalized = normalized.gsub(/^(\s*[*\-+])\s+/, '\1 ')
            normalized = normalized.gsub(/^(\s*\d+\.)\s+/, '\1 ')
          end

          normalized
        end
      end
    end
  end
end
