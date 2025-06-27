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
require 'review/book'
require 'review/configure'
require 'review/i18n'
require 'stringio'

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

    # Convert a Re:VIEW source string to LaTeX using LATEXRenderer
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

      # Render with LATEXRenderer
      renderer = Renderer::LATEXRenderer.new(chapter)

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
  end
end
