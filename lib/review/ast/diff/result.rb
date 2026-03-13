# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

module ReVIEW
  module AST
    module Diff
      # Result of a diff comparison operation
      #
      # Holds comparison results from any format-specific comparator (Html, Idgxml, Latex).
      # Provides unified interface for checking equality and viewing differences.
      class Result
        # @return [String] Signature/hash of left content
        #   - For Html/Idgxml: SHA1 hash of token structure
        #   - For Latex: normalized string
        attr_reader :left_signature

        # @return [String] Signature/hash of right content
        attr_reader :right_signature

        # @return [Array<Diff::LCS::Change>] Raw diff changes from Diff::LCS.sdiff
        #   - For Html/Idgxml: changes contain token arrays
        #   - For Latex: changes contain line strings
        attr_reader :changes

        # @param left_signature [String] Signature of left content
        # @param right_signature [String] Signature of right content
        # @param changes [Array<Diff::LCS::Change>] Diff::LCS.sdiff output
        def initialize(left_signature, right_signature, changes)
          @left_signature = left_signature
          @right_signature = right_signature
          @changes = changes
        end

        # Check if contents are equal
        # @return [Boolean] true if signatures match
        def equal?
          @left_signature == @right_signature
        end

        # Check if contents are different
        # @return [Boolean] true if signatures don't match
        def different?
          !equal?
        end

        # Alias for equal? to match existing HtmlDiff/IdgxmlDiff API
        # @return [Boolean]
        def same_hash?
          equal?
        end

        # Generate human-readable diff output
        # @return [String] Formatted diff showing changes
        def pretty_diff
          return '' if equal?

          output = []
          @changes.each do |change|
            action = change.action # '-'(remove) '+'(add) '!'(change) '='(same)
            case action
            when '='
              # Skip unchanged lines/tokens for brevity
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

        # Alias for pretty_diff
        # @return [String]
        def diff
          pretty_diff
        end
      end
    end
  end
end
