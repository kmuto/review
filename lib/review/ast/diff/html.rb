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
      # Html comparator for semantic HTML comparison
      #
      # Parses HTML, normalizes whitespace and attributes, tokenizes structure,
      # and compares using hash-based comparison for efficiency.
      class Html
        SIGNIFICANT_WS = %w[pre textarea script style code].freeze
        VOID_ELEMENTS = %w[area base br col embed hr img input link meta param source track wbr].freeze

        def initialize
          # No options needed for HTML comparison
        end

        # Compare two HTML strings
        # @param left [String] First HTML content
        # @param right [String] Second HTML content
        # @return [Result] Comparison result
        def compare(left, right)
          left_data = prepare(left)
          right_data = prepare(right)

          changes = ::Diff::LCS.sdiff(left_data[:tokens], right_data[:tokens])

          Result.new(left_data[:hash], right_data[:hash], changes)
        end

        # Quick equality check
        # @param left [String] First HTML content
        # @param right [String] Second HTML content
        # @return [Boolean] true if contents are equivalent
        def equal?(left, right)
          compare(left, right).equal?
        end

        # Get pretty diff output
        # @param left [String] First HTML content
        # @param right [String] Second HTML content
        # @return [String] Formatted diff
        def diff(left, right)
          compare(left, right).pretty_diff
        end

        private

        PreparedData = Struct.new(:tokens, :hash, :doc, keyword_init: true)

        def prepare(html)
          doc = canonicalize(parse_html(html))
          tokens = tokenize(doc)
          hash = subtree_hash(tokens)

          PreparedData.new(tokens: tokens, hash: hash, doc: doc)
        end

        def parse_html(html)
          Nokogiri::HTML5.parse(html)
        end

        def canonicalize(doc)
          remove_comment!(doc)

          doc.traverse do |node|
            next unless node.text? || node.element?

            if node.text?
              preserve = node.ancestors.any? { |a| SIGNIFICANT_WS.include?(a.name) }
              unless preserve
                text = node.text.gsub(/\s+/, ' ').strip
                if text.empty?
                  node.remove
                else
                  node.content = text
                end
              end
            elsif node.element?
              node.attribute_nodes.each do |attr|
                next if attr.name == attr.name.downcase

                node.delete(attr.name)
                node[attr.name.downcase] = attr.value
              end

              if node['class']
                classes = node['class'].split(/\s+/).reject(&:empty?).uniq.sort
                if classes.empty?
                  node.remove_attribute('class')
                else
                  node['class'] = classes.join(' ')
                end
              end
            end
          end

          doc
        end

        def remove_comment!(doc)
          doc.xpath('//comment()').remove
        end

        # Structured token array
        # [:start, tag_name, [[attr, val], ...]] / [:end, tag_name] / [:void, tag_name, [[attr, val], ...]] / [:text, "content"]
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
