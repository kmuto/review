# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

module ReVIEW
  module AST
    class RawContentParser
      def self.parse(content)
        new.parse(content)
      end

      # Parse raw content for builder specification
      # @param content [String, nil]
      # @return [Array<(Array<String>, String)>] builders
      def parse(content)
        return [nil, content] if content.nil? || content.empty?

        if (matched = content.match(/\A\|(.*?)\|(.*)/))
          builders = matched[1].split(',').map { |i| i.gsub(/\s/, '') }
          processed_content = matched[2]
          [builders, processed_content]
        else
          [nil, content]
        end
      end
    end
  end
end
