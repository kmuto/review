# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'nokogiri'

module ReVIEW
  # HTMLComparator compares two HTML strings, ignoring whitespace differences
  # and providing detailed diff information when content differs.
  class HTMLComparator
    class ComparisonResult
      attr_reader :equal, :differences, :normalized_html1, :normalized_html2

      def initialize(equal, differences = [], normalized_html1 = nil, normalized_html2 = nil)
        @equal = equal
        @differences = differences
        @normalized_html1 = normalized_html1
        @normalized_html2 = normalized_html2
      end

      def equal?
        @equal
      end

      def different?
        !@equal
      end

      def summary
        if equal?
          'HTML content is identical'
        else
          "HTML content differs: #{@differences.length} difference(s) found"
        end
      end
    end

    def initialize(options = {})
      @ignore_whitespace = options.fetch(:ignore_whitespace, true)
      @ignore_attribute_order = options.fetch(:ignore_attribute_order, true)
      @normalize_quotes = options.fetch(:normalize_quotes, true)
      @case_sensitive = options.fetch(:case_sensitive, true)
    end

    # Compare two HTML strings
    #
    # @param html1 [String] First HTML string
    # @param html2 [String] Second HTML string
    # @return [ComparisonResult] Comparison result
    def compare(html1, html2)
      normalized_html1 = normalize_html(html1)
      normalized_html2 = normalize_html(html2)

      differences = find_differences(normalized_html1, normalized_html2)
      equal = differences.empty?

      ComparisonResult.new(equal, differences, normalized_html1, normalized_html2)
    end

    # Quick comparison that returns boolean
    #
    # @param html1 [String] First HTML string
    # @param html2 [String] Second HTML string
    # @return [Boolean] True if HTML is equivalent
    def equal?(html1, html2)
      compare(html1, html2).equal?
    end

    # Compare HTML structure using DOM parsing
    #
    # @param html1 [String] First HTML string
    # @param html2 [String] Second HTML string
    # @return [ComparisonResult] Comparison result
    def compare_dom(html1, html2)
      begin
        doc1 = parse_html_fragment(html1)
        doc2 = parse_html_fragment(html2)

        normalized_html1 = normalize_dom(doc1)
        normalized_html2 = normalize_dom(doc2)

        differences = compare_dom_nodes(doc1, doc2)
        equal = differences.empty?

        ComparisonResult.new(equal, differences, normalized_html1, normalized_html2)
      rescue StandardError => e
        # Fall back to string comparison if DOM parsing fails
        differences = ["DOM parsing failed: #{e.message}"]
        ComparisonResult.new(false, differences, html1, html2)
      end
    end

    private

    # Normalize HTML string for comparison
    def normalize_html(html)
      return '' if html.nil? || html.empty?

      normalized = html.dup

      if @ignore_whitespace
        # Normalize whitespace between tags
        normalized = normalized.gsub(/>\s+</, '><')
        # Normalize internal whitespace
        normalized = normalized.gsub(/\s+/, ' ')
        # Remove leading/trailing whitespace
        normalized = normalized.strip
      end

      if @normalize_quotes
        # Normalize quotes in attributes (single to double)
        normalized = normalized.gsub(/='([^']*)'/, '="\1"')
      end

      unless @case_sensitive
        # Convert to lowercase for case-insensitive comparison
        normalized = normalized.downcase
      end

      normalized
    end

    # Parse HTML fragment using Nokogiri
    def parse_html_fragment(html)
      # Wrap in a div to handle fragments
      wrapped_html = "<div>#{html}</div>"
      doc = Nokogiri::HTML::DocumentFragment.parse(wrapped_html)
      doc.children.first # Return the wrapping div
    end

    # Normalize DOM structure
    def normalize_dom(node)
      return '' unless node

      if node.text?
        text = node.content
        return @ignore_whitespace ? text.strip.gsub(/\s+/, ' ') : text
      end

      tag_name = @case_sensitive ? node.name : node.name.downcase

      # Sort attributes for consistent comparison
      attributes = if @ignore_attribute_order
                     node.attributes.sort.map do |name, attr|
                       value = @normalize_quotes ? "\"#{attr.value}\"" : attr.value
                       name_normalized = @case_sensitive ? name : name.downcase
                       "#{name_normalized}=#{value}"
                     end.join(' ')
                   else
                     node.attributes.map do |name, attr|
                       value = @normalize_quotes ? "\"#{attr.value}\"" : attr.value
                       name_normalized = @case_sensitive ? name : name.downcase
                       "#{name_normalized}=#{value}"
                     end.join(' ')
                   end

      attr_str = attributes.empty? ? '' : " #{attributes}"

      if node.children.empty?
        "<#{tag_name}#{attr_str}>"
      else
        children_html = node.children.map { |child| normalize_dom(child) }.join
        "<#{tag_name}#{attr_str}>#{children_html}</#{tag_name}>"
      end
    end

    # Find differences between normalized HTML strings
    def find_differences(html1, html2)
      differences = []

      if html1 != html2
        differences << {
          type: :content_mismatch,
          expected: html1,
          actual: html2,
          description: 'HTML content differs'
        }
      end

      differences
    end

    # Compare DOM nodes recursively
    def compare_dom_nodes(node1, node2, path = [])
      differences = []

      # Check node types
      if node1.type != node2.type
        differences << {
          type: :node_type_mismatch,
          path: path.join(' > '),
          expected: node1.type,
          actual: node2.type,
          description: "Node type mismatch at #{path.join(' > ')}"
        }
        return differences
      end

      # Check text nodes
      if node1.text?
        text1 = @ignore_whitespace ? node1.content.strip.gsub(/\s+/, ' ') : node1.content
        text2 = @ignore_whitespace ? node2.content.strip.gsub(/\s+/, ' ') : node2.content

        unless @case_sensitive
          text1 = text1.downcase
          text2 = text2.downcase
        end

        if text1 != text2
          differences << {
            type: :text_content_mismatch,
            path: path.join(' > '),
            expected: text1,
            actual: text2,
            description: "Text content differs at #{path.join(' > ')}"
          }
        end
        return differences
      end

      # Check element nodes
      if node1.element?
        # Check tag names
        tag1 = @case_sensitive ? node1.name : node1.name.downcase
        tag2 = @case_sensitive ? node2.name : node2.name.downcase

        if tag1 != tag2
          differences << {
            type: :tag_name_mismatch,
            path: path.join(' > '),
            expected: tag1,
            actual: tag2,
            description: "Tag name mismatch at #{path.join(' > ')}"
          }
          return differences
        end

        # Check attributes
        attr_diffs = compare_attributes(node1.attributes, node2.attributes, path)
        differences.concat(attr_diffs)

        # Check children count
        if node1.children.length != node2.children.length
          differences << {
            type: :children_count_mismatch,
            path: path.join(' > '),
            expected: node1.children.length,
            actual: node2.children.length,
            description: "Children count mismatch at #{path.join(' > ')}"
          }
        end

        # Compare children recursively
        [node1.children.length, node2.children.length].min.times do |i|
          child_path = path + ["#{tag1}[#{i}]"]
          child_diffs = compare_dom_nodes(node1.children[i], node2.children[i], child_path)
          differences.concat(child_diffs)
        end
      end

      differences
    end

    # Compare attributes between two nodes
    def compare_attributes(attrs1, attrs2, path)
      differences = []

      all_attr_names = (attrs1.keys + attrs2.keys).uniq

      all_attr_names.each do |name|
        attr1 = attrs1[name]
        attr2 = attrs2[name]

        if attr1.nil? && !attr2.nil?
          differences << {
            type: :missing_attribute,
            path: path.join(' > '),
            attribute: name,
            expected: nil,
            actual: attr2.value,
            description: "Missing attribute '#{name}' at #{path.join(' > ')}"
          }
        elsif !attr1.nil? && attr2.nil?
          differences << {
            type: :extra_attribute,
            path: path.join(' > '),
            attribute: name,
            expected: attr1.value,
            actual: nil,
            description: "Extra attribute '#{name}' at #{path.join(' > ')}"
          }
        elsif !attr1.nil? && !attr2.nil?
          value1 = @case_sensitive ? attr1.value : attr1.value.downcase
          value2 = @case_sensitive ? attr2.value : attr2.value.downcase

          if value1 != value2
            differences << {
              type: :attribute_value_mismatch,
              path: path.join(' > '),
              attribute: name,
              expected: value1,
              actual: value2,
              description: "Attribute '#{name}' value mismatch at #{path.join(' > ')}"
            }
          end
        end
      end

      differences
    end
  end
end
