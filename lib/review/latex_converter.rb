# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/compiler'
require 'review/latexbuilder'
require 'review/renderer/latex_renderer'
require 'review/ast'
require 'review/ast/compiler'
require 'review/ast/book_indexer'
require 'review/book'
require 'review/configure'
require 'review/i18n'
require 'stringio'
require 'yaml'
require 'pathname'

module ReVIEW
  # LATEXConverter converts *.re files to LaTeX using both LATEXBuilder and LATEXRenderer
  # for comparison purposes.
  class LATEXConverter
    def initialize(config: {})
      @config = config
    end

    # Convert a Re:VIEW source string to LaTeX using LATEXBuilder
    #
    # @param source [String] Re:VIEW source content
    # @param chapter [ReVIEW::Book::Chapter, nil] Chapter context (optional)
    # @return [String] Generated LaTeX
    def convert_with_builder(source, chapter: nil)
      # Create a temporary book/chapter if not provided
      unless chapter
        book = create_temporary_book
        chapter = create_temporary_chapter(book, source)
      end

      # Create LATEXBuilder and compiler
      builder = LATEXBuilder.new
      compiler = Compiler.new(builder)

      # Bind builder to context
      builder.bind(compiler, chapter, Location.new('test', nil))

      # Compile the chapter
      compiler.compile(chapter)

      builder.raw_result
    end

    # Convert a Re:VIEW source string to LaTeX using LatexRenderer
    #
    # @param source [String] Re:VIEW source content
    # @param chapter [ReVIEW::Book::Chapter, nil] Chapter context (optional)
    # @return [String] Generated LaTeX
    def convert_with_renderer(source, chapter: nil)
      # Create a temporary book/chapter if not provided
      unless chapter
        book = create_temporary_book
        chapter = create_temporary_chapter(book, source)
      end

      # Parse to AST
      # Create AST compiler using auto-detection for file format
      ast_compiler = ReVIEW::AST::Compiler.for_chapter(chapter)
      ast = ast_compiler.compile_to_ast(chapter)

      # Render with LatexRenderer
      renderer = Renderer::LatexRenderer.new(chapter)

      renderer.render(ast)
    end

    # Convert a *.re file to LaTeX using LATEXBuilder
    #
    # @param file_path [String] Path to .re file
    # @return [String] Generated LaTeX
    def convert_file_with_builder(file_path)
      source = File.read(file_path)
      convert_with_builder(source)
    end

    # Convert a *.re file to LaTeX using LATEXRenderer
    #
    # @param file_path [String] Path to .re file
    # @return [String] Generated LaTeX
    def convert_file_with_renderer(file_path)
      source = File.read(file_path)
      convert_with_renderer(source)
    end

    # Convert a chapter from a book project to LaTeX using both builder and renderer
    #
    # @param book_dir [String] Path to book project directory
    # @param chapter_name [String] Chapter filename (e.g., 'ch01.re' or 'ch01')
    # @return [Hash] Hash with :builder and :renderer keys containing LaTeX output
    def convert_chapter_with_book_context(book_dir, chapter_name)
      # Ensure book_dir is absolute
      book_dir = File.expand_path(book_dir)

      # Load book configuration
      book = load_book(book_dir)

      # Find chapter by name (with or without .re extension)
      chapter_name = chapter_name.sub(/\.re$/, '')
      chapter = book.chapters.find { |ch| ch.name == chapter_name }

      raise "Chapter '#{chapter_name}' not found in book at #{book_dir}" unless chapter

      # Convert with both builder and renderer
      builder_latex = convert_with_builder(nil, chapter: chapter)
      renderer_latex = convert_with_renderer(nil, chapter: chapter)

      {
        builder: builder_latex,
        renderer: renderer_latex
      }
    end

    private

    # Create a temporary book for testing
    def create_temporary_book
      book_config = Configure.values
      book_config.merge!(@config)

      # Set default LaTeX configuration
      book_config['texstyle'] = 'reviewmacro'
      book_config['texdocumentclass'] = ['jsbook', 'oneside']
      book_config['language'] = 'ja'

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
        book_config.merge!(@config)

        config_file = File.join(book_dir, 'config.yml')
        if File.exist?(config_file)
          yaml_config = YAML.load_file(config_file, permitted_classes: [Date, Time, Symbol])
          book_config.merge!(yaml_config) if yaml_config
        end

        # Set default LaTeX configuration
        book_config['texstyle'] ||= 'reviewmacro'
        book_config['texdocumentclass'] ||= ['jsbook', 'oneside']
        book_config['language'] ||= 'ja'

        # Convert relative paths in pdfmaker config to absolute paths
        # This is necessary because LATEXBuilder tries to read these files
        # after we exit the Dir.chdir block
        if book_config['pdfmaker'] && book_config['pdfmaker']['makeindex_dic']
          dic_file = book_config['pdfmaker']['makeindex_dic']
          unless Pathname.new(dic_file).absolute?
            book_config['pdfmaker']['makeindex_dic'] = File.join(book_dir, dic_file)
          end
        end

        # Initialize I18n
        I18n.setup(book_config['language'])

        # Create book instance
        book = Book::Base.new(book_dir, config: book_config)

        # Initialize book-wide indexes early for cross-chapter references
        ReVIEW::AST::BookIndexer.build(book)

        book
      end
    end
  end
end
