# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/ast/reference_node'
require 'review/ast/resolved_data'
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
      end

      def resolve_references(ast)
        # First build indexes (using existing mechanism)
        build_indexes_from_ast(ast)

        # Traverse InlineNodes and resolve their child ReferenceNodes
        resolve_count = 0
        error_count = 0

        visit_all_nodes(ast) do |node|
          next unless node.is_a?(InlineNode)

          if reference_children?(node)
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

        { resolved: resolve_count, failed: error_count }
      end

      private

      # Check if InlineNode is reference-type with ReferenceNode children
      def reference_children?(inline_node)
        return false unless inline_node.inline_type

        # Check reference-type inline_type
        ref_types = %w[img list table eq fn endnote hd chap chapref sec secref labelref ref w wb]
        return false unless ref_types.include?(inline_node.inline_type)

        # Check if it has ReferenceNode children
        inline_node.children.any?(ReferenceNode)
      end

      def build_indexes_from_ast(ast)
        # Always build indexes from the current AST
        # This ensures indexes are up-to-date with the current content
        indexer = Indexer.new(@chapter)
        indexer.build_indexes(ast)
      end

      # Resolve ReferenceNode (ref_type taken from parent InlineNode)
      def resolve_node(node, ref_type)
        # Build full reference ID from context_id and ref_id if context_id exists
        full_ref_id = if node.context_id
                        "#{node.context_id}|#{node.ref_id}"
                      else
                        node.ref_id
                      end

        resolved_data = case ref_type
                        when 'img' then resolve_image_ref(full_ref_id)
                        when 'table' then resolve_table_ref(full_ref_id)
                        when 'list' then resolve_list_ref(full_ref_id)
                        when 'eq' then resolve_equation_ref(full_ref_id)
                        when 'fn' then resolve_footnote_ref(full_ref_id)
                        when 'endnote' then resolve_endnote_ref(full_ref_id)
                        when 'chap' then resolve_chapter_ref(full_ref_id)
                        when 'chapref' then resolve_chapter_ref_with_title(full_ref_id)
                        when 'hd' then resolve_headline_ref(full_ref_id)
                        when 'sec', 'secref' then resolve_section_ref(full_ref_id)
                        when 'labelref', 'ref' then resolve_label_ref(full_ref_id)
                        when 'w', 'wb' then resolve_word_ref(full_ref_id)
                        else
                          raise CompileError, "Unknown reference type: #{ref_type}"
                        end

        # Create resolved node and replace in parent
        resolved_node = node.with_resolved_data(resolved_data)
        node.parent&.replace_child(node, resolved_node)

        !resolved_data.nil?
      end

      # Traverse all nodes in AST
      def visit_all_nodes(node, &block)
        yield node

        node.children.each { |child| visit_all_nodes(child, &block) }
      end

      # Resolve image references
      def resolve_image_ref(id)
        if id.include?('|')
          # Cross-chapter reference
          chapter_id, item_id = split_cross_chapter_ref(id)
          target_chapter = find_chapter_by_id(chapter_id)
          raise CompileError, "Chapter not found for image reference: #{chapter_id}" unless target_chapter

          if target_chapter.image_index && (item = find_index_item(target_chapter.image_index, item_id))
            ResolvedData.image(
              chapter_number: target_chapter.number,
              item_number: index_item_number(item),
              chapter_id: chapter_id,
              item_id: item_id,
              caption: extract_caption(item)
            )
          else
            raise CompileError, "Image reference not found: #{id}"
          end
        elsif (item = find_index_item(@chapter.image_index, id))
          # Same-chapter reference
          ResolvedData.image(
            chapter_number: @chapter.number,
            item_number: index_item_number(item),
            item_id: id,
            caption: extract_caption(item)
          )
        else
          raise CompileError, "Image reference not found: #{id}"
        end
      rescue KeyError
        raise CompileError, "Image reference not found: #{id}"
      end

      # Resolve table references
      def resolve_table_ref(id)
        if id.include?('|')
          # Cross-chapter reference
          chapter_id, item_id = split_cross_chapter_ref(id)
          target_chapter = find_chapter_by_id(chapter_id)
          raise CompileError, "Chapter not found for table reference: #{chapter_id}" unless target_chapter

          if target_chapter.table_index && (item = find_index_item(target_chapter.table_index, item_id))
            ResolvedData.table(
              chapter_number: target_chapter.number,
              item_number: index_item_number(item),
              chapter_id: chapter_id,
              item_id: item_id,
              caption: extract_caption(item)
            )
          else
            raise CompileError, "Table reference not found: #{id}"
          end
        elsif (item = find_index_item(@chapter.table_index, id))
          # Same-chapter reference
          ResolvedData.table(
            chapter_number: @chapter.number,
            item_number: index_item_number(item),
            item_id: id,
            caption: extract_caption(item)
          )
        else
          raise CompileError, "Table reference not found: #{id}"
        end
      end

      # Resolve list references
      def resolve_list_ref(id)
        if id.include?('|')
          # Cross-chapter reference
          chapter_id, item_id = split_cross_chapter_ref(id)
          target_chapter = find_chapter_by_id(chapter_id)
          raise CompileError, "Chapter not found for list reference: #{chapter_id}" unless target_chapter

          if target_chapter.list_index && (item = find_index_item(target_chapter.list_index, item_id))
            ResolvedData.list(
              chapter_number: target_chapter.number,
              item_number: index_item_number(item),
              chapter_id: chapter_id,
              item_id: item_id,
              caption: extract_caption(item)
            )
          else
            raise CompileError, "List reference not found: #{id}"
          end
        elsif (item = find_index_item(@chapter.list_index, id))
          # Same-chapter reference
          ResolvedData.list(
            chapter_number: @chapter.number,
            item_number: index_item_number(item),
            item_id: id,
            caption: extract_caption(item)
          )
        else
          raise CompileError, "List reference not found: #{id}"
        end
      end

      # Resolve equation references
      def resolve_equation_ref(id)
        if (item = find_index_item(@chapter.equation_index, id))
          ResolvedData.equation(
            chapter_number: @chapter.number,
            item_number: index_item_number(item),
            item_id: id,
            caption: extract_caption(item)
          )
        else
          raise CompileError, "Equation reference not found: #{id}"
        end
      rescue KeyError
        raise CompileError, "Equation reference not found: #{id}"
      end

      # Resolve footnote references
      def resolve_footnote_ref(id)
        if (item = find_index_item(@chapter.footnote_index, id))
          number = item.respond_to?(:number) ? item.number : nil
          ResolvedData.footnote(
            item_number: number,
            item_id: id,
            caption: extract_caption(item)
          )
        else
          raise CompileError, "Footnote reference not found: #{id}"
        end
      end

      # Resolve endnote references
      def resolve_endnote_ref(id)
        if (item = find_index_item(@chapter.endnote_index, id))
          number = item.respond_to?(:number) ? item.number : nil
          ResolvedData.endnote(
            item_number: number,
            item_id: id,
            caption: extract_caption(item)
          )
        else
          raise CompileError, "Endnote reference not found: #{id}"
        end
      end

      # Resolve chapter references
      def resolve_chapter_ref(id)
        if @book
          chapter = find_chapter_by_id(id)
          if chapter
            ResolvedData.chapter(
              chapter_number: chapter.number,
              chapter_id: id,
              chapter_title: chapter.title
            )
          else
            raise CompileError, "Chapter reference not found: #{id}"
          end
        else
          raise CompileError, "Book not available for chapter reference: #{id}"
        end
      end

      # Resolve chapter references with title
      def resolve_chapter_ref_with_title(id)
        # Use the same method as resolve_chapter_ref
        # The renderer will decide whether to include the title
        resolve_chapter_ref(id)
      end

      # Resolve headline references
      def resolve_headline_ref(id)
        # Pipe-separated case: chapter_id|headline_id
        if id.include?('|')
          chapter_id, headline_id = id.split('|', 2).map(&:strip)

          # Search for specified chapter
          if @book
            target_chapter = find_chapter_by_id(chapter_id)
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

          unless headline
            raise CompileError, "Headline not found: #{id}"
          end

          ResolvedData.headline(
            headline_number: headline.number,
            headline_caption: headline.caption || '',
            chapter_id: chapter_id,
            item_id: headline_id
          )
        elsif @chapter.headline_index
          # Same-chapter reference
          begin
            headline = @chapter.headline_index[id]
          rescue KeyError
            headline = nil
          end

          unless headline
            raise CompileError, "Headline not found: #{id}"
          end

          ResolvedData.headline(
            headline_number: headline.number,
            headline_caption: headline.caption || '',
            item_id: id
          )
        else
          raise CompileError, "Headline not found: #{id}"
        end
      end

      # Resolve section references
      def resolve_section_ref(id)
        # Section references use the same data structure as headline references
        # Renderers will format appropriately (e.g., adding "節" for secref)
        resolve_headline_ref(id)
      end

      # Resolve label references
      def resolve_label_ref(id)
        # Label references search multiple indexes (by priority order)
        # Try to find the label in various indexes and return appropriate ResolvedData

        # Search in image index
        if @chapter.image_index
          item = find_index_item(@chapter.image_index, id)
          if item
            return ResolvedData.image(
              chapter_number: @chapter.number,
              item_number: index_item_number(item),
              item_id: id,
              caption: extract_caption(item)
            )
          end
        end

        # Search in table index
        if @chapter.table_index
          item = find_index_item(@chapter.table_index, id)
          if item
            return ResolvedData.table(
              chapter_number: @chapter.number,
              item_number: index_item_number(item),
              item_id: id,
              caption: extract_caption(item)
            )
          end
        end

        # Search in list index
        if @chapter.list_index
          item = find_index_item(@chapter.list_index, id)
          if item
            return ResolvedData.list(
              chapter_number: @chapter.number,
              item_number: index_item_number(item),
              item_id: id,
              caption: extract_caption(item)
            )
          end
        end

        # Search in equation index
        if @chapter.equation_index
          item = find_index_item(@chapter.equation_index, id)
          if item
            return ResolvedData.equation(
              chapter_number: @chapter.number,
              item_number: index_item_number(item),
              item_id: id,
              caption: extract_caption(item)
            )
          end
        end

        # Search in headline index
        if @chapter.headline_index
          item = find_index_item(@chapter.headline_index, id)
          if item
            return ResolvedData.headline(
              headline_number: item.number,
              headline_caption: item.caption || '',
              item_id: id,
              caption: extract_caption(item)
            )
          end
        end

        # Search in column index
        if @chapter.column_index
          item = find_index_item(@chapter.column_index, id)
          if item
            # Return as a generic type with column information
            data = ResolvedData.new(
              type: :column,
              chapter_number: @chapter.number,
              item_number: index_item_number(item),
              item_id: id,
              caption: extract_caption(item)
            )
            return data
          end
        end

        # TODO: Support for other labeled elements (note, memo, tip, etc.)
        # Currently there are no dedicated indexes for these elements,
        # so we need to add label_index in the future

        raise CompileError, "Label not found: #{id}"
      end

      def index_item_number(item)
        return unless item

        number = item.respond_to?(:number) ? item.number : nil
        number.nil? ? nil : number.to_s
      end

      def extract_caption(item)
        return unless item

        if item.respond_to?(:caption)
          item.caption
        elsif item.respond_to?(:content)
          item.content
        end
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
          ResolvedData.word(
            word_content: dictionary[id],
            item_id: id
          )
        else
          raise CompileError, "word not bound: #{id}"
        end
      end

      # Split cross-chapter reference ID into chapter_id and item_id
      def split_cross_chapter_ref(id)
        id.split('|', 2).map(&:strip)
      end

      # Format chapter item number (e.g., "図1.2", "表3.4")
      def format_chapter_item_number(prefix, chapter_num, item_num)
        "#{prefix}#{chapter_num || ''}.#{item_num}"
      end

      # Find chapter by ID from book's chapter_index
      def find_chapter_by_id(id)
        @book.chapter_index[id]&.content
      rescue KeyError
        nil
      end
    end
  end
end
