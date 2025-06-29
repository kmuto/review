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

      # Build book-wide indexes for cross-chapter references
      # This is a class method that can be used by any renderer
      def self.build_book_indexes(book)
        return unless book

        # Skip if already built
        return if book.instance_variable_get(:@chapter_index)

        require 'review/ast/compiler'

        # Initialize chapter index
        chapter_index = ReVIEW::Book::ChapterIndex.new

        # Process all chapters and build their indexes - use Book::Base's method
        book.each_chapter do |chapter|
          # Add chapter to chapter index - follow Book::Base#create_chapter_index pattern
          chapter_index.add_item(ReVIEW::Book::Index::Item.new(chapter.id, chapter.number, chapter))
        end

        # Add parts to chapter index
        book.parts.each do |part|
          if part.id.present?
            chapter_index.add_item(ReVIEW::Book::Index::Item.new(part.id, part.number, part))
          end
        end

        # Now build indexes for all chapters
        book.each_chapter do |chapter|
          # Build AST and indexes for this chapter if not already done
          next if chapter.instance_variable_get(:@list_index)

          begin
            ast = compile_chapter_to_ast(chapter)
            indexer = new(chapter)
            indexer.build_indexes(ast)

            # Set indexes on the chapter
            chapter.instance_variable_set(:@footnote_index, indexer.footnote_index)
            chapter.instance_variable_set(:@endnote_index, indexer.endnote_index)
            chapter.instance_variable_set(:@list_index, indexer.list_index)
            chapter.instance_variable_set(:@table_index, indexer.table_index)
            chapter.instance_variable_set(:@equation_index, indexer.equation_index)
            chapter.instance_variable_set(:@image_index, indexer.image_index)
            chapter.instance_variable_set(:@icon_index, indexer.icon_index)
            chapter.instance_variable_set(:@numberless_image_index, indexer.numberless_image_index)
            chapter.instance_variable_set(:@indepimage_index, indexer.indepimage_index)
            chapter.instance_variable_set(:@headline_index, indexer.headline_index)
            chapter.instance_variable_set(:@column_index, indexer.column_index)
            chapter.instance_variable_set(:@bibpaper_index, indexer.bibpaper_index)
          rescue StandardError => e
            # Skip chapters that can't be processed
            warn "Failed to build index for chapter #{chapter.id}: #{e.message}" if $DEBUG
          end
        end

        # Set chapter index on book
        book.instance_variable_set(:@chapter_index, chapter_index)
      end

      # Compile a chapter to AST (class method helper)
      def self.compile_chapter_to_ast(chapter)
        compiler = ReVIEW::AST::Compiler.new
        content = chapter.content
        compiler.compile(content)
      rescue StandardError => e
        warn "Failed to compile chapter #{chapter.id} to AST: #{e.message}" if $DEBUG
        # Return empty document node as fallback
        ReVIEW::AST::DocumentNode.new(location: nil)
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

      private

      # Extract footnote content from FootnoteNode
      def extract_footnote_content(node)
        # Use the original content from FootnoteNode
        # Inline processing will be handled later by the renderer
        return node.content if node.content && !node.content.empty?

        # Fallback to empty string to avoid nil issues
        ''
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

        if @book
          @image_index = ReVIEW::Book::ImageIndex.new(@chapter)
          @icon_index = ReVIEW::Book::IconIndex.new(@chapter)
          @numberless_image_index = ReVIEW::Book::NumberlessImageIndex.new(@chapter)
          @indepimage_index = ReVIEW::Book::IndepImageIndex.new(@chapter)
        end
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
        return unless node.children

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
        caption_text = extract_caption_text(node.caption)
        @headline_stack[cursor] = (node.label || caption_text)
        if @headline_stack.size > cursor + 1
          @headline_stack = @headline_stack.take(cursor + 1)
        end

        item_id = @headline_stack.join('|')

        # Always add to headline index like IndexBuilder does
        item = ReVIEW::Book::Index::Item.new(item_id, @sec_counter.number_list, caption_text)
        @headline_index.add_item(item)

        # Process caption inline elements
        process_caption_inline_elements(node.caption) if node.caption
      end

      # Process column nodes
      def process_column(node)
        # Check if column has a label (ID)
        return unless node.label

        check_id(node.label)

        # Extract caption text like IndexBuilder does
        caption_text = extract_caption_text(node.caption)

        # Create index item - use label as ID and caption text
        item = ReVIEW::Book::Index::Item.new(node.label, @column_index.size + 1, caption_text)
        @column_index.add_item(item)

        # Process caption inline elements
        process_caption_inline_elements(node.caption) if node.caption
      end

      # Process code block nodes (list, listnum, emlist, etc.)
      def process_code_block(node)
        return unless node.id?

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
        return unless node.id?

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
        return unless node.id?

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
        caption_text = node.caption? ? node.caption : ''
        item = ReVIEW::Book::Index::Item.new(node.id, @equation_index.size + 1, caption_text)
        @equation_index.add_item(item)
      end

      def process_block(node)
        return unless node.block_type

        case node.block_type.to_s
        when 'bibpaper'
          if node.args && node.args.length >= 2
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
          if node.args && node.args.first
            footnote_id = node.args.first
            check_id(footnote_id)
            # Track cross-reference
            @crossref[:footnote][footnote_id] = @crossref[:footnote][footnote_id] ? @crossref[:footnote][footnote_id] + 1 : 1
            # Add reference entry (content will be filled when FootnoteNode is processed)
            @footnote_index.add_or_update(footnote_id)
          end
        when 'endnote'
          if node.args && node.args.first
            endnote_id = node.args.first
            check_id(endnote_id)
            # Track cross-reference
            @crossref[:endnote][endnote_id] = @crossref[:endnote][endnote_id] ? @crossref[:endnote][endnote_id] + 1 : 1
            # Add reference entry (content will be filled when FootnoteNode is processed)
            @endnote_index.add_or_update(endnote_id)
          end
        when 'bib'
          if node.args && node.args.first
            bib_id = node.args.first
            check_id(bib_id)
            # Add to index if not already present (for compatibility with tests and IndexBuilder behavior)
            unless @bibpaper_index.key?(bib_id)
              item = ReVIEW::Book::Index::Item.new(bib_id, @bibpaper_index.size + 1)
              @bibpaper_index.add_item(item)
            end
          end
        when 'eq'
          if node.args && node.args.first
            eq_id = node.args.first
            check_id(eq_id)
            # Add to index if not already present (for compatibility with tests and IndexBuilder behavior)
            unless @equation_index.key?(eq_id)
              item = ReVIEW::Book::Index::Item.new(eq_id, @equation_index.size + 1)
              @equation_index.add_item(item)
            end
          end
        when 'img'
          # Image references are handled when the actual image blocks are processed
          # No special processing needed for inline image references
        when 'icon'
          if node.args && node.args.first
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
