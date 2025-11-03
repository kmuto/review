# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/ast/reference_node'
require 'review/ast/resolved_data'
require 'review/ast/inline_node'
require 'review/ast/indexer'
require 'review/ast/visitor'
require 'review/exception'

module ReVIEW
  module AST
    # ReferenceResolver - Specialized class for reference resolution
    #
    # Traverses ReferenceNodes contained in AST and resolves them to
    # appropriate reference content using index information.
    class ReferenceResolver < Visitor
      # Default mapping of reference types to resolver methods
      DEFAULT_RESOLVER_METHODS = {
        img: :resolve_image_ref,
        imgref: :resolve_image_ref,
        table: :resolve_table_ref,
        list: :resolve_list_ref,
        eq: :resolve_equation_ref,
        fn: :resolve_footnote_ref,
        endnote: :resolve_endnote_ref,
        column: :resolve_column_ref,
        chap: :resolve_chapter_ref,
        chapref: :resolve_chapter_ref_with_title,
        title: :resolve_chapter_title,
        hd: :resolve_headline_ref,
        sec: :resolve_section_ref,
        secref: :resolve_section_ref,
        sectitle: :resolve_section_ref,
        labelref: :resolve_label_ref,
        ref: :resolve_label_ref,
        w: :resolve_word_ref,
        wb: :resolve_word_ref,
        bib: :resolve_bib_ref,
        bibref: :resolve_bib_ref
      }.freeze

      def initialize(chapter)
        super()
        @chapter = chapter
        @book = chapter.book
        @resolver_methods = DEFAULT_RESOLVER_METHODS.dup
      end

      def resolve_references(ast)
        # First build indexes (using existing mechanism)
        build_indexes_from_ast(ast)

        # Initialize counters
        @resolve_count = 0
        @error_count = 0

        # Traverse AST using Visitor pattern
        visit(ast)

        { resolved: @resolve_count, failed: @error_count }
      end

      # Register a new reference type resolver
      # @param ref_type [Symbol] The reference type (e.g., :custom)
      # @param resolver_method [Symbol] The method name to handle this reference type
      # @example
      #   resolver.register_resolver_method(:custom, :resolve_custom_ref)
      def register_resolver_method(ref_type, resolver_method)
        @resolver_methods[ref_type.to_sym] = resolver_method
      end

      # @return [Array<Symbol>] List of all registered reference types
      def registered_reference_types
        @resolver_methods.keys
      end

      private

      # Visit caption_node if present on the given node
      def visit_caption_if_present(node)
        visit(node.caption_node) if node.respond_to?(:caption_node) && node.caption_node
      end

      def build_indexes_from_ast(ast)
        # Always build indexes from the current AST
        # This ensures indexes are up-to-date with the current content
        indexer = Indexer.new(@chapter)
        indexer.build_indexes(ast)
      end

      # Resolve ReferenceNode (ref_type taken from parent InlineNode)
      # @param node [ReferenceNode] The reference node to resolve
      # @param ref_type [Symbol] The reference type (e.g., :img, :table, :list)
      def resolve_node(node, ref_type)
        method_name = @resolver_methods[ref_type]
        raise CompileError, "Unknown reference type: #{ref_type}" unless method_name

        resolved_data = send(method_name, node.full_ref_id)

        resolved_node = node.with_resolved_data(resolved_data)
        node.parent&.replace_child(node, resolved_node)

        !resolved_data.nil?
      end

      # Visit document node (root)
      def visit_document(node)
        visit_all(node.children)
      end

      # Visit paragraph node
      def visit_paragraph(node)
        visit_all(node.children)
      end

      # Visit text node (leaf node)
      def visit_text(node)
        # Text nodes don't need processing
      end

      # Visit headline node
      def visit_headline(node)
        visit_caption_if_present(node)
        visit_all(node.children)
      end

      # Visit column node
      def visit_column(node)
        visit_caption_if_present(node)
        visit_all(node.children)
      end

      # Visit code block node
      def visit_code_block(node)
        visit_caption_if_present(node)
        visit_all(node.children)
      end

      # Visit table node
      def visit_table(node)
        visit_caption_if_present(node)
        visit_all(node.children)
      end

      # Visit image node
      def visit_image(node)
        visit_caption_if_present(node)
        visit_all(node.children)
      end

      # Visit minicolumn node
      def visit_minicolumn(node)
        visit_caption_if_present(node)
        visit_all(node.children)
      end

      # Visit embed node
      def visit_embed(node)
        visit_all(node.children)
      end

      # Visit footnote node
      def visit_footnote(node)
        visit_all(node.children)
      end

      # Visit tex equation node
      def visit_tex_equation(node)
        visit_caption_if_present(node)
        visit_all(node.children)
      end

      # Visit block node
      def visit_block(node)
        visit_caption_if_present(node)
        visit_all(node.children)
      end

      # Visit list node
      def visit_list(node)
        visit_all(node.children)
      end

      # Visit list item node
      def visit_list_item(node)
        visit_all(node.term_children) if node.term_children&.any?
        visit_all(node.children)
      end

      # Visit caption node
      def visit_caption(node)
        visit_all(node.children)
      end

      # Visit code line node
      def visit_code_line(node)
        visit_all(node.children)
      end

      # Visit table row node
      def visit_table_row(node)
        visit_all(node.children)
      end

      # Visit table cell node
      def visit_table_cell(node)
        visit_all(node.children)
      end

      # Visit inline node
      def visit_inline(node)
        visit_all(node.children)
      end

      # Visit reference node - main reference resolution logic
      def visit_reference(node)
        return if node.resolved?

        # Get reference type from parent InlineNode
        parent_inline = node.parent
        return unless parent_inline.is_a?(InlineNode)

        ref_type = parent_inline.inline_type

        if resolve_node(node, ref_type.to_sym)
          @resolve_count += 1
        else
          @error_count += 1
        end
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
              chapter_number: format_chapter_number(target_chapter),
              item_number: index_item_number(item),
              chapter_id: chapter_id,
              item_id: item_id,
              caption_node: item.caption_node
            )
          else
            raise CompileError, "Image reference not found: #{id}"
          end
        elsif (item = find_index_item(@chapter.image_index, id))
          # Same-chapter reference
          ResolvedData.image(
            chapter_number: format_chapter_number(@chapter),
            item_number: index_item_number(item),
            item_id: id,
            caption_node: item.caption_node
          )
        else
          raise CompileError, "Image reference not found: #{id}"
        end
      rescue ReVIEW::KeyError
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
              chapter_number: format_chapter_number(target_chapter),
              item_number: index_item_number(item),
              chapter_id: chapter_id,
              item_id: item_id,
              caption_node: item.caption_node
            )
          else
            raise CompileError, "Table reference not found: #{id}"
          end
        elsif (item = find_index_item(@chapter.table_index, id))
          # Same-chapter reference
          ResolvedData.table(
            chapter_number: format_chapter_number(@chapter),
            item_number: index_item_number(item),
            item_id: id,
            caption_node: item.caption_node
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
              chapter_number: format_chapter_number(target_chapter),
              item_number: index_item_number(item),
              chapter_id: chapter_id,
              item_id: item_id,
              caption_node: item.caption_node
            )
          else
            raise CompileError, "List reference not found: #{id}"
          end
        elsif (item = find_index_item(@chapter.list_index, id))
          # Same-chapter reference
          ResolvedData.list(
            chapter_number: format_chapter_number(@chapter),
            item_number: index_item_number(item),
            item_id: id,
            caption_node: item.caption_node
          )
        else
          raise CompileError, "List reference not found: #{id}"
        end
      end

      # Resolve equation references
      def resolve_equation_ref(id)
        if (item = find_index_item(@chapter.equation_index, id))
          ResolvedData.equation(
            chapter_number: format_chapter_number(@chapter),
            item_number: index_item_number(item),
            item_id: id,
            caption_node: item.caption_node
          )
        else
          raise CompileError, "Equation reference not found: #{id}"
        end
      rescue ReVIEW::KeyError
        raise CompileError, "Equation reference not found: #{id}"
      end

      # Resolve footnote references
      def resolve_footnote_ref(id)
        if (item = find_index_item(@chapter.footnote_index, id))
          if item.respond_to?(:footnote_node?) && !item.footnote_node?
            raise CompileError, "Footnote reference not found: #{id}"
          end

          number = item.respond_to?(:number) ? item.number : nil
          # Get footnote_node (AST node with inline content) if available
          fn_node = item.respond_to?(:footnote_node) ? item.footnote_node : nil
          ResolvedData.footnote(
            item_number: number,
            item_id: id,
            caption_node: fn_node
          )
        else
          raise CompileError, "Footnote reference not found: #{id}"
        end
      end

      # Resolve endnote references
      def resolve_endnote_ref(id)
        if (item = find_index_item(@chapter.endnote_index, id))
          if item.respond_to?(:footnote_node?) && !item.footnote_node?
            raise CompileError, "Endnote reference not found: #{id}"
          end

          number = item.respond_to?(:number) ? item.number : nil
          caption_node = item.respond_to?(:caption_node) ? item.caption_node : nil
          ResolvedData.endnote(
            item_number: number,
            item_id: id,
            caption_node: caption_node
          )
        else
          raise CompileError, "Endnote reference not found: #{id}"
        end
      end

      def resolve_column_ref(id)
        if id.include?('|')
          chapter_id, item_id = split_cross_chapter_ref(id)
          target_chapter = find_chapter_by_id(chapter_id)
          raise CompileError, "Chapter not found for column reference: #{chapter_id}" unless target_chapter

          item = safe_column_fetch(target_chapter, item_id)
          ResolvedData.column(
            chapter_number: format_chapter_number(target_chapter),
            item_number: index_item_number(item),
            chapter_id: chapter_id,
            item_id: item_id,
            caption_node: item.caption_node
          )
        else
          item = safe_column_fetch(@chapter, id)
          ResolvedData.column(
            chapter_number: format_chapter_number(@chapter),
            item_number: index_item_number(item),
            item_id: id,
            caption_node: item.caption_node
          )
        end
      end

      # Resolve chapter references (chapter number only, for @<chap>)
      def resolve_chapter_ref(id)
        if @book
          chapter = find_chapter_by_id(id)
          if chapter
            ResolvedData.chapter(
              chapter_number: format_chapter_number(chapter),
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

      # Resolve chapter references with title (for @<chapref>)
      def resolve_chapter_ref_with_title(id)
        if @book
          chapter = find_chapter_by_id(id)
          if chapter
            ResolvedData.chapter(
              chapter_number: format_chapter_number(chapter),
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

      # Resolve chapter title only (for @<title>)
      def resolve_chapter_title(id)
        if @book
          chapter = find_chapter_by_id(id)
          if chapter
            ResolvedData.chapter(
              chapter_number: format_chapter_number(chapter),
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
              rescue ReVIEW::KeyError
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
            chapter_number: format_chapter_number(target_chapter),
            chapter_id: chapter_id,
            item_id: headline_id,
            caption_node: headline.caption_node
          )
        elsif @chapter.headline_index
          # Same-chapter reference
          begin
            headline = @chapter.headline_index[id]
          rescue ReVIEW::KeyError
            headline = nil
          end

          unless headline
            raise CompileError, "Headline not found: #{id}"
          end

          ResolvedData.headline(
            headline_number: headline.number,
            chapter_number: format_chapter_number(@chapter),
            item_id: id,
            caption_node: headline.caption_node
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
              chapter_number: format_chapter_number(@chapter),
              item_number: index_item_number(item),
              item_id: id,
              caption_node: item.caption_node
            )
          end
        end

        # Search in table index
        if @chapter.table_index
          item = find_index_item(@chapter.table_index, id)
          if item
            return ResolvedData.table(
              chapter_number: format_chapter_number(@chapter),
              item_number: index_item_number(item),
              item_id: id,
              caption_node: item.caption_node
            )
          end
        end

        # Search in list index
        if @chapter.list_index
          item = find_index_item(@chapter.list_index, id)
          if item
            return ResolvedData.list(
              chapter_number: format_chapter_number(@chapter),
              item_number: index_item_number(item),
              item_id: id,
              caption_node: item.caption_node
            )
          end
        end

        # Search in equation index
        if @chapter.equation_index
          item = find_index_item(@chapter.equation_index, id)
          if item
            return ResolvedData.equation(
              chapter_number: format_chapter_number(@chapter),
              item_number: index_item_number(item),
              item_id: id,
              caption_node: item.caption_node
            )
          end
        end

        # Search in headline index
        if @chapter.headline_index
          item = find_index_item(@chapter.headline_index, id)
          if item
            return ResolvedData.headline(
              headline_number: item.number,
              chapter_number: format_chapter_number(@chapter),
              item_id: id,
              caption_node: item.caption_node
            )
          end
        end

        # Search in column index
        if @chapter.column_index
          item = find_index_item(@chapter.column_index, id)
          if item
            return ResolvedData.column(
              chapter_number: format_chapter_number(@chapter),
              item_number: index_item_number(item),
              item_id: id,
              caption_node: item.caption_node
            )
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

      # Safely search for items from index
      def find_index_item(index, id)
        return nil unless index

        begin
          index[id]
        rescue ReVIEW::KeyError
          nil
        end
      end

      def safe_column_fetch(chapter, column_id)
        raise CompileError, "Column reference not found: #{column_id}" unless chapter

        chapter.column(column_id)
      rescue ReVIEW::KeyError
        raise CompileError, "Column reference not found: #{column_id}"
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

      # Resolve bibpaper references
      # Bibpapers are book-wide, so use @book.bibpaper_index instead of chapter index
      def resolve_bib_ref(id)
        if (item = find_index_item(@book.bibpaper_index, id))
          ResolvedData.bibpaper(
            item_number: index_item_number(item),
            item_id: id,
            caption_node: item.caption_node
          )
        else
          raise CompileError, "unknown bib: #{id}"
        end
      rescue ReVIEW::KeyError
        raise CompileError, "unknown bib: #{id}"
      end

      # Split cross-chapter reference ID into chapter_id and item_id
      def split_cross_chapter_ref(id)
        id.split('|', 2).map(&:strip)
      end

      # Find chapter by ID from book's chapter_index
      def find_chapter_by_id(id)
        return nil unless @book

        begin
          item = @book.chapter_index[id]
          return item.content if item
        rescue ReVIEW::KeyError
          # fall through to contents search
        end

        Array(@book.contents).find { |chap| chap.id == id }
      end

      # Format chapter number in long form (for all reference types)
      # Returns formatted chapter number like "第1章", "付録A", "第II部", etc.
      # This mimics ChapterIndex#number behavior
      def format_chapter_number(chapter)
        chapter.format_number # true (default) = long form with heading
      rescue StandardError # part
        ReVIEW::I18n.t('part', chapter.number)
      end
    end
  end
end
