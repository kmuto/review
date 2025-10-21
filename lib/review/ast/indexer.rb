# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
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
        @book = chapter.book
        initialize_indexes
        initialize_counters
      end

      # Build book-wide indexes for cross-chapter references using BookIndexer
      # This is a class method that can be used by any renderer
      def self.build_book_indexes(book)
        return unless book

        require 'review/ast/book_indexer'

        # Create BookIndexer and build all indexes
        book_indexer = AST::BookIndexer.new(book)
        book_indexer.build_all_chapter_indexes

        # Build chapter index for compatibility
        build_chapter_index(book)
      end

      # Build chapter index for compatibility with existing Book class expectations
      def self.build_chapter_index(book)
        # The book.chapter_index method has lazy initialization
        # Calling it will trigger creation if not already set
        book.chapter_index
      end

      # Main index building method
      # Traverses the AST and builds all indexes
      def build_indexes(ast_root)
        return self unless ast_root

        visit_node(ast_root)

        set_indexes_on_chapter

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

      # Available index types
      def available_index_types
        %i[list table equation footnote endnote image icon numberless_image indepimage headline column bibpaper]
      end

      # Collect index items of specific type from this indexer for book-wide aggregation
      def collect_index_items(type)
        index = index_for(type)
        return [] unless index

        # Transform each item to add chapter context for book-wide reference
        index.map do |item|
          ReVIEW::Book::Index::Item.new(item.id, item.number, @chapter)
        end
      end

      # Create combined index from multiple indexers
      def self.combine_indexes(indexers, type)
        combined_index = ReVIEW::Book::Index.new

        # Collect all items from all indexers and add them to the combined index
        indexers.flat_map { |indexer| indexer.collect_index_items(type) }.
          each { |item| combined_index.add_item(item) }

        combined_index
      end

      private

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

      # AST node traversal using Visitor pattern
      def visit_node(node)
        case node
        when AST::HeadlineNode
          process_headline(node)
        when AST::ColumnNode
          process_column(node)
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
        when AST::FootnoteNode
          process_footnote(node)
        when AST::TexEquationNode
          process_tex_equation(node)
        when AST::BlockNode
          process_block(node)
        end

        # Recursively process child nodes
        visit_children(node)
      end

      def visit_children(node)
        node.children.each { |child| visit_node(child) }
      end

      # Process headline nodes (matches IndexBuilder behavior)
      def process_headline(node)
        check_id(node.label)
        @sec_counter.inc(node.level)
        return if node.level < 2

        # Build item_id exactly like IndexBuilder
        cursor = node.level - 2
        @headline_stack ||= []
        caption_text = extract_caption_text(node.caption, node.caption_node)
        @headline_stack[cursor] = (node.label || caption_text)
        if @headline_stack.size > cursor + 1
          @headline_stack = @headline_stack.take(cursor + 1)
        end

        item_id = @headline_stack.join('|')

        # Always add to headline index like IndexBuilder does
        item = ReVIEW::Book::Index::Item.new(item_id, @sec_counter.number_list, caption_text, caption_node: node.caption_node)
        @headline_index.add_item(item)

        # Process caption inline elements
        process_caption_inline_elements(node.caption_node) if node.caption_node
      end

      # Process column nodes
      def process_column(node)
        # Extract caption text like IndexBuilder does
        caption_text = extract_caption_text(node.caption, node.caption_node)

        # Use label if available, otherwise use caption as ID (like IndexBuilder does)
        item_id = node.label || caption_text

        check_id(node.label) if node.label

        # Create index item - use item_id as ID and caption text
        item = ReVIEW::Book::Index::Item.new(item_id, @column_index.size + 1, caption_text, caption_node: node.caption_node)
        @column_index.add_item(item)

        # Process caption inline elements
        process_caption_inline_elements(node.caption_node) if node.caption_node
      end

      # Process code block nodes (list, listnum, emlist, etc.)
      def process_code_block(node)
        return unless node.id?

        check_id(node.id)
        item = ReVIEW::Book::Index::Item.new(node.id, @list_index.size + 1)
        @list_index.add_item(item)

        # Process caption inline elements
        process_caption_inline_elements(node.caption_node) if node.caption_node

        # Inline elements in code lines are now properly parsed as InlineNodes
        # and will be processed automatically by visit_children
      end

      # Process table nodes
      def process_table(node)
        return unless node.id?

        check_id(node.id)
        caption_text = extract_caption_text(node.caption, node.caption_node)
        item = ReVIEW::Book::Index::Item.new(node.id, @table_index.size + 1, caption_text, caption_node: node.caption_node)
        @table_index.add_item(item)

        # For imgtable, also add to indepimage_index (like IndexBuilder does)
        if node.table_type == :imgtable
          image_item = ReVIEW::Book::Index::Item.new(node.id, @indepimage_index.size + 1)
          @indepimage_index.add_item(image_item)
        end

        # Process caption inline elements
        process_caption_inline_elements(node.caption_node) if node.caption_node

        # Inline elements in table cells are now properly parsed as InlineNodes
        # and will be processed automatically by visit_children
      end

      # Process image nodes
      def process_image(node)
        return unless node.id?

        check_id(node.id)
        caption_text = extract_caption_text(node.caption, node.caption_node)
        item = ReVIEW::Book::Index::Item.new(node.id, @image_index.size + 1, caption_text, caption_node: node.caption_node)
        @image_index.add_item(item)

        # Process caption inline elements
        process_caption_inline_elements(node.caption_node) if node.caption_node
      end

      # Process minicolumn nodes (note, memo, tip, etc.)
      def process_minicolumn(node)
        # Minicolumns are typically indexed by their type and content
        # Process caption inline elements
        process_caption_inline_elements(node.caption_node) if node.caption_node
      end

      # Process embed nodes
      def process_embed(node)
        case node.embed_type
        when :block
          # Embed blocks contain raw content that shouldn't be processed for inline elements
          # since it's meant to be output as-is for specific formats
          # No inline processing needed
        end
      end

      # Process footnote nodes (simplified with AST::FootnoteIndex)
      def process_footnote(node)
        check_id(node.id)

        # Extract footnote content
        footnote_content = extract_footnote_content(node)

        # Add or update footnote in appropriate index
        if node.footnote_type == :footnote
          @crossref[:footnote][node.id] ||= 0
          @footnote_index.add_or_update(node.id, content: footnote_content, footnote_node: node)
        elsif node.footnote_type == :endnote
          @crossref[:endnote][node.id] ||= 0
          @endnote_index.add_or_update(node.id, content: footnote_content, footnote_node: node)
        end
      end

      # Process texequation nodes
      def process_tex_equation(node)
        return unless node.id?

        check_id(node.id)
        caption_text = extract_caption_text(node.caption, node.caption_node) || ''
        item = ReVIEW::Book::Index::Item.new(node.id, @equation_index.size + 1, caption_text, caption_node: node.caption_node)
        @equation_index.add_item(item)
      end

      def process_block(node)
        return unless node.block_type

        case node.block_type.to_s
        when 'bibpaper'
          if node.args.length >= 2
            bib_id = node.args[0]
            bib_caption = node.args[1]
            check_id(bib_id)
            item = ReVIEW::Book::Index::Item.new(bib_id, @bibpaper_index.size + 1, bib_caption)
            @bibpaper_index.add_item(item)
          end
        end
      end

      # Process inline nodes (matches IndexBuilder behavior)
      def process_inline(node)
        case node.inline_type
        when 'fn'
          if node.args.first
            footnote_id = node.args.first
            check_id(footnote_id)
            # Track cross-reference
            @crossref[:footnote][footnote_id] = @crossref[:footnote][footnote_id] ? @crossref[:footnote][footnote_id] + 1 : 1
            # Add reference entry (content will be filled when FootnoteNode is processed)
            @footnote_index.add_or_update(footnote_id)
          end
        when 'endnote'
          if node.args.first
            endnote_id = node.args.first
            check_id(endnote_id)
            # Track cross-reference
            @crossref[:endnote][endnote_id] = @crossref[:endnote][endnote_id] ? @crossref[:endnote][endnote_id] + 1 : 1
            # Add reference entry (content will be filled when FootnoteNode is processed)
            @endnote_index.add_or_update(endnote_id)
          end
        when 'bib'
          if node.args.first
            bib_id = node.args.first
            check_id(bib_id)
            # Add to index if not already present (for compatibility with tests and IndexBuilder behavior)
            unless @bibpaper_index.key?(bib_id)
              item = ReVIEW::Book::Index::Item.new(bib_id, @bibpaper_index.size + 1)
              @bibpaper_index.add_item(item)
            end
          end
        when 'eq'
          if node.args.first
            eq_id = node.args.first
            check_id(eq_id)
          end
        when 'img'
          # Image references are handled when the actual image blocks are processed
          # No special processing needed for inline image references
        when 'icon'
          if node.args.first
            icon_id = node.args.first
            check_id(icon_id)
            # Add icon to index if not already present
            unless @icon_index.key?(icon_id)
              item = ReVIEW::Book::Index::Item.new(icon_id, @icon_index.size + 1)
              @icon_index.add_item(item)
            end
          end
        when 'list', 'table'
          # These are references, already processed in their respective nodes
        end
      end

      # Process inline elements in caption nodes
      def process_caption_inline_elements(caption_node)
        return unless caption_node

        caption_node.children.each { |child| visit_node(child) }
      end

      # Extract plain text from caption node
      def extract_caption_text(caption, caption_node = nil)
        return nil if caption.nil? && caption_node.nil?

        if caption.is_a?(String)
          caption
        elsif caption.respond_to?(:to_text)
          caption.to_text
        elsif caption_node.respond_to?(:to_text)
          caption_node.to_text
        elsif caption_node
          caption_node.to_s
        else
          caption.to_s
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
