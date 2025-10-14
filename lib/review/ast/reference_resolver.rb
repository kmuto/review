# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/ast/reference_node'
require 'review/ast/inline_node'
require 'review/ast/indexer'
require 'review/exception'

module ReVIEW
  module AST
    # ReferenceResolver - Specialized class for reference resolution
    #
    # Traverses ReferenceNodes contained in AST and resolves them to
    # appropriate reference content using index information.
    class ReferenceResolver
      def initialize(chapter)
        @chapter = chapter
        @book = chapter.book
        @logger = ReVIEW.logger
      end

      # Resolve ReferenceNodes in AST
      def resolve_references(ast)
        # First build indexes (using existing mechanism)
        build_indexes_if_needed(ast)

        # Traverse InlineNodes and resolve their child ReferenceNodes
        resolve_count = 0
        error_count = 0

        visit_all_nodes(ast) do |node|
          if node.is_a?(InlineNode) && reference_children?(node)
            ref_type = node.inline_type
            node.children.each do |child|
              if child.is_a?(ReferenceNode) && !child.resolved?
                if resolve_node(child, ref_type)
                  resolve_count += 1
                else
                  error_count += 1
                end
              end
            end
          end
        end

        @logger.debug("ReferenceResolver: #{resolve_count} references resolved, #{error_count} failed") if @logger
        { resolved: resolve_count, failed: error_count }
      end

      private

      # Check if InlineNode is reference-type with ReferenceNode children
      def reference_children?(inline_node)
        return false unless inline_node.inline_type

        # Check reference-type inline_type
        ref_types = %w[img list table eq fn endnote hd chap chapref sec secref labelref ref]
        return false unless ref_types.include?(inline_node.inline_type)

        # Check if it has ReferenceNode children
        inline_node.children&.any?(ReferenceNode)
      end

      # Build indexes if not already built
      def build_indexes_if_needed(ast)
        # Check if indexes are already built
        # Chapter objects always have footnote_index and ast_indexes_built? methods
        has_indexes = @chapter.footnote_index || @chapter.ast_indexes_built?

        unless has_indexes
          indexer = Indexer.new(@chapter)
          indexer.build_indexes(ast)
        end
      end

      # Resolve ReferenceNode (ref_type taken from parent InlineNode)
      def resolve_node(node, ref_type)
        content = case ref_type
                  when 'img' then resolve_image_ref(node.ref_id)
                  when 'table' then resolve_table_ref(node.ref_id)
                  when 'list' then resolve_list_ref(node.ref_id)
                  when 'eq' then resolve_equation_ref(node.ref_id)
                  when 'fn' then resolve_footnote_ref(node.ref_id)
                  when 'endnote' then resolve_endnote_ref(node.ref_id)
                  when 'chap' then resolve_chapter_ref(node.ref_id)
                  when 'chapref' then resolve_chapter_ref_with_title(node.ref_id)
                  when 'hd' then resolve_headline_ref(node.ref_id)
                  when 'sec' then resolve_section_ref(node.ref_id)
                  when 'secref' then "#{resolve_section_ref(node.ref_id)}節"
                  when 'labelref', 'ref' then resolve_label_ref(node.ref_id)
                  when 'w' then resolve_word_ref(node.ref_id)
                  when 'wb' then resolve_word_ref(node.ref_id) # rubocop:disable Lint/DuplicateBranch
                  else
                    raise CompileError, "Unknown reference type: #{ref_type}"
                  end

        node.resolve!(content)
        !content.nil?
      end

      # Traverse all nodes in AST
      def visit_all_nodes(node, &block)
        yield node if block

        if node.respond_to?(:children) && node.children
          node.children.each { |child| visit_all_nodes(child, &block) }
        end
      end

      # Resolve image references
      def resolve_image_ref(id)
        if @chapter.image_index && @chapter.image_index.number(id)
          "図#{@chapter.number}.#{@chapter.image_index.number(id)}"
        else
          raise CompileError, "Image reference not found: #{id}"
        end
      end

      # Resolve table references
      def resolve_table_ref(id)
        if @chapter.table_index && @chapter.table_index.number(id)
          "表#{@chapter.number}.#{@chapter.table_index.number(id)}"
        else
          raise CompileError, "Table reference not found: #{id}"
        end
      end

      # Resolve list references
      def resolve_list_ref(id)
        if @chapter.list_index && @chapter.list_index.number(id)
          "リスト#{@chapter.number}.#{@chapter.list_index.number(id)}"
        else
          raise CompileError, "List reference not found: #{id}"
        end
      end

      # Resolve equation references
      def resolve_equation_ref(id)
        if @chapter.equation_index && @chapter.equation_index.number(id)
          "式#{@chapter.number}.#{@chapter.equation_index.number(id)}"
        else
          raise CompileError, "Equation reference not found: #{id}"
        end
      end

      # Resolve footnote references
      def resolve_footnote_ref(id)
        if @chapter.footnote_index && @chapter.footnote_index.number(id)
          @chapter.footnote_index.number(id).to_s
        else
          raise CompileError, "Footnote reference not found: #{id}"
        end
      end

      # Resolve endnote references
      def resolve_endnote_ref(id)
        if @chapter.endnote_index && @chapter.endnote_index.number(id)
          @chapter.endnote_index.number(id).to_s
        else
          raise CompileError, "Endnote reference not found: #{id}"
        end
      end

      # Resolve chapter references
      def resolve_chapter_ref(id)
        if @book
          chapter = @book.chapter_by_id(id)
          if chapter
            "第#{chapter.number}章"
          else
            raise CompileError, "Chapter reference not found: #{id}"
          end
        else
          raise CompileError, "Book not available for chapter reference: #{id}"
        end
      end

      # Resolve chapter references with title
      def resolve_chapter_ref_with_title(id)
        if @book
          chapter = @book.chapter_by_id(id)
          if chapter
            "第#{chapter.number}章「#{chapter.title}」"
          else
            raise CompileError, "Chapter reference not found: #{id}"
          end
        else
          raise CompileError, "Book not available for chapter reference: #{id}"
        end
      end

      # Resolve headline references
      def resolve_headline_ref(id)
        # Pipe-separated case: chapter_id|headline_id
        if id.include?('|')
          chapter_id, headline_id = id.split('|', 2).map(&:strip)

          # Search for specified chapter
          if @book
            target_chapter = @book.chapter_by_id(chapter_id)
            unless target_chapter
              raise CompileError, "Chapter not found for headline reference: #{chapter_id}"
            end

            # Search from headline_index of that chapter
            if target_chapter.headline_index
              begin
                headline = target_chapter.headline_index[headline_id]
              rescue KeyError
                headline = nil
              end
            end
          else
            raise CompileError, "Book not available for cross-chapter headline reference: #{id}"
          end
        elsif @chapter.headline_index
          # Same-chapter reference
          begin
            headline = @chapter.headline_index[id]
          rescue KeyError
            headline = nil
          end
        end

        unless headline
          raise CompileError, "Headline not found: #{id}"
        end

        # Return combination of headline number and caption
        # headline.number is array format (e.g. [1, 2, 3]) so join them
        number_str = headline.number.join('.')
        caption = headline.caption || ''

        # Format: "1.2.3 headline text"
        if number_str.empty?
          "「#{caption}」"
        else
          "#{number_str} #{caption}"
        end
      end

      # Resolve section references
      def resolve_section_ref(id)
        # Section references use the same index as headline references
        # However, only return the number (for secref, add "節" suffix)

        # Pipe-separated case: chapter_id|headline_id
        if id.include?('|')
          chapter_id, headline_id = id.split('|', 2).map(&:strip)

          # Search for specified chapter
          if @book
            target_chapter = @book.chapter_by_id(chapter_id)
            unless target_chapter
              raise CompileError, "Chapter not found for section reference: #{chapter_id}"
            end

            # Search from headline_index of that chapter
            if target_chapter.headline_index
              begin
                headline = target_chapter.headline_index[headline_id]
              rescue KeyError
                headline = nil
              end
            end
          else
            raise CompileError, "Book not available for cross-chapter section reference: #{id}"
          end
        elsif @chapter.headline_index
          # Same-chapter reference
          begin
            headline = @chapter.headline_index[id]
          rescue KeyError
            headline = nil
          end
        end

        unless headline
          raise CompileError, "Section not found: #{id}"
        end

        # Return only headline number
        # headline.number is array format (e.g. [1, 2, 3]) so join them
        headline.number.join('.')

        # Format changes by ref_type (expected to be passed from parent method)
        # Here only return number, caller adds "節" etc.
      end

      # Resolve label references
      def resolve_label_ref(id)
        # Label references search multiple indexes (by priority order)
        label_searches = [
          { index: @chapter.image_index, format: ->(item) { "図#{@chapter.number}.#{item.number}" } },
          { index: @chapter.table_index, format: ->(item) { "表#{@chapter.number}.#{item.number}" } },
          { index: @chapter.list_index, format: ->(item) { "リスト#{@chapter.number}.#{item.number}" } },
          { index: @chapter.equation_index, format: ->(item) { "式#{@chapter.number}.#{item.number}" } },
          { index: @chapter.headline_index, format: ->(item) { item.number.join('.') } },
          { index: @chapter.column_index, format: ->(item) { "コラム#{@chapter.number}.#{item.number}" } }
        ]

        # Search each index in order
        label_searches.each do |search|
          next unless search[:index]

          item = find_index_item(search[:index], id)
          return search[:format].call(item) if item
        end

        # TODO: Support for other labeled elements (note, memo, tip, etc.)
        # Currently there are no dedicated indexes for these elements,
        # so we need to add label_index in the future

        raise CompileError, "Label not found: #{id}"
      end

      # Safely search for items from index
      def find_index_item(index, id)
        return nil unless index

        begin
          index[id]
        rescue KeyError
          nil
        end
      end

      # Resolve word references (dictionary lookup)
      def resolve_word_ref(id)
        dictionary = @book.config['dictionary'] || {}
        if dictionary.key?(id)
          dictionary[id]
        else
          raise CompileError, "word not bound: #{id}"
        end
      end
    end
  end
end
