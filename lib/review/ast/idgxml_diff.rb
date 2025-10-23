# frozen_string_literal: true

require 'nokogiri'
require 'diff/lcs'
require 'digest'

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

module ReVIEW
  module AST
    # IdgxmlDiff compares two IDGXML strings for semantic equivalence.
    # It parses XML, normalizes it (whitespace, attribute order, etc.),
    # tokenizes the structure, and compares using hash-based comparison.
    #
    # This is similar to HtmlDiff but handles IDGXML-specific features like
    # InDesign namespaces (aid:, aid5:) and processing instructions.
    class IdgxmlDiff
      # Elements where whitespace is significant
      SIGNIFICANT_WS = %w[code pre].freeze

      # Self-closing elements (void elements) in IDGXML
      VOID_ELEMENTS = %w[br label index].freeze

      Result = Struct.new(:tokens, :root_hash, :doc)

      def initialize(content1, content2)
        @content1 = prepare(content1)
        @content2 = prepare(content2)
      end

      # Check if two IDGXML documents are semantically equivalent
      # @return [Boolean]
      def same_hash?
        @content1.root_hash == @content2.root_hash
      end

      # Get diff tokens using LCS algorithm
      # @return [Array<Diff::LCS::Change>]
      def diff_tokens
        Diff::LCS.sdiff(@content1.tokens, @content2.tokens)
      end

      # Generate human-readable diff output
      # @return [String]
      def pretty_diff
        diff_tokens.map do |change|
          action = change.action # '-'(remove) '+'(add) '!'(change) '='(same)
          case action
          when '='
            next
          when '-', '+'
            tok = if action == '-'
                    change.old_element
                  else
                    change.new_element
                  end
            "#{action} #{tok.inspect}"
          when '!'
            "- #{change.old_element.inspect}\n+ #{change.new_element.inspect}"
          end
        end.compact.join("\n")
      end

      private

      def prepare(idgxml)
        doc = canonicalize(parse_xml(idgxml))
        tokens = tokenize(doc)
        Result.new(tokens, subtree_hash(tokens), doc)
      end

      def parse_xml(idgxml)
        # Wrap in a root element if not already wrapped
        # IDGXML fragments may not have a single root
        wrapped = "<root>#{idgxml}</root>"
        Nokogiri::XML(wrapped) do |config|
          config.noblanks.nonet
        end
      end

      def canonicalize(doc)
        remove_comment!(doc)

        doc.traverse do |node|
          next unless node.text? || node.element? || node.processing_instruction?

          if node.text?
            preserve = node.ancestors.any? { |a| SIGNIFICANT_WS.include?(a.name) }
            unless preserve
              # Normalize whitespace
              text = node.text.gsub(/\s+/, ' ').strip
              if text.empty?
                node.remove
              else
                node.content = text
              end
            end
          elsif node.element?
            # Normalize attribute names to lowercase and sort
            node.attribute_nodes.each do |attr|
              # Keep namespace prefixes as-is (aid:, aid5:)
              # Only normalize the local name part
              next if attr.name == attr.name.downcase

              node.delete(attr.name)
              node[attr.name.downcase] = attr.value
            end

            # Normalize class attribute if present
            if node['class']
              classes = node['class'].split(/\s+/).reject(&:empty?).uniq.sort
              if classes.empty?
                node.remove_attribute('class')
              else
                node['class'] = classes.join(' ')
              end
            end
          elsif node.processing_instruction?
            # Processing instructions like <?dtp level="1" section="..."?>
            # Normalize the content by sorting attributes
            # This is important for IDGXML comparison
            content = node.content
            # Parse key="value" pairs and sort them
            pairs = content.scan(/(\w+)="([^"]*)"/)
            if pairs.any?
              sorted_content = pairs.sort_by { |k, _v| k }.map { |k, v| %Q(#{k}="#{v}") }.join(' ')
              node.content = sorted_content
            end
          end
        end

        doc
      end

      def remove_comment!(doc)
        doc.xpath('//comment()').remove
      end

      # Structured token array
      # [:start, tag_name, [[attr, val], ...]] / [:end, tag_name] / [:void, tag_name, [[attr, val], ...]] / [:text, "content"] / [:pi, target, content]
      def tokenize(node, acc = [])
        node.children.each do |n|
          if n.element?
            attrs = n.attribute_nodes.map { |a| [a.name, a.value] }.sort_by { |k, _| k }
            if VOID_ELEMENTS.include?(n.name)
              acc << [:void, n.name, attrs]
            else
              acc << [:start, n.name, attrs]
              tokenize(n, acc)
              acc << [:end, n.name]
            end
          elsif n.text?
            t = n.text
            next if t.nil? || t.empty?

            acc << [:text, t]
          elsif n.processing_instruction?
            # Include processing instructions in tokens
            # Format: [:pi, target, content]
            acc << [:pi, n.name, n.content]
          end
        end
        acc
      end

      def subtree_hash(tokens)
        Digest::SHA1.hexdigest(tokens.map { |t| t.join("\u241F") }.join("\u241E"))
      end
    end
  end
end

# Usage:
# idgxml1 = File.read("a.xml")
# idgxml2 = File.read("b.xml")
#
# diff = ReVIEW::AST::IdgxmlDiff.new(idgxml1, idgxml2)
# puts "Same structure? #{diff.same_hash?}"
# puts diff.pretty_diff unless diff.same_hash?
