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
    class HtmlDiff
      SIGNIFICANT_WS = %w[pre textarea script style code].freeze
      VOID_ELEMENTS = %w[area base br col embed hr img input link meta param source track wbr].freeze

      Result = Struct.new(:tokens, :root_hash, :doc)

      def initialize(content1, content2)
        @content1 = prepare(content1)
        @content2 = prepare(content2)
      end

      def same_hash?
        @content1.root_hash == @content2.root_hash
      end

      def diff_tokens
        Diff::LCS.sdiff(@content1.tokens, @content2.tokens)
      end

      def pretty_diff
        diff_tokens.map do |change|
          action = change.action # '-'(remove) '+'(add) '!'(change) '='(same)
          case action
          when '='
            next
          when '-', '+'
            tok = change.send(action == '-' ? :old_element : :new_element)
            "#{action} #{tok.inspect}"
          when '!'
            "- #{change.old_element.inspect}\n+ #{change.new_element.inspect}"
          end
        end.compact.join("\n")
      end

      private

      def prepare(html)
        doc = canonicalize(parse_html(html))
        tokens = tokenize(doc)
        Result.new(tokens, subtree_hash(tokens), doc)
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

# Usage:
# html1 = File.read("a.html")
# html2 = File.read("b.html")
#
# diff = ReVIEW::AST::HtmlDiff.new(html1, html2)
# puts "root hash equal? #{diff.same_hash?}"
# puts diff.pretty_diff
