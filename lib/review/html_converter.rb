# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/compiler'
require 'review/htmlbuilder'
require 'review/renderer/html_renderer'
require 'review/ast'
require 'review/ast/compiler'
require 'review/ast/book_indexer'
require 'review/book'
require 'review/configure'
require 'review/i18n'
require 'stringio'
require 'yaml'

module ReVIEW
  # HTMLConverter converts *.re files to HTML using both HTMLBuilder and HTMLRenderer
  # for comparison purposes.
  class HTMLConverter
    # Convert a Re:VIEW source string to HTML using HTMLBuilder
    #
    # @param source [String] Re:VIEW source content
    # @param chapter [ReVIEW::Book::Chapter, nil] Chapter context (optional)
    # @return [String] Generated HTML
    def convert_with_builder(source, chapter: nil)
      # Create a temporary book/chapter if not provided
      unless chapter
        book = create_temporary_book
        chapter = create_temporary_chapter(book, source)
      end

      # Create HTMLBuilder
      builder = HTMLBuilder.new
      compiler = Compiler.new(builder)
      builder.bind(compiler, chapter, Location.new('test', nil))

      # Compiler already created above

      # Compile the chapter
      compiler.compile(chapter)

      builder.raw_result
    end

    # Convert a Re:VIEW source string to HTML using HtmlRenderer
    #
    # @param source [String] Re:VIEW source content
    # @param chapter [ReVIEW::Book::Chapter, nil] Chapter context (optional)
    # @return [String] Generated HTML
    def convert_with_renderer(source, chapter: nil)
      # Create a temporary book/chapter if not provided
      unless chapter
        book = create_temporary_book
        chapter = create_temporary_chapter(book, source)
      end

      # Generate AST indexes for all chapters in the book to support cross-chapter references
      if chapter.book
        ReVIEW::AST::BookIndexer.build(chapter.book)
      end

      ast_compiler = ReVIEW::AST::Compiler.for_chapter(chapter)
      ast = ast_compiler.compile_to_ast(chapter)

      renderer = Renderer::HtmlRenderer.new(chapter)

      # Use render_body to get body content only (without template)
      # This matches HTMLBuilder's raw_result output for comparison
      renderer.render_body(ast)
    end

    # Convert a chapter from a book project to HTML using both builder and renderer
    #
    # @param book_dir [String] Path to book project directory
    # @param chapter_name [String] Chapter filename (e.g., 'ch01.re' or 'ch01')
    # @return [Hash] Hash with :builder and :renderer keys containing HTML output
    def convert_chapter_with_book_context(book_dir, chapter_name)
      # Ensure book_dir is absolute
      book_dir = File.expand_path(book_dir)

      # Normalize chapter_name (remove .re extension)
      chapter_name = chapter_name.sub(/\.re$/, '')

      # Load book and find chapter for builder
      book_for_builder = load_book(book_dir)
      chapter_for_builder = book_for_builder.chapters.find { |ch| ch.name == chapter_name }
      raise "Chapter '#{chapter_name}' not found in book at #{book_dir}" unless chapter_for_builder

      # Load book and find chapter for renderer (separate instance)
      book_for_renderer = load_book(book_dir)
      chapter_for_renderer = book_for_renderer.chapters.find { |ch| ch.name == chapter_name }

      # Convert with both builder and renderer using separate chapter instances
      builder_html = convert_with_builder(nil, chapter: chapter_for_builder)
      renderer_html = convert_with_renderer(nil, chapter: chapter_for_renderer)

      {
        builder: builder_html,
        renderer: renderer_html
      }
    end

    private

    # Create a temporary book for testing
    def create_temporary_book
      book_config = Configure.values

      # Set default HTML configuration
      book_config['htmlext'] = 'html'
      book_config['stylesheet'] = []
      book_config['language'] = 'ja'
      book_config['epubversion'] = 3 # Enable EPUB3 features for consistent output

      # Initialize I18n
      I18n.setup(book_config['language'])

      Book::Base.new('.', config: book_config)
    end

    # Create a temporary chapter for testing
    def create_temporary_chapter(book, source = '')
      # Create a StringIO with the source content
      io = StringIO.new(source)
      Book::Chapter.new(book, 1, 'test', 'test.re', io)
    end

    # Load a book from a directory
    def load_book(book_dir)
      # Change to book directory to load configuration
      Dir.chdir(book_dir) do
        # Load book configuration from config.yml
        book_config = Configure.values
        config_file = File.join(book_dir, 'config.yml')
        if File.exist?(config_file)
          yaml_config = YAML.load_file(config_file, permitted_classes: [Date, Time, Symbol])
          book_config.merge!(yaml_config) if yaml_config
        end

        # Set default HTML configuration
        book_config['htmlext'] ||= 'html'
        book_config['stylesheet'] ||= []
        book_config['language'] ||= 'ja'
        book_config['epubversion'] ||= 3

        # Initialize I18n
        I18n.setup(book_config['language'])

        # Create book instance
        book = Book::Base.new(book_dir, config: book_config)

        # Initialize book-wide indexes early for cross-chapter references
        # This is the same approach used by bin/review-ast-compile
        ReVIEW::AST::BookIndexer.build(book)

        book
      end
    end
  end
end
