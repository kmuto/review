# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

module ReVIEW
  module AST
    # HeadlineParser - Parses headline syntax and extracts components
    #
    # This class is responsible for parsing headline lines and extracting:
    # - Level (number of = characters)
    # - Tag (e.g., [column], [nonum])
    # - Label (e.g., {label})
    # - Caption text
    class HeadlineParser
      MAX_HEADLINE_LEVEL = 6

      # Parse result class with helper methods
      class ParseResult
        attr_reader :level, :tag, :label, :caption

        def initialize(level:, tag:, label:, caption:)
          @level = level
          @tag = tag
          @label = label
          @caption = caption
        end

        # Check if this is a column tag
        def column?
          @tag == 'column'
        end

        # Check if this is a closing tag (e.g., /column)
        def closing_tag?
          @tag&.start_with?('/')
        end

        # Get the closing tag name without the leading '/'
        # Returns nil if not a closing tag
        def closing_tag_name
          return nil unless closing_tag?

          @tag[1..-1]
        end

        # Check if caption text exists
        def caption?
          !@caption.nil? && !@caption.empty?
        end
      end

      # Parse headline line and return components
      #
      # @param line [String] headline line (e.g., "== [nonum]{label}Caption")
      # @param location [SnapshotLocation] location information for error messages
      # @return [ParseResult, nil] parsed result or nil if not a headline
      def self.parse(line, location: nil)
        new(line, location: location).parse
      end

      def initialize(line, location: nil)
        @line = line
        @location = location
      end

      def parse
        level_match = /\A(=+)(?:\[(.+?)\])?/.match(@line)
        return nil unless level_match

        level = level_match[1].size
        validate_level!(level)

        tag = level_match[2]
        remaining = @line[level_match.end(0)..-1].strip
        label, caption = extract_label_and_caption(remaining)

        ParseResult.new(level: level, tag: tag, label: label, caption: caption)
      end

      private

      def validate_level!(level)
        return if level <= MAX_HEADLINE_LEVEL

        error_msg = "Invalid header: max headline level is #{MAX_HEADLINE_LEVEL}"
        error_msg += " at line #{@location.lineno}" if @location&.lineno
        error_msg += " in #{@location.filename}" if @location&.filename
        raise CompileError, error_msg
      end

      def extract_label_and_caption(text)
        # Check for old syntax: {label} Caption
        if text =~ /\A\{([^}]+)\}\s*(.+)/
          return [$1, $2.strip]
        end

        # Check for new syntax: Caption{label} - but only if the last {...} is not part of inline markup
        if text.match(/\A(.+?)\{([^}]+)\}\s*\z/) && !$1.match?(/@<[^>]+>\s*\z/)
          return [$2, $1.strip]
        end

        # No label, or label is part of inline markup - treat everything as caption
        [nil, text]
      end
    end
  end
end
