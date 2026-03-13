# frozen_string_literal: true

require 'nokogiri'
require 'diff/lcs'
require 'digest'
require_relative 'result'

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

module ReVIEW
  module AST
    module Diff
      # Idgxml comparator for semantic IDGXML comparison
      #
      # Handles IDGXML-specific features like InDesign namespaces (aid:, aid5:)
      # and processing instructions while normalizing for comparison.
      class Idgxml
        # Elements where whitespace is significant
        SIGNIFICANT_WS = %w[code pre].freeze

        # Self-closing elements (void elements) in IDGXML
        VOID_ELEMENTS = %w[br label index].freeze

        PreparedData = Struct.new(:tokens, :signature, :doc, keyword_init: true)

        def initialize
          # No options needed for IDGXML comparison
        end

        # Compare two IDGXML strings
        # @param left [String] First IDGXML content
        # @param right [String] Second IDGXML content
        # @return [Result] Comparison result
        def compare(left, right)
          left_data = prepare(left)
          right_data = prepare(right)

          changes = ::Diff::LCS.sdiff(left_data[:tokens], right_data[:tokens])

          Result.new(left_data[:signature], right_data[:signature], changes)
        end

        # Quick equality check
        # @param left [String] First IDGXML content
        # @param right [String] Second IDGXML content
        # @return [Boolean] true if contents are equivalent
        def equal?(left, right)
          compare(left, right).equal?
        end

        # Get pretty diff output
        # @param left [String] First IDGXML content
        # @param right [String] Second IDGXML content
        # @return [String] Formatted diff
        def diff(left, right)
          compare(left, right).pretty_diff
        end

        private

        def prepare(idgxml)
          doc = canonicalize(parse_xml(idgxml))
          tokens = tokenize(doc)
          signature = subtree_hash(tokens)

          PreparedData.new(tokens: tokens, signature: signature, doc: doc)
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
end
