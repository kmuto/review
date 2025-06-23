# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

module ReVIEW
  # LATEXComparator compares two LaTeX strings, ignoring whitespace differences
  # and providing detailed diff information when content differs.
  class LATEXComparator
    class ComparisonResult
      attr_reader :equal, :differences, :normalized_latex1, :normalized_latex2

      def initialize(equal, differences = [], normalized_latex1 = nil, normalized_latex2 = nil)
        @equal = equal
        @differences = differences
        @normalized_latex1 = normalized_latex1
        @normalized_latex2 = normalized_latex2
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
    end

    def initialize(options = {})
      @ignore_whitespace = options.fetch(:ignore_whitespace, true)
      @ignore_blank_lines = options.fetch(:ignore_blank_lines, true)
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

      differences = find_differences(normalized_latex1, normalized_latex2)
      equal = differences.empty?

      ComparisonResult.new(equal, differences, normalized_latex1, normalized_latex2)
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

      if @ignore_blank_lines
        # Remove blank lines
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
      end

      normalized
    end

    # Find differences between normalized LaTeX strings
    def find_differences(latex1, latex2)
      differences = []

      if latex1 != latex2
        differences << {
          type: :content_mismatch,
          expected: latex1,
          actual: latex2,
          description: 'LaTeX content differs'
        }
      end

      differences
    end
  end
end
