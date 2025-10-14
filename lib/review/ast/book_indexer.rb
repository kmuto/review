# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/book/index'
require 'review/ast/indexer'
require 'review/ast/compiler'

module ReVIEW
  module AST
    # BookIndexer - Book-wide index management for AST-based processing
    #
    # This class provides centralized index management for entire books,
    # using AST::Indexer to build indexes for each chapter and coordinating
    # them into book-wide indexes for cross-chapter references.
    #
    # Responsibilities:
    # - Use AST::Indexer to build indexes for each chapter
    # - Coordinate index collection across multiple chapters
    # - Provide book-wide index access for cross-chapter references
    # - Maintain compatibility with existing index structures
    # - Support AST-based processing pipelines
    class BookIndexer
      attr_reader :book, :chapter_indexers

      def initialize(book)
        @book = book
        @chapter_indexers = {}
      end

      # Build indexes for all chapters in the book
      def build_all_chapter_indexes
        @book.each_chapter do |chapter|
          build_chapter_index(chapter)
        end
      end

      # Build index for a specific chapter using AST::Indexer
      def build_chapter_index(chapter)
        return if @chapter_indexers[chapter] # Already built

        begin
          # Compile chapter to AST
          ast = compile_chapter_to_ast(chapter)

          # Create indexer and build indexes
          indexer = AST::Indexer.new(chapter)
          indexer.build_indexes(ast)

          # Store the indexer
          @chapter_indexers[chapter] = indexer
        rescue StandardError => e
          warn "Failed to build index for chapter #{chapter.id}: #{e.message}" if $DEBUG
        end
      end

      # Get indexer for a specific chapter
      def chapter_indexer(chapter)
        @chapter_indexers[chapter]
      end

      # Find item across all chapters by ID and type
      def find_item(type, id, context_chapter = nil)
        # First try the context chapter if provided
        if context_chapter && @chapter_indexers[context_chapter]
          chapter_indexer = @chapter_indexers[context_chapter]
          index = chapter_indexer.index_for(type)
          item = index&.find_item(id)
          return item if item
        end

        # Search all chapters
        @chapter_indexers.each do |chapter, indexer|
          next if chapter == context_chapter # Already checked

          index = indexer.index_for(type)
          item = index&.find_item(id)
          return item if item
        end

        nil
      end

      # Get chapter that contains a specific item
      def find_chapter_for_item(type, id)
        @chapter_indexers.each do |chapter, indexer|
          index = indexer.index_for(type)
          return chapter if index&.find_item(id)
        end
        nil
      end

      private

      # Compile chapter to AST using appropriate compiler
      def compile_chapter_to_ast(chapter)
        compiler = AST::Compiler.for_chapter(chapter)
        compiler.compile_to_ast(chapter)
      end
    end
  end
end
