# frozen_string_literal: true

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
