# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/compiler'
require 'review/htmlbuilder'
require 'review/renderer/html_renderer'
require 'review/ast'
require 'review/book'
require 'review/configure'
require 'review/i18n'
require 'stringio'

module ReVIEW
  # HTMLConverter converts *.re files to HTML using both HTMLBuilder and HTMLRenderer
  # for comparison purposes.
  class HTMLConverter
    def initialize(config: {})
      @config = config.dup
    end

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

      # Parse to AST
      # Create AST compiler using auto-detection for file format
      ast_compiler = ReVIEW::AST::Compiler.for_chapter(chapter)
      ast = ast_compiler.compile_to_ast(chapter)

      # Render with HtmlRenderer
      renderer = Renderer::HtmlRenderer.new(chapter)

      # Use render_body to get body content only (without template)
      # This matches HTMLBuilder's raw_result output for comparison
      renderer.render_body(ast)
    end

    # Convert a *.re file to HTML using HTMLBuilder
    #
    # @param file_path [String] Path to .re file
    # @return [String] Generated HTML
    def convert_file_with_builder(file_path)
      source = File.read(file_path)
      convert_with_builder(source)
    end

    # Convert a *.re file to HTML using HTMLRenderer
    #
    # @param file_path [String] Path to .re file
    # @return [String] Generated HTML
    def convert_file_with_renderer(file_path)
      source = File.read(file_path)
      convert_with_renderer(source)
    end

    private

    # Create a temporary book for testing
    def create_temporary_book
      book_config = Configure.values
      book_config.merge!(@config)

      # Set default HTML configuration
      book_config['htmlext'] = 'html'
      book_config['stylesheet'] = []
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
