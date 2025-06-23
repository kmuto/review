# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/book/index'
require 'review/exception'
require 'review/sec_counter'

module ReVIEW
  module AST
    # Indexer - AST-based index building for Re:VIEW documents
    #
    # This class provides high-performance index building by directly analyzing
    # AST structures instead of going through Builder classes. It generates
    # the same index structures as IndexBuilder for compatibility.
    #
    # Features:
    # - Direct AST node traversal using Visitor pattern
    # - Compatible with existing IndexBuilder output
    # - High-performance processing without Builder overhead
    # - Comprehensive index support (lists, tables, images, headlines, etc.)
    class Indexer
      attr_reader :list_index, :table_index, :equation_index,
                  :footnote_index, :endnote_index,
                  :numberless_image_index, :image_index, :icon_index, :indepimage_index,
                  :headline_index, :column_index, :bibpaper_index

      def initialize(chapter)
        @chapter = chapter
        @book = chapter.book if chapter.respond_to?(:book)
        initialize_indexes
        initialize_counters
      end

      # Main index building method
      # Traverses the AST and builds all indexes
      def build_indexes(ast_root)
        return self unless ast_root

        visit_node(ast_root)
        self
      end

      # Get all indexes as a hash (for compatibility)
      def indexes
        {
          list: @list_index,
          table: @table_index,
          equation: @equation_index,
          footnote: @footnote_index,
          endnote: @endnote_index,
          image: @image_index,
          icon: @icon_index,
          numberless_image: @numberless_image_index,
          indepimage: @indepimage_index,
          headline: @headline_index,
          column: @column_index,
          bibpaper: @bibpaper_index
        }
      end

      private

      def initialize_indexes
        @list_index = ReVIEW::Book::ListIndex.new
        @table_index = ReVIEW::Book::TableIndex.new
        @equation_index = ReVIEW::Book::EquationIndex.new
        @footnote_index = ReVIEW::Book::FootnoteIndex.new
        @endnote_index = ReVIEW::Book::EndnoteIndex.new
        @headline_index = ReVIEW::Book::HeadlineIndex.new(@chapter)
        @column_index = ReVIEW::Book::ColumnIndex.new
        @chapter_index = ReVIEW::Book::ChapterIndex.new
        @bibpaper_index = ReVIEW::Book::BibpaperIndex.new

        if @book
          @image_index = ReVIEW::Book::ImageIndex.new(@chapter)
          @icon_index = ReVIEW::Book::IconIndex.new(@chapter)
          @numberless_image_index = ReVIEW::Book::NumberlessImageIndex.new(@chapter)
          @indepimage_index = ReVIEW::Book::IndepImageIndex.new(@chapter)
        end
      end

      def initialize_counters
        @sec_counter = ReVIEW::SecCounter.new(6, @chapter) # 6 is max level
      end

      # AST node traversal using Visitor pattern
      def visit_node(node)
        case node
        when AST::HeadlineNode
          process_headline(node)
        when AST::CodeBlockNode
          process_code_block(node)
        when AST::TableNode
          process_table(node)
        when AST::ImageNode
          process_image(node)
        when AST::MinicolumnNode
          process_minicolumn(node)
        when AST::InlineNode
          process_inline(node)
        when AST::EmbedNode
          process_embed(node)
        end

        # Recursively process child nodes
        visit_children(node)
      end

      def visit_children(node)
        return unless node.children

        node.children.each { |child| visit_node(child) }
      end

      # Process headline nodes
      def process_headline(node)
        check_id(node.label)
        @sec_counter.inc(node.level)
        return if node.level < 2

        # Build item_id similar to IndexBuilder
        cursor = node.level - 2
        @headline_stack ||= []
        @headline_stack[cursor] = (node.label || extract_caption_text(node.caption))
        if @headline_stack.size > cursor + 1
          @headline_stack = @headline_stack.take(cursor + 1)
        end

        item_id = @headline_stack.join('|')
        caption_text = extract_caption_text(node.caption)

        if node.label
          item = ReVIEW::Book::Index::Item.new(item_id, @sec_counter.number_list, caption_text)
          @headline_index.add_item(item)
        end

        # Process caption inline elements
        process_caption_inline_elements(node.caption) if node.caption
      end

      # Process code block nodes (list, listnum, emlist, etc.)
      def process_code_block(node)
        return unless node.id && !node.id.empty?

        check_id(node.id)
        item = ReVIEW::Book::Index::Item.new(node.id, @list_index.size + 1)
        @list_index.add_item(item)

        # Process caption inline elements
        process_caption_inline_elements(node.caption) if node.caption

        # Inline elements in code lines are now properly parsed as InlineNodes
        # and will be processed automatically by visit_children
      end

      # Process table nodes
      def process_table(node)
        return unless node.id && !node.id.empty?

        check_id(node.id)
        caption_text = extract_caption_text(node.caption)
        item = ReVIEW::Book::Index::Item.new(node.id, @table_index.size + 1, caption_text)
        @table_index.add_item(item)

        # Process caption inline elements
        process_caption_inline_elements(node.caption) if node.caption

        # Inline elements in table cells are now properly parsed as InlineNodes
        # and will be processed automatically by visit_children
      end

      # Process image nodes
      def process_image(node)
        return unless node.id && !node.id.empty?

        check_id(node.id)
        caption_text = extract_caption_text(node.caption)
        item = ReVIEW::Book::Index::Item.new(node.id, @image_index.size + 1, caption_text)
        @image_index.add_item(item)

        # Process caption inline elements
        process_caption_inline_elements(node.caption) if node.caption
      end

      # Process minicolumn nodes (note, memo, tip, etc.)
      def process_minicolumn(node)
        # Minicolumns are typically indexed by their type and content
        # Process caption inline elements
        process_caption_inline_elements(node.caption) if node.caption
      end

      # Process embed nodes
      def process_embed(node)
        case node.embed_type
        when :block
          # Process embedded content
          if node.lines
            node.lines.each { |line| process_text_inline_elements(line) }
          end
        end
      end

      # Process inline nodes
      def process_inline(node)
        case node.inline_type
        when 'fn'
          if node.args && node.args.first
            footnote_id = node.args.first
            check_id(footnote_id)
            item = ReVIEW::Book::Index::Item.new(footnote_id, @footnote_index.size + 1)
            @footnote_index.add_item(item)
          end
        when 'endnote'
          if node.args && node.args.first
            endnote_id = node.args.first
            check_id(endnote_id)
            item = ReVIEW::Book::Index::Item.new(endnote_id, @endnote_index.size + 1)
            @endnote_index.add_item(item)
          end
        when 'bib'
          if node.args && node.args.first
            bib_id = node.args.first
            check_id(bib_id)
            item = ReVIEW::Book::Index::Item.new(bib_id, @bibpaper_index.size + 1)
            @bibpaper_index.add_item(item)
          end
        when 'eq'
          if node.args && node.args.first
            eq_id = node.args.first
            check_id(eq_id)
            item = ReVIEW::Book::Index::Item.new(eq_id, @equation_index.size + 1)
            @equation_index.add_item(item)
          end
        when 'list', 'table', 'img'
          # These are references, already processed in their respective nodes
        end
      end

      # Process inline elements in caption nodes
      def process_caption_inline_elements(caption)
        return unless caption.respond_to?(:children)

        caption.children.each { |child| visit_node(child) }
      end

      # Extract plain text from caption node
      def extract_caption_text(caption)
        return nil unless caption

        if caption.respond_to?(:children)
          caption.children.map do |child|
            case child
            when AST::TextNode
              child.content
            when AST::InlineNode
              extract_inline_text(child)
            else
              child.to_s
            end
          end.join
        else
          caption.to_s
        end
      end

      # Extract text content from inline nodes
      def extract_inline_text(inline_node)
        if inline_node.respond_to?(:children)
          inline_node.children.map { |child| child.respond_to?(:content) ? child.content : child.to_s }.join
        else
          inline_node.to_s
        end
      end

      # ID validation (same as IndexBuilder)
      def check_id(id)
        if id
          # Check for various deprecated characters
          id.scan(%r![#%\\{}\[\]~/$'"|*?&<>`\s]!) do |char|
            warn "deprecated ID: `#{char}` in `#{id}`"
          end

          if id.start_with?('.')
            warn "deprecated ID: `#{id}` begins from `.`"
          end
        end
      end

      # Warning output
      def warn(message)
        # For now, just output to stderr
        # In a real implementation, this should use the proper logging system
        $stderr.puts "WARNING: #{message}"
      end
    end
  end
end
