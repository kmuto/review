# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/book/index'
require 'review/exception'
require 'review/sec_counter'
require 'review/ast/footnote_node'
require 'review/ast/footnote_index'
require 'review/ast/headline_node'
require 'review/ast/column_node'
require 'review/ast/minicolumn_node'
require 'review/ast/code_block_node'
require 'review/ast/image_node'
require 'review/ast/table_node'
require 'review/ast/embed_node'
require 'review/ast/tex_equation_node'
require 'review/ast/block_node'
require 'review/ast/inline_node'
require 'review/ast/visitor'

module ReVIEW
  module AST
    # Indexer - AST-based index building for Re:VIEW documents
    #
    # This class provides high-performance index building by directly analyzing
    # AST structures instead of going through Builder classes. It generates
    # the same index structures as IndexBuilder for compatibility.
    #
    # Features:
    # - AST node traversal using Visitor pattern
    # - Compatible with existing IndexBuilder output
    # - High-performance processing without Builder overhead
    # - Comprehensive index support (lists, tables, images, headlines, etc.)
    class Indexer < Visitor
      attr_reader :list_index, :table_index, :equation_index,
                  :footnote_index, :endnote_index,
                  :numberless_image_index, :image_index, :icon_index, :indepimage_index,
                  :headline_index, :column_index, :bibpaper_index

      def initialize(chapter)
        super()
        @chapter = chapter
        @book = chapter.book
        initialize_indexes
        initialize_counters
      end

      # Main index building method
      # Traverses the AST and builds all indexes
      def build_indexes(ast_root)
        return self unless ast_root

        visit(ast_root)

        set_indexes_on_chapter

        # This prevents duplicate index generation by renderers
        if ast_root.is_a?(DocumentNode)
          ast_root.indexes_generated = true
        end

        self
      end

      # Get all indexes as a hash (for compatibility)
      def indexes
        {
          list: @list_index,
          table: @table_index,
          equation: @equation_index,
          footnote: @footnote_index.to_book_index,
          endnote: @endnote_index.to_book_index,
          image: @image_index,
          icon: @icon_index,
          numberless_image: @numberless_image_index,
          indepimage: @indepimage_index,
          headline: @headline_index,
          column: @column_index,
          bibpaper: @bibpaper_index
        }
      end

      # Find index by type name (type-safe alternative to send)
      def index_for(type)
        case type.to_sym
        when :list then @list_index
        when :table then @table_index
        when :equation then @equation_index
        when :footnote then @footnote_index
        when :endnote then @endnote_index
        when :image then @image_index
        when :icon then @icon_index
        when :numberless_image then @numberless_image_index
        when :indepimage then @indepimage_index
        when :headline then @headline_index
        when :column then @column_index
        when :bibpaper then @bibpaper_index
        else
          raise ArgumentError, "Unknown index type: #{type}"
        end
      end

      private

      def visit_caption_children(node)
        visit_all(node.caption_node.children) if node.caption_node
      end

      # Set indexes on chapter using public API
      def set_indexes_on_chapter
        @chapter.ast_indexes = {
          footnote_index: @footnote_index,
          endnote_index: @endnote_index,
          list_index: @list_index,
          table_index: @table_index,
          equation_index: @equation_index,
          image_index: @image_index,
          icon_index: @icon_index,
          numberless_image_index: @numberless_image_index,
          indepimage_index: @indepimage_index,
          headline_index: @headline_index,
          column_index: @column_index,
          bibpaper_index: @bibpaper_index
        }
      end

      # Extract footnote content from FootnoteNode
      def extract_footnote_content(node)
        node.to_text
      end

      def initialize_indexes
        @list_index = ReVIEW::Book::ListIndex.new
        @table_index = ReVIEW::Book::TableIndex.new
        @equation_index = ReVIEW::Book::EquationIndex.new
        @footnote_index = AST::FootnoteIndex.new
        @endnote_index = AST::FootnoteIndex.new
        @headline_index = ReVIEW::Book::HeadlineIndex.new(@chapter)
        @column_index = ReVIEW::Book::ColumnIndex.new
        @chapter_index = ReVIEW::Book::ChapterIndex.new
        @bibpaper_index = ReVIEW::Book::BibpaperIndex.new

        @image_index = ReVIEW::Book::ImageIndex.new(@chapter)
        @icon_index = ReVIEW::Book::IconIndex.new(@chapter)
        unless @book
          # Create basic indexes even without book for testing
        end
        @numberless_image_index = ReVIEW::Book::NumberlessImageIndex.new(@chapter)
        @indepimage_index = ReVIEW::Book::IndepImageIndex.new(@chapter)
      end

      def initialize_counters
        @sec_counter = ReVIEW::SecCounter.new(6, @chapter) # 6 is max level

        # Initialize cross-reference tracking like IndexBuilder
        @headline_stack = []
        @crossref = {
          footnote: {},
          endnote: {}
        }
      end

      def visit_document(node)
        visit_all(node.children)
      end

      def visit_paragraph(node)
        visit_all(node.children)
      end

      def visit_text(node)
        # Text nodes have no children and don't contribute to indexes
      end

      def visit_list(node)
        visit_all(node.children)
      end

      def visit_list_item(node)
        visit_all(node.term_children) if node.term_children&.any?
        visit_all(node.children)
      end

      def visit_caption(node)
        visit_all(node.children)
      end

      def visit_code_line(node)
        visit_all(node.children)
      end

      def visit_table_row(node)
        visit_all(node.children)
      end

      def visit_table_cell(node)
        visit_all(node.children)
      end

      def visit_reference(node)
        visit_all(node.children)
      end

      def visit_headline(node)
        check_id(node.label)
        @sec_counter.inc(node.level)

        if node.level >= 2
          # Build item_id exactly like IndexBuilder
          cursor = node.level - 2
          @headline_stack ||= []
          caption_text = extract_caption_text(node.caption_node)
          @headline_stack[cursor] = (node.label || caption_text)
          if @headline_stack.size > cursor + 1
            @headline_stack = @headline_stack.take(cursor + 1)
          end

          item_id = @headline_stack.join('|')

          # Always add to headline index like IndexBuilder does
          item = ReVIEW::Book::Index::Item.new(item_id, @sec_counter.number_list, caption_text, caption_node: node.caption_node)
          @headline_index.add_item(item)

          visit_caption_children(node)
        end

        visit_all(node.children)
      end

      def visit_column(node)
        # Extract caption text like IndexBuilder does
        caption_text = extract_caption_text(node.caption_node)

        # Use label if available, otherwise use caption as ID (like IndexBuilder does)
        item_id = node.label || caption_text

        check_id(node.label) if node.label

        item = ReVIEW::Book::Index::Item.new(item_id, @column_index.size + 1, caption_text, caption_node: node.caption_node)
        @column_index.add_item(item)

        visit_caption_children(node)
        visit_all(node.children)
      end

      def visit_code_block(node)
        if node.id?
          check_id(node.id)
          item = ReVIEW::Book::Index::Item.new(node.id, @list_index.size + 1)
          @list_index.add_item(item)

          visit_caption_children(node)
        end

        visit_all(node.children)
      end

      def visit_table(node)
        if node.id?
          check_id(node.id)
          caption_text = extract_caption_text(node.caption_node)
          item = ReVIEW::Book::Index::Item.new(node.id, @table_index.size + 1, caption_text, caption_node: node.caption_node)
          @table_index.add_item(item)

          # For imgtable, also add to indepimage_index (like IndexBuilder does)
          if node.table_type == :imgtable
            image_item = ReVIEW::Book::Index::Item.new(node.id, @indepimage_index.size + 1)
            @indepimage_index.add_item(image_item)
          end

          visit_caption_children(node)
        end

        visit_all(node.children)
      end

      def visit_image(node)
        if node.id?
          check_id(node.id)
          caption_text = extract_caption_text(node.caption_node)
          item = ReVIEW::Book::Index::Item.new(node.id, @image_index.size + 1, caption_text, caption_node: node.caption_node)
          @image_index.add_item(item)

          visit_caption_children(node)
        end

        visit_all(node.children)
      end

      def visit_minicolumn(node)
        # Minicolumns are typically indexed by their type and content
        visit_caption_children(node)

        visit_all(node.children)
      end

      def visit_embed(node)
        case node.embed_type
        when :block
          # Embed blocks contain raw content that shouldn't be processed for inline elements
          # since it's meant to be output as-is for specific formats
        end

        visit_all(node.children)
      end

      def visit_footnote(node)
        check_id(node.id)

        footnote_content = extract_footnote_content(node)

        if node.footnote_type == :footnote
          @crossref[:footnote][node.id] ||= 0
          @footnote_index.add_or_update(node.id, content: footnote_content, footnote_node: node)
        elsif node.footnote_type == :endnote
          @crossref[:endnote][node.id] ||= 0
          @endnote_index.add_or_update(node.id, content: footnote_content, footnote_node: node)
        end

        visit_all(node.children)
      end

      def visit_tex_equation(node)
        if node.id?
          check_id(node.id)
          caption_text = extract_caption_text(node.caption_node) || ''
          item = ReVIEW::Book::Index::Item.new(node.id, @equation_index.size + 1, caption_text, caption_node: node.caption_node)
          @equation_index.add_item(item)
        end

        visit_all(node.children)
      end

      def visit_block(node)
        if node.block_type
          case node.block_type.to_s
          when 'bibpaper'
            if node.args.length >= 2
              bib_id = node.args[0]
              bib_caption = node.args[1]
              check_id(bib_id)
              item = ReVIEW::Book::Index::Item.new(bib_id, @bibpaper_index.size + 1, bib_caption, caption_node: node.caption_node)
              @bibpaper_index.add_item(item)
            end
          end
        end

        visit_caption_children(node)
        visit_all(node.children)
      end

      def visit_inline(node)
        case node.inline_type
        when :fn
          if node.args.first
            footnote_id = node.args.first
            check_id(footnote_id)
            # Track cross-reference
            @crossref[:footnote][footnote_id] = @crossref[:footnote][footnote_id] ? @crossref[:footnote][footnote_id] + 1 : 1
            # Add reference entry (content will be filled when FootnoteNode is processed)
            @footnote_index.add_or_update(footnote_id)
          end
        when :endnote
          if node.args.first
            endnote_id = node.args.first
            check_id(endnote_id)
            # Track cross-reference
            @crossref[:endnote][endnote_id] = @crossref[:endnote][endnote_id] ? @crossref[:endnote][endnote_id] + 1 : 1
            # Add reference entry (content will be filled when FootnoteNode is processed)
            @endnote_index.add_or_update(endnote_id)
          end
        when :bib
          if node.args.first
            bib_id = node.args.first
            check_id(bib_id)
            # Add to index if not already present (for compatibility with tests and IndexBuilder behavior)
            unless @bibpaper_index.key?(bib_id)
              item = ReVIEW::Book::Index::Item.new(bib_id, @bibpaper_index.size + 1)
              @bibpaper_index.add_item(item)
            end
          end
        when :eq
          if node.args.first
            eq_id = node.args.first
            check_id(eq_id)
          end
        when :img
          # Image references are handled when the actual image blocks are processed
          # No special processing needed for inline image references
        when :icon
          if node.args.first
            icon_id = node.args.first
            check_id(icon_id)
            # Add icon to index if not already present
            unless @icon_index.key?(icon_id)
              item = ReVIEW::Book::Index::Item.new(icon_id, @icon_index.size + 1)
              @icon_index.add_item(item)
            end
          end
        when :list, :table
          # These are references, already processed in their respective nodes
        end

        visit_all(node.children)
      end

      # Extract plain text from caption node
      def extract_caption_text(caption_node)
        return nil if caption_node.nil?

        if caption_node.respond_to?(:to_text)
          caption_node.to_text
        else
          caption_node.to_s
        end
      end

      # Extract text content from inline nodes
      def extract_inline_text(inline_node)
        inline_node.children.map { |child| child.respond_to?(:content) ? child.content : child.to_s }.join
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
